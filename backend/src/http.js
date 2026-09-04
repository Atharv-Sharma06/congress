/** Fetch JSON with timeout + one retry on transient failure. */
export async function fetchJSON(url, { timeoutMs = 12000, retries = 1, label = "upstream" } = {}) {
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, {
        signal: controller.signal,
        headers: { "User-Agent": "CivicAI/1.0 (civic data research app)" },
      });
      if (res.status === 429) {
        const err = new Error(`${label} rate limited`);
        err.code = "RATE_LIMIT";
        throw err;
      }
      if (!res.ok) {
        const err = new Error(`${label} responded ${res.status}`);
        err.code = "UPSTREAM";
        err.status = res.status;
        throw err;
      }
      const contentType = res.headers.get("content-type") || "";
      if (!contentType.includes("json")) {
        // Census answers a missing/invalid API key with an HTML error page.
        const body = (await res.text()).slice(0, 200);
        const err = new Error(
          `${label} returned ${contentType || "an unknown content type"} instead of JSON` +
            (/missing key|invalid key/i.test(body) ? " (check your API key)" : "")
        );
        err.code = "UPSTREAM";
        throw err;
      }
      return await res.json();
    } catch (err) {
      lastErr = err;
      if (err.code === "RATE_LIMIT" || attempt === retries) break;
      await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastErr;
}

/** Resolves to null instead of throwing — used for optional metrics. */
export async function fetchJSONSoft(url, opts) {
  try {
    return await fetchJSON(url, opts);
  } catch (err) {
    console.warn(`[soft-fail] ${opts?.label || "upstream"}: ${err.message}`);
    return null;
  }
}
