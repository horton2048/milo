import { buffer } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import auth, {
  VerifyCodeAction,
  EmailVerifyCode,
  EmailCredentialInfo,
  VerifyCodeParam,
  SignInParam,
} from '@hw-agconnect/auth';
import {
  type AuthProvider,
  type AuthError,
  type AuthSession,
  type AuthFailureReason,
  type CodePurpose,
  type ResetPasswordResult,
  type SendCodeResult,
  type SignInResult,
  isValidEmail,
  invalidEmailError,
  isValidPassword,
  invalidPasswordError,
} from './AuthProvider';

/** Name of the AGC config inside entry/src/main/resources/rawfile/. */
const AGC_CONFIG_FILE = 'agconnect-services.json';
/** Locale used for AGC verification-code emails. */
const AGC_LANG = 'zh_CN';
/** Minimum seconds between two code requests enforced client-side. */
const AGC_SEND_INTERVAL = 60;

let agcInitialized = false;

function initAgcOnce(context: common.Context): void {
  if (agcInitialized) {
    return;
  }
  try {
    const raw = context.resourceManager.getRawFileContentSync(AGC_CONFIG_FILE);
    const json = buffer.from(raw.buffer).toString();
    auth.init(context, json);
    agcInitialized = true;
  } catch (e) {
    // Missing/broken config must never crash startup; auth calls will fail
    // with typed errors instead.
    console.error(`AgcAuthProvider init failed: ${String(e)}`);
  }
}

/** AGC server code for wrong credentials (code or password). */
const AGC_CODE_BAD_CREDENTIALS = 203818129;
/** AGC server code for wrong email/password pair in password login. */
const AGC_CODE_BAD_LOGIN = 203818032;

/**
 * Translates an error thrown by the AGC auth SDK into the typed AuthError
 * contract. Known codes get friendly copy; unknown ones pass the server
 * message through so device logs stay useful.
 */
function mapAgcError(e: Object): AuthError {
  const err = e as BusinessError;
  const code: number = err.code ?? -1;
  const message: string = err.message ?? String(e);
  if (code === AGC_CODE_BAD_LOGIN) {
    return { reason: 'wrong-password', message: '邮箱或密码不对，再试一次？' };
  }
  if (code === AGC_CODE_BAD_CREDENTIALS) {
    if (message.indexOf('password') >= 0) {
      return { reason: 'wrong-password', message: '邮箱或密码不对，再试一次？' };
    }
    return { reason: 'invalid-code', message: '验证码不对，再检查一下邮件里的数字。' };
  }
  let reason: AuthFailureReason = 'unknown';
  if (message.indexOf('frequent') >= 0 || message.indexOf('频繁') >= 0) {
    reason = 'rate-limited';
  } else if (message.indexOf('network') >= 0 || message.indexOf('Failed to connect') >= 0) {
    reason = 'network';
  } else if (message.indexOf('password') >= 0 && message.indexOf('not set') >= 0) {
    reason = 'password-not-set';
  }
  return { reason: reason, message: `AGC ${code}: ${message}` };
}

/** Production auth provider backed by AGC 认证服务 (email + code / password). */
export class AgcAuthProvider implements AuthProvider {
  constructor(context: common.Context) {
    initAgcOnce(context);
  }

  async sendCode(email: string, purpose: CodePurpose): Promise<SendCodeResult> {
    if (!isValidEmail(email)) {
      const failure: SendCodeResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    const verifyCodeType: EmailVerifyCode = { kind: 'email', email: email.trim() };
    const param: VerifyCodeParam = {
      verifyCodeType: verifyCodeType,
      action: purpose === 'reset-password'
        ? VerifyCodeAction.RESET_PASSWORD
        : VerifyCodeAction.REGISTER_LOGIN,
      lang: AGC_LANG,
      sendInterval: AGC_SEND_INTERVAL,
    };
    try {
      await auth.requestVerifyCode(param);
      return { ok: true };
    } catch (e) {
      const failure: SendCodeResult = { ok: false, error: mapAgcError(e) };
      return failure;
    }
  }

  async signIn(email: string, code: string, password?: string): Promise<SignInResult> {
    if (!isValidEmail(email)) {
      const failure: SignInResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    const credentialInfo: EmailCredentialInfo = {
      kind: 'email',
      email: email.trim(),
      verifyCode: code.trim(),
      password: password !== undefined && password.length > 0 ? password : undefined,
    };
    const param: SignInParam = { credentialInfo: credentialInfo, autoCreateUser: true };
    try {
      const result = await auth.signIn(param);
      const user = result.getUser();
      const session: AuthSession = {
        uid: user.getUid(),
        email: user.getEmail() !== '' ? user.getEmail() : email.trim(),
        provider: 'agc',
      };
      return { ok: true, session: session };
    } catch (e) {
      const failure: SignInResult = { ok: false, error: mapAgcError(e) };
      return failure;
    }
  }

  async signInWithPassword(email: string, password: string): Promise<SignInResult> {
    if (!isValidEmail(email)) {
      const failure: SignInResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    if (!isValidPassword(password)) {
      const failure: SignInResult = { ok: false, error: invalidPasswordError() };
      return failure;
    }
    const credentialInfo: EmailCredentialInfo = {
      kind: 'email',
      email: email.trim(),
      password: password,
    };
    const param: SignInParam = { credentialInfo: credentialInfo };
    try {
      const result = await auth.signIn(param);
      const user = result.getUser();
      const session: AuthSession = {
        uid: user.getUid(),
        email: user.getEmail() !== '' ? user.getEmail() : email.trim(),
        provider: 'agc',
      };
      return { ok: true, session: session };
    } catch (e) {
      const failure: SignInResult = { ok: false, error: mapAgcError(e) };
      return failure;
    }
  }

  async resetPassword(email: string, code: string, newPassword: string): Promise<ResetPasswordResult> {
    if (!isValidEmail(email)) {
      const failure: ResetPasswordResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    if (!isValidPassword(newPassword)) {
      const failure: ResetPasswordResult = { ok: false, error: invalidPasswordError() };
      return failure;
    }
    const credentialInfo: EmailCredentialInfo = {
      kind: 'email',
      email: email.trim(),
      verifyCode: code.trim(),
      password: newPassword,
    };
    try {
      await auth.resetPassword(credentialInfo);
      return { ok: true };
    } catch (e) {
      const failure: ResetPasswordResult = { ok: false, error: mapAgcError(e) };
      return failure;
    }
  }

  async signOut(): Promise<void> {
    try {
      await auth.signOut();
    } catch (e) {
      // Never block local sign-out on remote cleanup failures.
      console.error(`AgcAuthProvider.signOut: ${String(e)}`);
    }
  }
}
