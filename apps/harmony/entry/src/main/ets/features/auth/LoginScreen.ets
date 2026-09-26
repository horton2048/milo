import { MILO_COLORS } from '../../core/theme/MiloTheme';
import { MiloPrimaryButton, MiloBackNode, MiloBackLink } from '../ui/MiloButtons';
import { Haptics } from '../../core/system/Haptics';
import { isValidEmail, isValidPassword } from '../../core/auth/AuthProvider';
import { type AuthSession } from '../../core/auth/AuthProvider';
import { AuthController, BACKDOOR_EMAIL } from './AuthController';

/**
 * First-launch login gate: email + verification code (registration, AGC
 * 认证服务) or email + password for returning users. Full-screen by design —
 * the only skip affordance is the owner backdoor email `milo`.
 */
@Component
export struct LoginScreen {
  controller: AuthController | null = null;
  onSignedIn: (session: AuthSession) => void = () => {};
  @State mode: 'code' | 'password' = 'code';
  @State step: 'email' | 'code' | 'reset' = 'email';
  @State email: string = '';
  @State code: string = '';
  @State password: string = '';
  @State newPassword: string = '';
  @State error: string = '';
  @State busy: boolean = false;
  private haptics: Haptics = new Haptics();

  private isBackdoor(): boolean {
    return this.email.trim().toLowerCase() === BACKDOOR_EMAIL;
  }

  private canSubmitEmail(): boolean {
    const trimmed = this.email.trim();
    return trimmed.toLowerCase() === BACKDOOR_EMAIL || isValidEmail(trimmed);
  }

  private canSubmitPassword(): boolean {
    if (this.isBackdoor()) {
      return this.password.trim().length > 0;
    }
    return isValidEmail(this.email.trim()) && isValidPassword(this.password);
  }

  private syncError(): void {
    const error = this.controller?.getError();
    this.error = error !== undefined ? error.message : '';
  }

  private switchMode(mode: 'code' | 'password'): void {
    if (this.busy || this.mode === mode) {
      return;
    }
    this.mode = mode;
    this.step = 'email';
    this.code = '';
    this.password = '';
    this.error = '';
    this.controller?.backToEmail();
  }

  private async submitEmail(): Promise<void> {
    if (this.busy || this.controller === null || !this.canSubmitEmail()) {
      return;
    }
    this.busy = true;
    this.error = '';
    const session = await this.controller.submitEmail(this.email);
    this.busy = false;
    this.syncError();
    if (session !== undefined) {
      this.onSignedIn(session);
      return;
    }
    if (this.controller.getPhase() === 'awaitingCode') {
      this.haptics.selection();
      this.step = 'code';
    }
  }

  private async submitCode(): Promise<void> {
    if (this.busy || this.controller === null) {
      return;
    }
    this.busy = true;
    this.error = '';
    const session = await this.controller.submitCode(this.code, this.password);
    this.busy = false;
    this.syncError();
    if (session !== undefined) {
      this.onSignedIn(session);
    }
  }

  private async submitPassword(): Promise<void> {
    if (this.busy || this.controller === null || !this.canSubmitPassword()) {
      return;
    }
    this.busy = true;
    this.error = '';
    const session = await this.controller.submitPassword(this.email, this.password);
    this.busy = false;
    this.syncError();
    if (session !== undefined) {
      this.onSignedIn(session);
    }
  }

  /** 忘记密码: send a reset code for the entered email and show the reset form. */
  private async startReset(): Promise<void> {
    if (this.busy || this.controller === null || !this.canSubmitEmail()) {
      return;
    }
    this.busy = true;
    this.error = '';
    const session = await this.controller.submitEmail(this.email, 'reset-password');
    this.busy = false;
    this.syncError();
    if (session !== undefined) {
      this.onSignedIn(session);
      return;
    }
    if (this.controller.getPhase() === 'awaitingCode') {
      this.haptics.selection();
      this.step = 'reset';
    }
  }

  private async submitReset(): Promise<void> {
    if (this.busy || this.controller === null) {
      return;
    }
    this.busy = true;
    this.error = '';
    const session = await this.controller.submitReset(this.code, this.newPassword);
    this.busy = false;
    this.syncError();
    if (session !== undefined) {
      this.onSignedIn(session);
    }
  }

  private backToEmail(): void {
    this.step = 'email';
    this.code = '';
    this.password = '';
    this.newPassword = '';
    this.error = '';
    this.controller?.backToEmail();
  }

  @Builder
  modeToggle() {
    Row() {
      Text('验证码登录')
        .fontSize(14)
        .fontColor(this.mode === 'code' ? MILO_COLORS.ink : MILO_COLORS.inkHint)
        .fontWeight(this.mode === 'code' ? FontWeight.Bold : FontWeight.Normal)
        .onClick(() => this.switchMode('code'))
      Text('·')
        .fontSize(14)
        .fontColor(MILO_COLORS.inkHint)
        .margin({ left: 14, right: 14 })
      Text('密码登录')
        .fontSize(14)
        .fontColor(this.mode === 'password' ? MILO_COLORS.ink : MILO_COLORS.inkHint)
        .fontWeight(this.mode === 'password' ? FontWeight.Bold : FontWeight.Normal)
        .onClick(() => this.switchMode('password'))
    }
    .margin({ bottom: 26 })
  }

  @Builder
  emailField() {
    TextInput({ placeholder: 'you@example.com', text: this.email })
      .onChange((value: string) => {
        this.email = value;
        if (this.error.length > 0) {
          this.error = '';
        }
      })
      .type(InputType.Email)
      .width('82%')
      .height(48)
      .padding({ left: 18, right: 18 })
      .borderRadius(999)
      .backgroundColor('rgba(255,255,255,0.05)')
      .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
      .fontColor(MILO_COLORS.ink)
      .fontSize(14)
      .placeholderColor('rgba(234,230,255,0.45)')
      .placeholderFont({ size: 13 })
  }

  @Builder
  errorText() {
    if (this.error.length > 0) {
      Text(this.error)
        .fontSize(12.5)
        .fontColor('rgba(255,164,173,0.92)')
        .margin({ top: 14 })
        .textAlign(TextAlign.Center)
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)

      Column() {
        Text('MILO')
          .fontSize(34)
          .fontFamily('serif')
          .fontWeight(FontWeight.Medium)
          .fontColor(MILO_COLORS.ink)
          .letterSpacing(6)
        Text('你的私人回忆空间')
          .fontSize(13)
          .fontColor(MILO_COLORS.inkHint)
          .margin({ top: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 44 })

      if (this.step === 'email') {
        this.modeToggle()
      }

      if (this.step === 'reset') {
        Column() {
          MiloBackNode({
            onTap: () => this.backToEmail(),
          })
            .alignSelf(ItemAlign.Start)
            .margin({ left: 4, bottom: 20 })
          Text('重置密码')
            .fontSize(22)
            .fontFamily('serif')
            .fontWeight(FontWeight.Medium)
            .fontColor(MILO_COLORS.ink)
          Text(`重置码已发往 ${this.email.trim()}，\n设置新密码后直接登录。`)
            .fontSize(13)
            .lineHeight(23.4)
            .fontColor(MILO_COLORS.inkHint)
            .margin({ top: 12 })
        }
        .width('82%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 30 })

        TextInput({ placeholder: '6 位验证码', text: this.code })
          .onChange((value: string) => {
            this.code = value;
            if (this.error.length > 0) {
              this.error = '';
            }
          })
          .type(InputType.Number)
          .width('82%')
          .height(48)
          .padding({ left: 18, right: 18 })
          .borderRadius(999)
          .backgroundColor('rgba(255,255,255,0.05)')
          .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
          .fontColor(MILO_COLORS.ink)
          .fontSize(14)
          .textAlign(TextAlign.Center)
          .placeholderColor('rgba(234,230,255,0.45)')
          .placeholderFont({ size: 13 })

        TextInput({ placeholder: '新密码（6-32 位）', text: this.newPassword })
          .onChange((value: string) => {
            this.newPassword = value;
            if (this.error.length > 0) {
              this.error = '';
            }
          })
          .type(InputType.Password)
          .width('82%')
          .height(48)
          .padding({ left: 18, right: 18 })
          .borderRadius(999)
          .backgroundColor('rgba(255,255,255,0.05)')
          .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
          .fontColor(MILO_COLORS.ink)
          .fontSize(14)
          .placeholderColor('rgba(234,230,255,0.45)')
          .placeholderFont({ size: 13 })
          .showPasswordIcon(true)
          .margin({ top: 14 })

        this.errorText()

        Blank().layoutWeight(2)

        MiloPrimaryButton({
          label: this.busy ? '重置中…' : '重置并登录',
          active: this.code.trim().length > 0 && isValidPassword(this.newPassword) && !this.busy,
          onTap: () => {
            void this.submitReset();
          },
        })
          .margin({ left: 24, right: 24, bottom: 10 })

        MiloBackLink({
          label: '重新发送重置码',
          onTap: () => {
            void this.startReset();
          },
        })
          .margin({ bottom: 24 })
      } else if (this.mode === 'code' && this.step === 'code') {
        Column() {
          MiloBackNode({
            onTap: () => this.backToEmail(),
          })
            .alignSelf(ItemAlign.Start)
            .margin({ left: 4, bottom: 20 })
          Text('查收验证码')
            .fontSize(22)
            .fontFamily('serif')
            .fontWeight(FontWeight.Medium)
            .fontColor(MILO_COLORS.ink)
          Text(`验证码已发往 ${this.email.trim()}，\n如果没收到，记得看看垃圾邮件。`)
            .fontSize(13)
            .lineHeight(23.4)
            .fontColor(MILO_COLORS.inkHint)
            .margin({ top: 12 })
        }
        .width('82%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 30 })

        TextInput({ placeholder: '6 位验证码', text: this.code })
          .onChange((value: string) => {
            this.code = value;
            if (this.error.length > 0) {
              this.error = '';
            }
          })
          .type(InputType.Number)
          .width('82%')
          .height(48)
          .padding({ left: 18, right: 18 })
          .borderRadius(999)
          .backgroundColor('rgba(255,255,255,0.05)')
          .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
          .fontColor(MILO_COLORS.ink)
          .fontSize(14)
          .textAlign(TextAlign.Center)
          .placeholderColor('rgba(234,230,255,0.45)')
          .placeholderFont({ size: 13 })

        TextInput({ placeholder: '设置密码（可选，下次免验证码）', text: this.password })
          .onChange((value: string) => {
            this.password = value;
            if (this.error.length > 0) {
              this.error = '';
            }
          })
          .type(InputType.Password)
          .width('82%')
          .height(48)
          .padding({ left: 18, right: 18 })
          .borderRadius(999)
          .backgroundColor('rgba(255,255,255,0.05)')
          .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
          .fontColor(MILO_COLORS.ink)
          .fontSize(14)
          .placeholderColor('rgba(234,230,255,0.45)')
          .placeholderFont({ size: 13 })
          .showPasswordIcon(true)
          .margin({ top: 14 })

        this.errorText()

        Blank().layoutWeight(2)

        MiloPrimaryButton({
          label: this.busy ? '登录中…' : '登录',
          active: this.code.trim().length > 0 && !this.busy,
          onTap: () => {
            void this.submitCode();
          },
        })
          .margin({ left: 24, right: 24, bottom: 10 })

        MiloBackLink({
          label: '重新发送验证码',
          onTap: () => {
            void this.submitEmail();
          },
        })
          .margin({ bottom: 24 })
      } else if (this.mode === 'password') {
        Column() {
          Text('用邮箱登录')
            .fontSize(22)
            .fontFamily('serif')
            .fontWeight(FontWeight.Medium)
            .fontColor(MILO_COLORS.ink)
          Text('输入密码直接登录，\n第一次来？切到验证码登录注册。')
            .fontSize(13)
            .lineHeight(23.4)
            .fontColor(MILO_COLORS.inkHint)
            .margin({ top: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 30 })

        this.emailField()

        TextInput({ placeholder: '密码', text: this.password })
          .onChange((value: string) => {
            this.password = value;
            if (this.error.length > 0) {
              this.error = '';
            }
          })
          .type(InputType.Password)
          .width('82%')
          .height(48)
          .padding({ left: 18, right: 18 })
          .borderRadius(999)
          .backgroundColor('rgba(255,255,255,0.05)')
          .border({ width: 1, color: 'rgba(255,255,255,0.10)' })
          .fontColor(MILO_COLORS.ink)
          .fontSize(14)
          .placeholderColor('rgba(234,230,255,0.45)')
          .placeholderFont({ size: 13 })
          .showPasswordIcon(true)
          .margin({ top: 14 })

        this.errorText()

        Blank().layoutWeight(2)

        MiloPrimaryButton({
          label: this.busy ? '登录中…' : '登录',
          active: this.canSubmitPassword() && !this.busy,
          onTap: () => {
            void this.submitPassword();
          },
        })
          .margin({ left: 24, right: 24, bottom: 10 })

        MiloBackLink({
          label: '忘记密码',
          onTap: () => {
            void this.startReset();
          },
        })
          .margin({ bottom: 24 })
      } else {
        Column() {
          Text('用邮箱登录')
            .fontSize(22)
            .fontFamily('serif')
            .fontWeight(FontWeight.Medium)
            .fontColor(MILO_COLORS.ink)
          Text('我们会发送一封带验证码的邮件，\n之后就可以一直离线使用了。')
            .fontSize(13)
            .lineHeight(23.4)
            .fontColor(MILO_COLORS.inkHint)
            .margin({ top: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 30 })

        this.emailField()

        this.errorText()

        Blank().layoutWeight(2)

        MiloPrimaryButton({
          label: this.busy ? '发送中…' : '发送验证码',
          active: this.canSubmitEmail() && !this.busy,
          onTap: () => {
            void this.submitEmail();
          },
        })
          .margin({ left: 24, right: 24, bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
  }
}
