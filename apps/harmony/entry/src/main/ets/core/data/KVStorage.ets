/**
 * Synchronous key/value storage contract.
 *
 * The repository layer is platform-agnostic: it never touches `@ohos.*`
 * directly. Production code injects a Preferences- or file-backed adapter;
 * unit tests inject `MapKVStorage` to keep tests fast and hermetic.
 */
export interface KVStorage {
  read(key: string): string | undefined;
  write(key: string, value: string): void;
  remove(key: string): void;
}

/**
 * In-memory adapter used by Hypium tests. Not intended for production.
 * Exposes a `hydrate` helper so a test can pre-populate a corrupt payload.
 */
export class MapKVStorage implements KVStorage {
  private store: Map<string, string> = new Map<string, string>();

  read(key: string): string | undefined {
    return this.store.get(key);
  }

  write(key: string, value: string): void {
    this.store.set(key, value);
  }

  remove(key: string): void {
    this.store.delete(key);
  }

  /** Seed the store with arbitrary bytes to simulate a corrupt legacy record. */
  hydrate(key: string, value: string): void {
    this.store.set(key, value);
  }
}