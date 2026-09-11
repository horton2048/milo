import { speechRecognizer } from '@kit.CoreSpeechKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  type SpeechListener,
  type SpeechPermissionState,
  type SpeechPlatform,
} from './SpeechInput';

/**
 * Production `SpeechPlatform` backed by the HarmonyOS Core Speech Kit
 * (`speechRecognizer`, short offline mode, zh-CN). Microphone access is
 * requested on demand; denial and engine errors surface as normal outcomes
 * so callers can degrade gracefully.
 */
export class HarmonySpeechPlatform implements SpeechPlatform {
  private context: common.UIAbilityContext;
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = '';
  private finishSession: (() => void) | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  checkPermission(): SpeechPermissionState {
    // Always go through the request flow: it resolves instantly when the
    // permission was already granted, and shows the dialog otherwise.
    return 'never_asked';
  }

  async requestPermission(): Promise<SpeechPermissionState> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(
        this.context,
        ['ohos.permission.MICROPHONE'],
      );
      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        return 'granted';
      }
      return 'denied';
    } catch (e) {
      return 'denied';
    }
  }

  async start(listener: SpeechListener): Promise<void> {
    const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
    const engineParams: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
      extraParams: extraParams,
    };
    const engine: speechRecognizer.SpeechRecognitionEngine =
      await speechRecognizer.createEngine(engineParams);
    this.engine = engine;

    this.sessionId = `milo-${Date.now()}`;
    const session: Promise<void> = new Promise<void>((resolve: () => void) => {
      this.finishSession = resolve;
    });

    const recognitionListener: speechRecognizer.RecognitionListener = {
      onStart: (_sessionId: string, _eventMessage: string) => {},
      onEvent: (_sessionId: string, _eventCode: number, _eventMessage: string) => {},
      onResult: (_sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        if (result.isFinal) {
          listener.onFinal(result.result);
        } else {
          listener.onPartial(result.result);
        }
      },
      onComplete: (_sessionId: string, _eventMessage: string) => {
        this.endSession();
      },
      onError: (_sessionId: string, _errorCode: number, errorMessage: string) => {
        listener.onError(errorMessage);
        this.endSession();
      },
    };
    engine.setListener(recognitionListener);

    const audioInfo: speechRecognizer.AudioInfo = {
      audioType: 'pcm',
      sampleRate: 16000,
      soundChannel: 1,
      sampleBit: 16,
    };
    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: audioInfo,
    };
    engine.startListening(startParams);
    await session;
  }

  async cancel(): Promise<void> {
    const engine = this.engine;
    if (engine !== null && this.sessionId.length > 0) {
      try {
        engine.cancel(this.sessionId);
      } catch (e) {
        // The session may already be over; cancellation is best-effort.
      }
    }
    this.endSession();
  }

  async destroy(): Promise<void> {
    const engine = this.engine;
    this.engine = null;
    if (engine !== null) {
      try {
        engine.shutdown();
      } catch (e) {
        const _unused: BusinessError = e as BusinessError;
      }
    }
  }

  private endSession(): void {
    const finish = this.finishSession;
    this.finishSession = null;
    if (finish !== null) {
      finish();
    }
  }
}
