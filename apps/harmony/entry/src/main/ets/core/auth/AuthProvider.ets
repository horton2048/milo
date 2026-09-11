/**
 * Email + verification-code auth contract (AGC 认证服务 in production).
 * Follows the AiGatewayClient result-object style: no throws across the
 * boundary, failures carry a typed reason plus user-facing message.
 */
export type AuthFailureReason =
  | 'invalid-email'
  | 'invalid-code'
  | 'invalid-password'
  | 'wrong-password'
  | 'password-not-set'
  | 'network'
  | 'rate-limited'
  | 'unknown';

export interface AuthError {
  reason: AuthFailureReason;
  message: string;
}

/** Which backend issued the session; `local` marks the built-in owner bypass. */
export type AuthProviderKind = 'agc' | 'local';

export interface AuthSession {
  uid: string;
  email: string;
  provider: AuthProviderKind;
}

export interface SendCodeSuccess {
  ok: true;
}

export interface SendCodeFailure {
  ok: false;
  error: AuthError;
}

export type SendCodeResult = SendCodeSuccess | SendCodeFailure;

export interface SignInSuccess {
  ok: true;
  session: AuthSession;
}

export interface SignInFailure {
  ok: false;
  error: AuthError;
}

export type SignInResult = SignInSuccess | SignInFailure;

export interface ResetPasswordSuccess {
  ok: true;
}

export interface ResetPasswordFailure {
  ok: false;
  error: AuthError;
}

export type ResetPasswordResult = ResetPasswordSuccess | ResetPasswordFailure;

/** What the requested verification code will be used for. */
export type CodePurpose = 'sign-in' | 'reset-password';

export function isSendCodeFailure(result: SendCodeResult): boolean {
  return result.ok === false;
}

export function isSignInFailure(result: SignInResult): boolean {
  return result.ok === false;
}

export function isResetPasswordFailure(result: ResetPasswordResult): boolean {
  return result.ok === false;
}

/**
 * Password policy (mirrors AGC): 6-32 characters, no other constraints so
 * passphrases stay welcome.
 */
export const PASSWORD_MIN_LENGTH = 6;
export const PASSWORD_MAX_LENGTH = 32;

export function isValidPassword(password: string): boolean {
  const trimmed = password.trim();
  return trimmed.length >= PASSWORD_MIN_LENGTH && trimmed.length <= PASSWORD_MAX_LENGTH;
}

export function invalidPasswordError(): AuthError {
  return { reason: 'invalid-password', message: '密码需要 6-32 位，中间不能有空格。' };
}

export function wrongPasswordError(): AuthError {
  return { reason: 'wrong-password', message: '邮箱或密码不对，再试一次？' };
}

export function passwordNotSetError(): AuthError {
  return { reason: 'password-not-set', message: '这个邮箱还没设置过密码，先用验证码登录吧。' };
}

export interface AuthProvider {
  /** Request a verification code for the given email and purpose. */
  sendCode(email: string, purpose: CodePurpose): Promise<SendCodeResult>;
  /**
   * Exchange email + code for a session. The optional password registers a
   * password alongside the code login (first-time setup).
   */
  signIn(email: string, code: string, password?: string): Promise<SignInResult>;
  /** Sign in with email + password (no email round-trip). */
  signInWithPassword(email: string, password: string): Promise<SignInResult>;
  /** Reset the account password with an emailed reset code. */
  resetPassword(email: string, code: string, newPassword: string): Promise<ResetPasswordResult>;
  /** Sign out from the remote provider; local state is cleared by the caller. */
  signOut(): Promise<void>;
}

/**
 * Lightweight email shape check (no regex): must contain one "@" with local
 * text before it and a dotted domain after it, e.g. `someone@milo.app`.
 */
export function isValidEmail(email: string): boolean {
  const trimmed = email.trim();
  const at = trimmed.indexOf('@');
  if (at <= 0 || at !== trimmed.lastIndexOf('@')) {
    return false;
  }
  const domain = trimmed.slice(at + 1);
  if (domain.length < 3) {
    return false;
  }
  const dot = domain.indexOf('.');
  if (dot <= 0 || dot === domain.length - 1) {
    return false;
  }
  return true;
}

export function invalidEmailError(): AuthError {
  return { reason: 'invalid-email', message: '这个邮箱地址看起来不太对，检查一下再试试。' };
}
