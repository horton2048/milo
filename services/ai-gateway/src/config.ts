/**
 * Validates environment configuration at startup. Exits with a non-zero code
 * when the gateway is started without the required secret.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function readDotenv(): void {
  try {
    const raw = readFileSync(resolve(process.cwd(), '.env'), 'utf8');
    for (const line of raw.split('\n')) {
      const trimmed = line.trim();
      if (trimmed.length === 0 || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq < 0) continue;
      const key = trimmed.slice(0, eq).trim();
      const value = trimmed.slice(eq + 1).trim();
      if (process.env[key] === undefined) {
        process.env[key] = value;
      }
    }
  } catch {
    // .env is optional; fall back to process.env directly.
  }
}

export interface GatewayConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
  port: number;
  timeoutMs: number;
}

export function loadConfig(): GatewayConfig {
  readDotenv();
  const apiKey = process.env.MINIMAX_API_KEY ?? '';
  const baseUrl = process.env.MINIMAX_BASE_URL ?? 'https://api.minimaxi.com/v1';
  const model = process.env.MINIMAX_MODEL ?? 'MiniMax-M3';
  const port = Number(process.env.PORT ?? 8788);
  const timeoutMs = Number(process.env.AI_TIMEOUT_MS ?? 20000);
  if (apiKey.trim().length === 0) {
    throw new Error('Missing MINIMAX_API_KEY. Set it in the environment or .env before starting the gateway.');
  }
  if (!Number.isFinite(port) || port <= 0 || port >= 65536) {
    throw new Error('Invalid PORT.');
  }
  if (!Number.isFinite(timeoutMs) || timeoutMs < 1000) {
    throw new Error('Invalid AI_TIMEOUT_MS; must be ≥ 1000.');
  }
  if (baseUrl.length === 0 || !baseUrl.startsWith('http')) {
    throw new Error('Invalid MINIMAX_BASE_URL.');
  }
  return { apiKey, baseUrl, model, port, timeoutMs };
}

/** Replaces the key with a redacted marker suitable for logs and error responses. */
export function redactKey(key: string): string {
  if (key.length === 0) return '<missing>';
  if (key.length <= 6) return '***';
  return `${key.slice(0, 3)}***${key.slice(-3)}`;
}
