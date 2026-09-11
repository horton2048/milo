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
  type SendCodeResult,
  type SignInResult,
  isValidEmail,
  invalidEmailError,
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

/** AGC server code for wrong email/code pair; mapped to a friendly message. */
const AGC_CODE_BAD_CREDENTIALS = 203818129;

/**
 * Translates an error thrown by the AGC auth SDK into the typed AuthError
 * contract. Known codes get friendly copy; unknown ones pass the server
 * message through so device logs stay useful.
 */
function mapAgcError(e: Object): AuthError {
  const err = e as BusinessError;
  const code: number = err.code ?? -1;
  const message: string = err.message ?? String(e);
  if (code === AGC_CODE_BAD_CREDENTIALS) {
    return { reason: 'invalid-code', message: '验证码不对，再检查一下邮件里的数字。' };
  }
  let reason: AuthFailureReason = 'unknown';
  if (message.indexOf('frequent') >= 0 || message.indexOf('频繁') >= 0) {
    reason = 'rate-limited';
  } else if (message.indexOf('network') >= 0 || message.indexOf('Failed to connect') >= 0) {
    reason = 'network';
  }
  return { reason: reason, message: `AGC ${code}: ${message}` };
}

/** Production auth provider backed by AGC 认证服务 (email + verification code). */
export class AgcAuthProvider implements AuthProvider {
  constructor(context: common.Context) {
    initAgcOnce(context);
  }

  async sendCode(email: string): Promise<SendCodeResult> {
    if (!isValidEmail(email)) {
      const failure: SendCodeResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    const verifyCodeType: EmailVerifyCode = { kind: 'email', email: email.trim() };
    const param: VerifyCodeParam = {
      verifyCodeType: verifyCodeType,
      action: VerifyCodeAction.REGISTER_LOGIN,
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

  async signIn(email: string, code: string): Promise<SignInResult> {
    if (!isValidEmail(email)) {
      const failure: SignInResult = { ok: false, error: invalidEmailError() };
      return failure;
    }
    const credentialInfo: EmailCredentialInfo = {
      kind: 'email',
      email: email.trim(),
      verifyCode: code.trim(),
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

  async signOut(): Promise<void> {
    try {
      await auth.signOut();
    } catch (e) {
      // Never block local sign-out on remote cleanup failures.
      console.error(`AgcAuthProvider.signOut: ${String(e)}`);
    }
  }
}
