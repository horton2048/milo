import { type AuthSession, type AuthProviderKind } from './AuthProvider';
import { type KVStorage } from '../data/KVStorage';

/** Persisted shape for the signed-in session. */
export interface SessionEnvelope {
  schemaVersion: 1;
  session: PersistedSession;
}

interface PersistedSession {
  uid: string;
  email: string;
  provider: string;
}

export const SESSION_STORAGE_KEY = 'milo.auth.session.v1';
export const SESSION_SCHEMA_VERSION = 1;

const VALID_PROVIDERS: ReadonlyArray<AuthProviderKind> = ['agc', 'local'];

/**
 * KVStorage-backed session persistence. Survives app restarts so the app
 * stays fully offline after the first successful login. Phase 2 moves the
 * AGC token itself into Asset Store Kit; this envelope only keeps the
 * identity snapshot.
 */
export class AuthSessionStore {
  private storage: KVStorage;

  constructor(storage: KVStorage) {
    this.storage = storage;
  }

  save(session: AuthSession): void {
    const envelope: SessionEnvelope = {
      schemaVersion: SESSION_SCHEMA_VERSION,
      session: {
        uid: session.uid,
        email: session.email,
        provider: session.provider,
      },
    };
    this.storage.write(SESSION_STORAGE_KEY, JSON.stringify(envelope));
  }

  /** Returns `undefined` when nothing is saved or the payload is corrupt. Never throws. */
  load(): AuthSession | undefined {
    const raw = this.storage.read(SESSION_STORAGE_KEY);
    if (raw === undefined) {
      return undefined;
    }
    return parseSession(raw);
  }

  clear(): void {
    this.storage.remove(SESSION_STORAGE_KEY);
  }
}

export function parseSession(raw: string): AuthSession | undefined {
  let parsed: Object;
  try {
    parsed = JSON.parse(raw) as Object;
  } catch {
    return undefined;
  }
  if (typeof parsed !== 'object' || parsed === null) {
    return undefined;
  }
  const record = parsed as Record<string, Object>;
  if (record['schemaVersion'] !== SESSION_SCHEMA_VERSION) {
    return undefined;
  }
  const sessionValue = record['session'];
  if (typeof sessionValue !== 'object' || sessionValue === null) {
    return undefined;
  }
  const session = sessionValue as Record<string, Object>;
  const uid = session['uid'];
  const email = session['email'];
  const provider = session['provider'];
  if (typeof uid !== 'string' || uid.length === 0) {
    return undefined;
  }
  if (typeof email !== 'string' || email.length === 0) {
    return undefined;
  }
  if (typeof provider !== 'string' || VALID_PROVIDERS.indexOf(provider as AuthProviderKind) < 0) {
    return undefined;
  }
  return {
    uid: uid,
    email: email,
    provider: provider as AuthProviderKind,
  };
}
