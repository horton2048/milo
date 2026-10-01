import { type Draft, type ChatMessage, type MoodId, type MoodState } from '../../core/model/Domain';
import {
  type AiGatewayClient,
  type GatewayError,
  type GatewayResult,
  type GatewaySuccess,
  type GatewayFailure,
  isFailure,
  type DraftSummary,
} from '../../core/network/AiGatewayClient';
import { FallbackGuide, fallbackDiary } from './FallbackGuide';

export type ConversationSource = 'ai' | 'script';

export interface ConversationState {
  /** Last source that produced a message; flips to `script` after first failure. */
  source: ConversationSource;
  /** Persistable script step so the guide resumes where it left off. */
  fallbackStep: number;
  /** Last failure surfaced to the user, or `undefined` when healthy. */
  lastError: GatewayError | undefined;
}

export function initialConversationState(): ConversationState {
  return {
    source: 'ai',
    fallbackStep: 0,
    lastError: undefined,
  };
}

export interface CompleteConversation {
  state: ConversationState;
  message: ChatMessage;
  usedAi: boolean;
}

export interface CompleteDiary {
  state: ConversationState;
  diary: string;
  usedAi: boolean;
}

/** Result type that distinguishes scripted vs AI outcomes for the UI layer. */
export type OpenResult = CompleteConversation;
export type RespondResult = CompleteConversation;
export type DiaryResult = CompleteDiary;

export interface ConversationControllerDeps {
  gateway: AiGatewayClient;
  /** Returns the local fallback guide for the current draft. */
  newGuide: (draft: Draft) => FallbackGuide;
}

export class ConversationController {
  private deps: ConversationControllerDeps;
  private state: ConversationState;
  private guide: FallbackGuide | undefined;

  constructor(deps: ConversationControllerDeps, state?: ConversationState) {
    this.deps = deps;
    this.state = state ?? initialConversationState();
  }

  /** Read-only snapshot for tests and persistence. */
  getState(): ConversationState {
    return this.state;
  }

  /** Restore a previously persisted state (e.g. after process restart). */
  restore(step: number): void {
    this.state.fallbackStep = step;
    if (this.guide !== undefined) {
      this.guide.restoreStep(step);
    }
  }

  /** Replace the whole controller state; used by the UI on cold-start hydration. */
  restoreState(state: ConversationState): void {
    this.state = {
      source: state.source,
      fallbackStep: state.fallbackStep,
      lastError: state.lastError,
    };
    if (this.guide !== undefined) {
      this.guide.restoreStep(state.fallbackStep);
    }
  }

  /** Send the opening greeting; AI first, then switch to the scripted guide. */
  async open(draft: Draft): Promise<OpenResult> {
    this.ensureGuide(draft);
    const aiText = await this.tryAi(draft, () => this.deps.gateway.open({ draft: this.toSummary(draft) as DraftSummary }));
    if (aiText !== undefined) {
      return {
        state: this.state,
        message: this.assistantMessage(aiText),
        usedAi: true,
      };
    }
    const scripted = this.guide!.opening();
    this.syncFallbackStep();
    return {
      state: this.state,
      message: this.assistantMessage(scripted),
      usedAi: false,
    };
  }

  /**
   * Reply to the user's latest message. The transcript we hand the gateway
   * already contains the user's line, so an AI success is recorded as a
   * fresh assistant message; a failure yields the next scripted reply.
   */
  async respond(draft: Draft, userText: string, ts: number): Promise<RespondResult> {
    this.ensureGuide(draft);
    const enriched: Draft = cloneDraftWith(draft, this.withUserLine(draft, userText, ts));
    const aiText = await this.tryAi(enriched, () => this.deps.gateway.respond({ draft: this.toSummary(enriched) as DraftSummary, userText: userText }));
    if (aiText !== undefined) {
      return {
        state: this.state,
        message: this.assistantMessage(aiText),
        usedAi: true,
      };
    }
    const scripted = this.guide!.next();
    this.syncFallbackStep();
    return {
      state: this.state,
      message: this.assistantMessage(scripted),
      usedAi: false,
    };
  }

  /** Generate the diary; falls back to the local first-person generator. */
  async createDiary(draft: Draft): Promise<DiaryResult> {
    const result = await this.deps.gateway.createDiary({ draft: this.toSummary(draft) as DraftSummary });
    if (result.ok === true) {
      const success: GatewaySuccess = result as GatewaySuccess;
      const trimmed = success.text.trim();
      if (trimmed.length > 0) {
        return {
          state: this.state,
          diary: trimmed,
          usedAi: true,
        };
      }
    }
    return {
      state: this.state,
      diary: fallbackDiary(draft),
      usedAi: false,
    };
  }

  /** True once the user has answered every scripted question. */
  isScriptComplete(): boolean {
    if (this.guide === undefined) {
      return false;
    }
    return this.guide.isWrappingUp();
  }

  /** Public for tests: did we already fall back to the script? */
  isOnFallback(): boolean {
    return this.state.source === 'script';
  }

  private ensureGuide(draft: Draft): void {
    if (this.guide === undefined) {
      this.guide = this.deps.newGuide(draft);
      this.guide.restoreStep(this.state.fallbackStep);
    }
  }

  private syncFallbackStep(): void {
    if (this.guide !== undefined) {
      this.state.fallbackStep = this.guide.currentStep();
    }
  }

  private async tryAi(
    draft: Draft,
    call: () => Promise<GatewayResult>,
  ): Promise<string | undefined> {
    void draft;
    if (this.state.source === 'script') {
      return undefined;
    }
    const result = await call();
    if (isFailure(result)) {
      const failure: GatewayFailure = result as GatewayFailure;
      this.state = {
        source: 'script',
        fallbackStep: this.state.fallbackStep,
        lastError: failure.error,
      };
      return undefined;
    }
    const success: GatewaySuccess = result as GatewaySuccess;
    const reply = success.text.trim();
    if (reply.length === 0) {
      const emptyError: GatewayError = {
        code: 'AI_UNAVAILABLE',
        retryable: true,
        requestId: success.requestId,
        message: 'AI 返回了空内容。',
      };
      this.state = {
        source: 'script',
        fallbackStep: this.state.fallbackStep,
        lastError: emptyError,
      };
      return undefined;
    }
    return reply;
  }

  private assistantMessage(text: string): ChatMessage {
    return { role: 'ai', text: text, ts: Date.now() };
  }

  private withUserLine(draft: Draft, userText: string, ts: number): ChatMessage[] {
    const next: ChatMessage[] = [];
    for (let index = 0; index < draft.transcript.length; index += 1) {
      next.push(draft.transcript[index]);
    }
    next.push({ role: 'user', text: userText, ts: ts });
    return next;
  }

  private toSummary(draft: Draft): DraftSummaryExport {
    const summary: DraftSummaryExport = {
      mood: draft.mood,
      transcript: draft.transcript.slice(),
    };
    if (draft.timeMark !== undefined) {
      summary.timeMark = draft.timeMark;
    }
    return summary;
  }
}

interface DraftSummaryExport {
  mood: MoodState;
  timeMark?: string;
  transcript: ChatMessage[];
}

function cloneDraftWith(draft: Draft, transcript: ChatMessage[]): Draft {
  const next: Draft = {
    mood: draft.mood,
    transcript: transcript,
    diaryEnabled: draft.diaryEnabled,
  };
  if (draft.kind !== undefined) next.kind = draft.kind;
  if (draft.timeMark !== undefined) next.timeMark = draft.timeMark;
  if (draft.note !== undefined) next.note = draft.note;
  if (draft.diary !== undefined) next.diary = draft.diary;
  if (draft.stickerTemplate !== undefined) next.stickerTemplate = draft.stickerTemplate;
  return next;
}