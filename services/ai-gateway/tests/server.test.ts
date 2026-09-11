import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/server.js';
import type { MiniMaxTransport, ChatRequest, ChatResult } from '../src/minimax.js';
import type { ChatMessage } from '../src/contracts.js';

class FakeTransport implements MiniMaxTransport {
  blocked = false;
  fail = false;
  timeout = false;
  payload: ChatMessage[] = [];
  promptText = '';
  async chat(request: ChatRequest): Promise<ChatResult> {
    this.promptText = request.messages[0]?.text ?? '';
    this.payload = request.messages;
    if (this.timeout) throw new Error('MiniMax request timed out');
    if (this.fail) throw new Error('boom');
    if (this.blocked) return { text: '', blocked: true };
    return { text: '你好，我是回响。', blocked: false };
  }
}

function baseBody() {
  return {
    draft: {
      mood: { valence: 0, labels: ['平静'], emotionId: 'calm' },
      timeMark: '去年夏天',
      transcript: [{ role: 'ai', text: '你好', ts: 1 }],
    },
  };
}

test('GET /health reports ok', async () => {
  const app = createApp({ transport: new FakeTransport(), rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'GET', '/health');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.ok(typeof body.requestId === 'string' && body.requestId.length > 0);
});

test('POST /v1/recall/open returns the AI greeting and forwards the prompt', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.text, '你好，我是回响。');
  assert.ok(transport.promptText.includes('去年夏天'));
});

test('POST /v1/recall/open rejects an unknown emotion id with 400', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const bad = { draft: { ...baseBody().draft, mood: { valence: 0, labels: [], emotionId: 'mystery' } } };
  const response = await appFakeRequest(app, 'POST', '/v1/recall/open', bad);
  assert.equal(response.status, 400);
  const body = await response.json();
  assert.equal(body.code, 'INVALID_REQUEST');
});

test('POST /v1/recall/open rejects a body without draft', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/open', { wrong: true });
  assert.equal(response.status, 400);
});

test('POST /v1/recall/respond appends the user turn to the transcript', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/respond', {
    ...baseBody(),
    userText: '那天是雨季',
  });
  assert.equal(response.status, 200);
  const last = transport.payload[transport.payload.length - 1];
  assert.equal(last?.role, 'user');
  assert.equal(last?.text, '那天是雨季');
});

test('POST /v1/recall/respond rejects an empty userText', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/respond', { ...baseBody(), userText: '' });
  assert.equal(response.status, 400);
});

test('POST /v1/recall/diary asks the AI to write the diary', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/diary', baseBody());
  assert.equal(response.status, 200);
  assert.ok(transport.promptText.includes('第一人称'));
  assert.ok(transport.promptText.includes('去年夏天'));
});

test('upstream timeout returns AI_UNAVAILABLE', async () => {
  const transport = new FakeTransport();
  transport.timeout = true;
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body.code, 'AI_UNAVAILABLE');
  assert.equal(body.retryable, true);
});

test('upstream sensitivity block returns CONTENT_BLOCKED', async () => {
  const transport = new FakeTransport();
  transport.blocked = true;
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  assert.equal(response.status, 451);
  const body = await response.json();
  assert.equal(body.code, 'CONTENT_BLOCKED');
});

test('rate limit returns RATE_LIMITED after exceeding the budget', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 2 });
  await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  const limited = await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  assert.equal(limited.status, 429);
  const body = await limited.json();
  assert.equal(body.code, 'RATE_LIMITED');
});

test('the request id is propagated from x-request-id', async () => {
  const transport = new FakeTransport();
  const app = createApp({ transport, rateLimitPerMinute: 100 });
  const response = await appFakeRequest(app, 'GET', '/health', undefined, 'req-abc');
  assert.equal(response.headers.get('x-request-id'), 'req-abc');
  const body = await response.json();
  assert.equal(body.requestId, 'req-abc');
});

test('request log is emitted with status but never the body', async () => {
  const transport = new FakeTransport();
  const calls: unknown[] = [];
  const app = createApp({
    transport,
    rateLimitPerMinute: 100,
    requestLog: (entry) => calls.push(entry),
  });
  await appFakeRequest(app, 'POST', '/v1/recall/open', baseBody());
  assert.equal(calls.length, 1);
  const entry = calls[0] as { route: string; status: number };
  assert.equal(entry.route, '/v1/recall/open');
  assert.equal(entry.status, 200);
  const serialized = JSON.stringify(calls);
  assert.ok(!serialized.includes('你好我是回响'));
  assert.ok(!serialized.includes('去年夏天'));
});

interface FakeResponse {
  status: number;
  headers: Headers;
  json(): Promise<Record<string, unknown>>;
}

async function appFakeRequest(
  app: ReturnType<typeof createApp>,
  method: string,
  path: string,
  body?: unknown,
  requestId?: string,
): Promise<FakeResponse> {
  const server = app.listen(0);
  try {
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('No address');
    const headers: Record<string, string> = {};
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (requestId) headers['x-request-id'] = requestId;
    const response = await fetch(`http://127.0.0.1:${address.port}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const responseHeaders = new Headers();
    response.headers.forEach((value, key) => {
      responseHeaders.set(key, value);
    });
    return {
      status: response.status,
      headers: responseHeaders,
      json: async () => await response.json() as Record<string, unknown>,
    };
  } finally {
    server.close();
  }
}