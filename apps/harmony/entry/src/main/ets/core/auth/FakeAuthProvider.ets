import {
  type AuthProvider,
  type AuthError,
  type AuthSession,
  type SendCodeResult,
  type SignInResult,
  isValidEmail,
  invalidEmailError,
} from './AuthProvider';

/** Fixed code accepted by the fake provider; documented for dev/testing. */
export const FAKE_AUTH_CODE = '000000';

/**
 * In-memory stand-in for the AGC auth service. Powers unit tests and Phase-1
 * device walkthroughs without any network or AGC console setup. Swap for
 * AgcAuthProvider in Phase 2.
 */
export class FakeAuthProvider implements AuthProvider {
  private sentEmails: string[] = [];
  private signOutCalls: number = 0;

  async sendCode(email: string): Promise<SendCodeResult> {
    if (!isValidEmail(email)) {
      const failure: SendCodeResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    this.sentEmails.push(email.trim());
    return { ok: true };
  }

  async signIn(email: string, code: string): Promise<SignInResult> {
    if (!isValidEmail(email)) {
      const failure: SignInResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    if (code.trim() !== FAKE_AUTH_CODE) {
      const error: AuthError = {
        reason: 'invalid-code',
        message: '验证码不对，再检查一下邮件里的数字。',
      };
      const failure: SignInResult = { ok: false, error: error };
      return failure;
    }
    const session: AuthSession = {
      uid: `agc-${email.trim()}`,
      email: email.trim(),
      provider: 'agc',
    };
    return { ok: true, session: session };
  }

  async signOut(): Promise<void> {
    this.signOutCalls += 1;
  }

  /** Test helpers. */
  codesSentTo(email: string): number {
    let count = 0;
    for (let index = 0; index < this.sentEmails.length; index += 1) {
      if (this.sentEmails[index] === email) {
        count += 1;
      }
    }
    return count;
  }

  signOutCallCount(): number {
    return this.signOutCalls;
  }
}
