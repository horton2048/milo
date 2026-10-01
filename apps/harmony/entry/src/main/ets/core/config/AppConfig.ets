/**
 * Build-time app configuration. Leave the gateway disabled for an
 * offline-only build, or set `GATEWAY_BASE_URL` to the deployed HTTPS
 * gateway before shipping a signed HAP to AppGallery Connect. See
 * `docs/operations/gateway-deploy.md` for how to deploy the gateway.
 */

export const GATEWAY_BASE_URL: string = '';
export const GATEWAY_BEARER_TOKEN: string = '';
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

export function isGatewayConfigured(config: AppConfigSnapshot): boolean {
  return config.gatewayBaseUrl.startsWith('https://');
}
