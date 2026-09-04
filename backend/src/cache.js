/**
 * Tiny in-process TTL cache with single-flight de-duplication.
 * Keeps us far under FRED (120 req/min) and Census (500 req/day/IP unkeyed) limits.
 */
const store = new Map();
const inflight = new Map();

export function get(key) {
  const hit = store.get(key);
  if (!hit) return undefined;
  if (Date.now() > hit.expires) {
    store.delete(key);
    return undefined;
  }
  return hit.value;
}

export function set(key, value, ttlMs) {
  store.set(key, { value, expires: Date.now() + ttlMs });
  return value;
}

/** Runs `fn` at most once per key while it is in flight, then caches for ttlMs. */
export async function remember(key, ttlMs, fn) {
  const cached = get(key);
  if (cached !== undefined) return cached;
  if (inflight.has(key)) return inflight.get(key);

  const promise = (async () => {
    try {
      const value = await fn();
      set(key, value, ttlMs);
      return value;
    } finally {
      inflight.delete(key);
    }
  })();

  inflight.set(key, promise);
  return promise;
}

export function stats() {
  return { entries: store.size, inflight: inflight.size };
}
