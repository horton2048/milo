/**
 * Haptic feedback adapter. Mirrors the trigger points used by the web build's
 * `apps/web/src/lib/haptics.ts`: selection changes, important confirmations,
 * and gentle reminders.
 *
 * The production wiring delegates to `@ohos.vibrator`. Tests inject a
 * `HapticPlatform` fake to assert timing without needing device APIs.
 */

export type HapticEvent =
  | 'selection'
  | 'confirmation'
  | 'reminder'
  | 'error';

export interface HapticPlatform {
  vibrate(event: HapticEvent): void;
}

export class Haptics {
  private platform: HapticPlatform;
  private enabled: boolean = true;

  constructor(platform?: HapticPlatform) {
    this.platform = platform ?? defaultHapticPlatform();
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  selection(): void {
    if (!this.enabled) return;
    this.platform.vibrate('selection');
  }

  confirmation(): void {
    if (!this.enabled) return;
    this.platform.vibrate('confirmation');
  }

  reminder(): void {
    if (!this.enabled) return;
    this.platform.vibrate('reminder');
  }

  error(): void {
    if (!this.enabled) return;
    this.platform.vibrate('error');
  }
}

function defaultHapticPlatform(): HapticPlatform {
  // The real device implementation would call `vibrator.startVibration` with
  // a `VibratorPattern` shaped from the event name. In unit tests we rely on
  // injected fakes instead.
  return new NoopHapticPlatform();
}

class NoopHapticPlatform implements HapticPlatform {
  vibrate(_event: HapticEvent): void {}
}