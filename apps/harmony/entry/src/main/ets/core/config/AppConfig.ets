/**
 * Build-time app configuration. The defaults target a developer machine;
 * flip `GATEWAY_BASE_URL` to your deployed HTTPS gateway before shipping
 * a signed HAP to AppGallery Connect. See
 * `docs/operations/gateway-deploy.md` for how to deploy the gateway.
 */

export const GATEWAY_BASE_URL: string = 'http://127.0.0.1:8787';
export const GATEWAY_BEARER_TOKEN: string = 'milo-harmony';
export const GATEWAY_TIMEOUT_MS: number = 15000;

export interface AppConfigSnapshot {
  gatewayBaseUrl: string;
  gatewayBearerToken: string;
  gatewayTimeoutMs: number;
}

export function readAppConfig(): AppConfigSnapshot {
  return {
    gatewayBaseUrl: GATEWAY_BASE_URL,
    gatewayBearerToken: GATEWAY_BEARER_TOKEN,
    gatewayTimeoutMs: GATEWAY_TIMEOUT_MS,
  };
}