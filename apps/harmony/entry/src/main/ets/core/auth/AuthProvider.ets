/**
 * Email + verification-code auth contract (AGC 认证服务 in production).
 * Follows the AiGatewayClient result-object style: no throws across the
 * boundary, failures carry a typed reason plus user-facing message.
 */
export type AuthFailureReason =
  | 'invalid-email'
  | 'invalid-code'
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

export function isSendCodeFailure(result: SendCodeResult): boolean {
  return result.ok === false;
}

export function isSignInFailure(result: SignInResult): boolean {
  return result.ok === false;
}

export interface AuthProvider {
  /** Request a verification code for the given email. */
  sendCode(email: string): Promise<SendCodeResult>;
  /** Exchange email + code for a session. */
  signIn(email: string, code: string): Promise<SignInResult>;
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
