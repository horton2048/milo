/**
 * Public HTTP gateway for the recall flow. Validates inputs, calls MiniMax
 * through the injected transport, and emits a single error envelope shape
 * (`ErrorEnvelope`) on every failure path.
 */
import { randomUUID } from 'node:crypto';
import express, { type Request, type Response, type NextFunction, type Express } from 'express';
import {
  buildDiaryPrompt,
  buildOpeningPrompt,
} from './prompts.js';
import {
  createMiniMaxTransport,
  type MiniMaxTransport,
} from './minimax.js';
import {
  isValidMoodId,
  isValidRole,
  MAX_LABELS,
  MAX_LABEL_LENGTH,
  MAX_TEXT_LENGTH,
  MAX_TRANSCRIPT_LINES,
  type ChatMessage,
  type DraftSummary,
  type ErrorEnvelope,
} from './contracts.js';

export interface ServerDeps {
  transport: MiniMaxTransport;
  rateLimitPerMinute: number;
  requestLog?: (entry: RequestLog) => void;
}

export interface RequestLog {
  requestId: string;
  route: string;
  status: number;
  code?: string;
  durationMs: number;
  blocked: boolean;
}

const SYSTEM_OPENING = '你是「回响」——温柔、安静的回忆引导者。每次只问一个问题。';
const SYSTEM_RESPOND = '你是「回响」。顺着上一轮的脉络继续引导，保持 1~3 句。';
const SYSTEM_DIARY = '你是「回响」。把对话改写成用户第一人称的感受日记，200~400 字，只输出正文。';

interface RouteDeps extends ServerDeps {}

export function createApp(deps: RouteDeps): Express {
  bindTransport(deps.transport);
  const app = express();
  app.use(express.json({ limit: '64kb' }));

  // Request id + basic access log; never logs the body.
  app.use((req, res, next) => {
    const id = req.header('x-request-id') ?? randomUUID();
    res.setHeader('x-request-id', id);
    const started = Date.now();
    res.on('finish', () => {
      deps.requestLog?.({
        requestId: id,
        route: req.path,
        status: res.statusCode,
        durationMs: Date.now() - started,
        blocked: res.getHeader('x-blocked') === 'true',
      });
    });
    next();
  });

  // Per-IP token bucket; simple in-memory. One window per minute.
  const buckets = new Map<string, { count: number; resetAt: number }>();
  app.use((req, res, next) => {
    if (req.path === '/health') {
      next();
      return;
    }
    const key = req.ip ?? 'unknown';
    const now = Date.now();
    const bucket = buckets.get(key);
    if (!bucket || bucket.resetAt < now) {
      buckets.set(key, { count: 1, resetAt: now + 60_000 });
      next();
      return;
    }
    bucket.count += 1;
    if (bucket.count > deps.rateLimitPerMinute) {
      respondError(res, 429, 'RATE_LIMITED', '请求过于频繁，请稍后再试。', req.header('x-request-id') ?? randomUUID());
      return;
    }
    next();
  });

  app.get('/health', (req, res) => {
    const requestId = req.header('x-request-id') ?? randomUUID();
    res.json({
      ok: true,
      model: 'gateway',
      baseUrl: 'gateway',
      requestId,
    });
  });

  app.post('/v1/recall/open', async (req, res) => {
    const requestId = res.getHeader('x-request-id') as string;
    const parsed = parseDraft(req.body);
    if (parsed.kind === 'invalid') {
      respondError(res, 400, 'INVALID_REQUEST', parsed.reason, requestId);
      return;
    }
    await runCompletion(res, requestId, SYSTEM_OPENING, parsed.value, buildOpeningPrompt);
  });

  app.post('/v1/recall/respond', async (req, res) => {
    const requestId = res.getHeader('x-request-id') as string;
    const parsed = parseDraft(req.body);
    if (parsed.kind === 'invalid') {
      respondError(res, 400, 'INVALID_REQUEST', parsed.reason, requestId);
      return;
    }
    const userText = readString(req.body?.userText);
    if (userText === undefined || userText.length === 0) {
      respondError(res, 400, 'INVALID_REQUEST', '缺少 userText。', requestId);
      return;
    }
    if (userText.length > MAX_TEXT_LENGTH) {
      respondError(res, 400, 'INVALID_REQUEST', 'userText 超过最大长度。', requestId);
      return;
    }
    const draft = parsed.value;
    const messages: ChatMessage[] = draft.transcript.concat([{ role: 'user', text: userText, ts: Date.now() }]);
    const enriched: DraftSummary = { ...draft, transcript: messages };
    await runCompletion(res, requestId, SYSTEM_RESPOND, enriched, (d) => userText);
  });

  app.post('/v1/recall/diary', async (req, res) => {
    const requestId = res.getHeader('x-request-id') as string;
    const parsed = parseDraft(req.body);
    if (parsed.kind === 'invalid') {
      respondError(res, 400, 'INVALID_REQUEST', parsed.reason, requestId);
      return;
    }
    await runCompletion(res, requestId, SYSTEM_DIARY, parsed.value, buildDiaryPrompt);
  });

  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    const requestId = res.getHeader('x-request-id') as string ?? randomUUID();
    respondError(res, 500, 'AI_UNAVAILABLE', '网关内部错误。', requestId);
  });

  return app;
}

type ParseResult =
  | { kind: 'ok'; value: DraftSummary }
  | { kind: 'invalid'; reason: string };

function parseDraft(body: unknown): ParseResult {
  if (typeof body !== 'object' || body === null) {
    return { kind: 'invalid', reason: '请求体必须是对象。' };
  }
  const root = body as Record<string, unknown>;
  const draftRaw = root['draft'];
  if (typeof draftRaw !== 'object' || draftRaw === null) {
    return { kind: 'invalid', reason: '缺少 draft 字段。' };
  }
  const draft = draftRaw as Record<string, unknown>;
  const moodRaw = draft['mood'];
  if (typeof moodRaw !== 'object' || moodRaw === null) {
    return { kind: 'invalid', reason: '缺少 draft.mood 字段。' };
  }
  const mood = moodRaw as Record<string, unknown>;
  const valence = mood['valence'];
  if (typeof valence !== 'number' || !Number.isFinite(valence)) {
    return { kind: 'invalid', reason: 'draft.mood.valence 必须是有限数字。' };
  }
  const labels = mood['labels'];
  if (!Array.isArray(labels) || labels.length > MAX_LABELS) {
    return { kind: 'invalid', reason: 'draft.mood.labels 必须是数组且不超过 6 个。' };
  }
  for (let index = 0; index < labels.length; index += 1) {
    const label = labels[index];
    if (typeof label !== 'string' || label.length === 0 || label.length > MAX_LABEL_LENGTH) {
      return { kind: 'invalid', reason: 'draft.mood.labels 中的元素必须是 1~32 字符的字符串。' };
    }
  }
  const emotionId = mood['emotionId'];
  if (emotionId !== undefined && !isValidMoodId(emotionId)) {
    return { kind: 'invalid', reason: 'draft.mood.emotionId 必须是已知的 MoodId。' };
  }
  const timeMark = draft['timeMark'];
  if (timeMark !== undefined && (typeof timeMark !== 'string' || timeMark.length === 0 || timeMark.length > 64)) {
    return { kind: 'invalid', reason: 'draft.timeMark 必须是 1~64 字符的字符串。' };
  }
  const transcriptRaw = draft['transcript'];
  if (!Array.isArray(transcriptRaw) || transcriptRaw.length > MAX_TRANSCRIPT_LINES) {
    return { kind: 'invalid', reason: 'draft.transcript 必须是数组且不超过 32 条。' };
  }
  const transcript: ChatMessage[] = [];
  for (let index = 0; index < transcriptRaw.length; index += 1) {
    const item = transcriptRaw[index];
    if (typeof item !== 'object' || item === null) {
      return { kind: 'invalid', reason: 'transcript 元素必须是对象。' };
    }
    const record = item as Record<string, unknown>;
    if (!isValidRole(record['role'])) {
      return { kind: 'invalid', reason: 'transcript.role 必须是 user 或 ai。' };
    }
    if (typeof record['text'] !== 'string' || record['text'].length === 0 || record['text'].length > MAX_TEXT_LENGTH) {
      return { kind: 'invalid', reason: 'transcript.text 必须是 1~2000 字符的字符串。' };
    }
    if (typeof record['ts'] !== 'number') {
      return { kind: 'invalid', reason: 'transcript.ts 必须是数字。' };
    }
    transcript.push({ role: record['role'], text: record['text'], ts: record['ts'] });
  }
  const summary: DraftSummary = {
    mood: { valence, labels: labels as string[] },
    transcript,
  };
  if (emotionId !== undefined) summary.mood.emotionId = emotionId;
  if (typeof timeMark === 'string') summary.timeMark = timeMark;
  return { kind: 'ok', value: summary };
}

function readString(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  return value;
}

async function runCompletion(
  res: Response,
  requestId: string,
  system: string,
  draft: DraftSummary,
  prompt: (d: DraftSummary) => string,
): Promise<void> {
  try {
    const result = await depsTransport(res).chat({
      system,
      messages: [
        { role: 'user', text: prompt(draft), ts: Date.now() },
      ],
      temperature: 0.6,
    });
    if (result.blocked) {
      res.setHeader('x-blocked', 'true');
      respondError(res, 451, 'CONTENT_BLOCKED', '对话内容触发了内容策略，请换个方向。', requestId);
      return;
    }
    if (result.text.length === 0) {
      respondError(res, 502, 'AI_UNAVAILABLE', 'AI 没有返回内容。', requestId);
      return;
    }
    res.json({ text: result.text, requestId });
  } catch {
    respondError(res, 502, 'AI_UNAVAILABLE', 'AI 服务暂时不可用。', requestId);
  }
}

function depsTransport(_res: Response): MiniMaxTransport {
  // Server-side dependency access; `createApp` captures `deps` in closure.
  // We re-export through a module-level binding so the route handlers can
  // call it without threading the reference through every signature.
  return gatewayTransport!;
}

let gatewayTransport: MiniMaxTransport | undefined;

export function bindTransport(transport: MiniMaxTransport): void {
  gatewayTransport = transport;
}

export function startServer(deps: ServerDeps & { port: number }): void {
  bindTransport(deps.transport);
  const app = createApp(deps);
  app.listen(deps.port, () => {
    process.stdout.write(`AI gateway listening on :${deps.port}\n`);
  });
}

export function respondError(
  res: Response,
  status: number,
  code: ErrorEnvelope['code'],
  message: string,
  requestId: string,
): void {
  const body: ErrorEnvelope = {
    code,
    message,
    retryable: code === 'AI_UNAVAILABLE' || code === 'RATE_LIMITED',
    requestId,
  };
  res.status(status).json(body);
}
