import {
  type AuthError,
  type AuthProvider,
  type AuthSession,
  type CodePurpose,
  type ResetPasswordFailure,
  type ResetPasswordResult,
  type SendCodeFailure,
  type SendCodeResult,
  type SignInFailure,
  type SignInResult,
  type SignInSuccess,
  isResetPasswordFailure,
  isSendCodeFailure,
  isSignInFailure,
  invalidPasswordError,
  isValidEmail,
  isValidPassword,
  invalidEmailError,
} from '../../core/auth/AuthProvider';
import { AuthSessionStore } from '../../core/auth/AuthSessionStore';

/**
 * Owner backdoor: submitting this exact string as the email skips remote auth
 * entirely and signs in a persistent local manager session. It exists so the
 * app owner can never be locked out by the first-launch login gate (e.g. no
 * network on a fresh install). A real address like `milo@x.com` is unaffected.
 */
export const BACKDOOR_EMAIL = 'milo';

export const BACKDOOR_SESSION: AuthSession = {
  uid: 'milo-local-owner',
  email: 'milo',
  provider: 'local',
};

export type AuthPhase =
  | 'checking'
  | 'signedOut'
  | 'sendingCode'
  | 'awaitingCode'
  | 'signingIn'
  | 'signedIn';

export interface AuthControllerDeps {
  provider: AuthProvider;
  store: AuthSessionStore;
}

/**
 * State machine behind the first-launch login gate:
 * checking → signedOut → sendingCode → awaitingCode → signingIn → signedIn.
 * The UI reads phase/error/session after each await; the controller never
 * touches the network for the owner backdoor.
 */
export class AuthController {
  private deps: AuthControllerDeps;
  private phaseValue: AuthPhase = 'checking';
  private errorValue: AuthError | undefined = undefined;
  private sessionValue: AuthSession | undefined = undefined;

  constructor(deps: AuthControllerDeps) {
    this.deps = deps;
  }

  /** Cold-start hydration from the persisted session. */
  restore(): AuthSession | undefined {
    const saved = this.deps.store.load();
    if (saved !== undefined) {
      this.sessionValue = saved;
      this.phaseValue = 'signedIn';
    } else {
      this.sessionValue = undefined;
      this.phaseValue = 'signedOut';
    }
    return saved;
  }

  getPhase(): AuthPhase {
    return this.phaseValue;
  }

  getError(): AuthError | undefined {
    return this.errorValue;
  }

  getSession(): AuthSession | undefined {
    return this.sessionValue;
  }

  clearError(): void {
    this.errorValue = undefined;
  }

  /** From the code step back to the email step (e.g. wrong address). */
  backToEmail(): void {
    if (this.phaseValue === 'awaitingCode') {
      this.phaseValue = 'signedOut';
      this.errorValue = undefined;
    }
  }

  /**
   * Submit the email: owner backdoor short-circuits to a local session,
   * otherwise request a verification code from the provider. Resolves with
   * the session when the backdoor signed in, `undefined` otherwise.
   */
  async submitEmail(email: string, purpose: CodePurpose = 'sign-in'): Promise<AuthSession | undefined> {
    const trimmed = email.trim();
    if (trimmed.toLowerCase() === BACKDOOR_EMAIL) {
      this.deps.store.save(BACKDOOR_SESSION);
      this.sessionValue = BACKDOOR_SESSION;
      this.errorValue = undefined;
      this.phaseValue = 'signedIn';
      return BACKDOOR_SESSION;
    }
    if (!isValidEmail(trimmed)) {
      this.errorValue = invalidEmailError();
      this.phaseValue = 'signedOut';
      return undefined;
    }
    this.errorValue = undefined;
    this.pendingEmail = trimmed;
    this.pendingPurpose = purpose;
    this.phaseValue = 'sendingCode';
    const result: SendCodeResult = await this.deps.provider.sendCode(trimmed, purpose);
    if (isSendCodeFailure(result)) {
      const failure: SendCodeFailure = result as SendCodeFailure;
      this.errorValue = failure.error;
      this.phaseValue = 'signedOut';
      return undefined;
    }
    this.phaseValue = 'awaitingCode';
    return undefined;
  }

  /** Exchange the emailed code for a session; persists it on success. */
  async submitCode(code: string, password?: string): Promise<AuthSession | undefined> {
    if (this.phaseValue !== 'awaitingCode') {
      return undefined;
    }
    const trimmed = code.trim();
    if (trimmed.length === 0) {
      this.errorValue = { reason: 'invalid-code', message: '先输入邮件里的验证码。' };
      return undefined;
    }
    if (password !== undefined && password.length > 0 && !isValidPassword(password)) {
      this.errorValue = invalidPasswordError();
      return undefined;
    }
    this.errorValue = undefined;
    this.phaseValue = 'signingIn';
    const email = this.pendingEmail;
    const result: SignInResult = await this.deps.provider.signIn(email, trimmed, password);
    if (isSignInFailure(result)) {
      const failure: SignInFailure = result as SignInFailure;
      this.errorValue = failure.error;
      this.phaseValue = 'awaitingCode';
      return undefined;
    }
    const success: SignInSuccess = result as SignInSuccess;
    const session = success.session;
    this.deps.store.save(session);
    this.sessionValue = session;
    this.phaseValue = 'signedIn';
    return session;
  }

  /**
   * Sign in directly with email + password (returning-user path). The owner
   * backdoor works here too, same as the code flow.
   */
  async submitPassword(email: string, password: string): Promise<AuthSession | undefined> {
    const trimmed = email.trim();
    if (trimmed.toLowerCase() === BACKDOOR_EMAIL) {
      this.deps.store.save(BACKDOOR_SESSION);
      this.sessionValue = BACKDOOR_SESSION;
      this.errorValue = undefined;
      this.phaseValue = 'signedIn';
      return BACKDOOR_SESSION;
    }
    if (!isValidEmail(trimmed)) {
      this.errorValue = invalidEmailError();
      this.phaseValue = 'signedOut';
      return undefined;
    }
    if (!isValidPassword(password)) {
      this.errorValue = invalidPasswordError();
      this.phaseValue = 'signedOut';
      return undefined;
    }
    this.errorValue = undefined;
    this.pendingEmail = trimmed;
    this.phaseValue = 'signingIn';
    const result: SignInResult = await this.deps.provider.signInWithPassword(trimmed, password);
    if (isSignInFailure(result)) {
      const failure: SignInFailure = result as SignInFailure;
      this.errorValue = failure.error;
      this.phaseValue = 'signedOut';
      return undefined;
    }
    const success: SignInSuccess = result as SignInSuccess;
    const session = success.session;
    this.deps.store.save(session);
    this.sessionValue = session;
    this.phaseValue = 'signedIn';
    return session;
  }

  /**
   * Complete the forgot-password flow: verify the reset code, set the new
   * password, then immediately sign in with it. Requires a reset code that
   * was requested via `submitEmail(email, 'reset-password')`.
   */
  async submitReset(code: string, newPassword: string): Promise<AuthSession | undefined> {
    if (this.phaseValue !== 'awaitingCode' || this.pendingPurpose !== 'reset-password') {
      return undefined;
    }
    if (code.trim().length === 0) {
      this.errorValue = { reason: 'invalid-code', message: '先输入邮件里的验证码。' };
      return undefined;
    }
    if (!isValidPassword(newPassword)) {
      this.errorValue = invalidPasswordError();
      return undefined;
    }
    this.errorValue = undefined;
    this.phaseValue = 'signingIn';
    const email = this.pendingEmail;
    const reset: ResetPasswordResult = await this.deps.provider.resetPassword(email, code.trim(), newPassword);
    if (isResetPasswordFailure(reset)) {
      const failure: ResetPasswordFailure = reset as ResetPasswordFailure;
      this.errorValue = failure.error;
      this.phaseValue = 'awaitingCode';
      return undefined;
    }
    const result: SignInResult = await this.deps.provider.signInWithPassword(email, newPassword);
    if (isSignInFailure(result)) {
      const failure: SignInFailure = result as SignInFailure;
      this.errorValue = failure.error;
      this.phaseValue = 'signedOut';
      return undefined;
    }
    const success: SignInSuccess = result as SignInSuccess;
    const session = success.session;
    this.deps.store.save(session);
    this.sessionValue = session;
    this.phaseValue = 'signedIn';
    return session;
  }

  /** Forget the session locally and sign out from the remote provider. */
  async signOut(): Promise<void> {
    const session = this.sessionValue;
    if (session !== undefined && session.provider !== 'local') {
      await this.deps.provider.signOut();
    }
    this.deps.store.clear();
    this.sessionValue = undefined;
    this.errorValue = undefined;
    this.phaseValue = 'signedOut';
  }

  private pendingEmail: string = '';
  private pendingPurpose: CodePurpose = 'sign-in';
}
