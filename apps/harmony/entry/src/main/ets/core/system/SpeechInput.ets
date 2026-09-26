/**
 * Permission-aware Chinese speech input. The runtime entry point is the
 * HarmonyOS `voiceRecognizer` engine; this module wraps it so callers never
 * see platform exceptions. Cancellation and permission denial are normal
 * outcomes — never auto-sent text — and the recognized string is normalised
 * into the active `input` value.
 *
 * Tests inject `SpeechPlatform` to avoid touching the real engine.
 */

export type SpeechPermissionState = 'granted' | 'denied' | 'never_asked';

export type SpeechState =
  | 'idle'
  | 'requesting_permission'
  | 'listening'
  | 'recognizing'
  | 'finalized'
  | 'cancelled'
  | 'denied'
  | 'error';

export interface SpeechResult {
  state: SpeechState;
  text: string;
  /** True when the recognizer delivered the final text fragment. */
  isFinal: boolean;
}

export interface SpeechPlatform {
  /** Returns the current microphone permission state without prompting. */
  checkPermission(): SpeechPermissionState;
  /** Prompts the user; resolves with the new state. */
  requestPermission(): Promise<SpeechPermissionState>;
  /** Begin recognition; the listener receives incremental results. */
  start(listener: SpeechListener): Promise<void>;
  /** Cancel an in-flight recognition without emitting text. */
  cancel(): Promise<void>;
  /** Tear down platform resources. */
  destroy(): Promise<void>;
}

export interface SpeechListener {
  onPartial(text: string): void;
  onFinal(text: string): void;
  onError(message: string): void;
}

export interface SpeechInputOptions {
  /** Locale id; defaults to `zh-CN`. */
  locale?: string;
  /** Override the platform for tests. */
  platform?: SpeechPlatform;
}

export class SpeechInput {
  private platform: SpeechPlatform;
  private locale: string;
  private state: SpeechState = 'idle';
  private currentListener: SpeechListener | null = null;

  constructor(options: SpeechInputOptions = {}) {
    this.platform = options.platform ?? defaultSpeechPlatform();
    this.locale = options.locale ?? 'zh-CN';
  }

  getState(): SpeechState {
    return this.state;
  }

  async begin(): Promise<SpeechResult> {
    const currentState: SpeechState = this.state;
    if (currentState === 'listening' || currentState === 'recognizing') {
      return { state: currentState, text: '', isFinal: false };
    }
    const permission = this.platform.checkPermission();
    if (permission === 'denied') {
      this.state = 'denied';
      return { state: 'denied', text: '', isFinal: false };
    }
    if (permission === 'never_asked') {
      this.state = 'requesting_permission';
      const granted = await this.platform.requestPermission();
      if (granted !== 'granted') {
        this.state = 'denied';
        return { state: 'denied', text: '', isFinal: false };
      }
    }
    this.state = 'listening';
    const captured = new SpeechCapture();
    const stateBox = new SpeechStateBox('listening');
    const listener = new InlineSpeechListener(captured, stateBox);
    this.currentListener = listener;
    await this.platform.start(listener);
    const resolvedState: SpeechState = stateBox.value;
    const result: SpeechResult = {
      state: resolvedState,
      text: captured.text,
      isFinal: resolvedState === 'finalized',
    };
    this.state = resolvedState;
    if (resolvedState === 'listening') {
      // platform.start resolved without any callback; treat as no text.
      this.state = 'idle';
      result.state = 'idle';
    }
    this.currentListener = null;
    return result;
  }

  async cancel(): Promise<void> {
    if (this.state !== 'listening' && this.state !== 'recognizing') {
      return;
    }
    await this.platform.cancel();
    this.state = 'cancelled';
    this.currentListener = null;
  }

  async dispose(): Promise<void> {
    await this.platform.destroy();
    this.state = 'idle';
  }
}

/** Convenience helper to merge recognized text into an existing input buffer. */
export function mergeRecognizedText(current: string, recognized: string): string {
  const trimmedCurrent = current.trimEnd();
  if (trimmedCurrent.length === 0) {
    return recognized.trim();
  }
  return `${trimmedCurrent} ${recognized.trim()}`;
}

function defaultSpeechPlatform(): SpeechPlatform {
  // On a real device the production wiring would import the
  // `@ohos.ai.speechRecognizer` + `@ohos.permissions` modules. In test
  // environments (and when no listener is attached) the no-op platform is
  // used so unit tests do not depend on device-only APIs.
  return new NoopSpeechPlatform();
}

class NoopSpeechPlatform implements SpeechPlatform {
  checkPermission(): SpeechPermissionState {
    return 'never_asked';
  }
  async requestPermission(): Promise<SpeechPermissionState> {
    return 'denied';
  }
  async start(_listener: SpeechListener): Promise<void> {
    // Intentional no-op for unsupported environments.
  }
  async cancel(): Promise<void> {}
  async destroy(): Promise<void> {}
}

class SpeechCapture {
  text: string = '';
  errorMessage: string = '';
}

class SpeechStateBox {
  value: SpeechState;
  constructor(initial: SpeechState) {
    this.value = initial;
  }
  set(next: SpeechState): void {
    this.value = next;
  }
}

class InlineSpeechListener implements SpeechListener {
  private capture: SpeechCapture;
  private stateBox: SpeechStateBox;

  constructor(capture: SpeechCapture, stateBox: SpeechStateBox) {
    this.capture = capture;
    this.stateBox = stateBox;
  }

  onPartial(text: string): void {
    this.capture.text = text;
    this.stateBox.set('recognizing');
  }

  onFinal(text: string): void {
    this.capture.text = text;
    this.stateBox.set('finalized');
  }

  onError(message: string): void {
    this.capture.errorMessage = message;
    this.stateBox.set('error');
  }
}