#!/usr/bin/env node
/**
 * End-to-end smoke test against a running backend.
 *   npm start                      # in one shell
 *   npm run smoke                  # in another
 *   BASE=https://your-host npm run smoke
 *
 * Verifies real data comes back — not just that endpoints return 200.
 */
const BASE = process.env.BASE || "http://localhost:8080";
const KEY = process.env.APP_SHARED_SECRET || "";
const STATE = process.env.SMOKE_STATE || "45"; // South Carolina
const COUNTY = process.env.SMOKE_COUNTY || "York";

let failures = 0;

async function call(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(KEY ? { "x-civicai-key": KEY } : {}),
      ...options.headers,
    },
  });
  const body = await res.json().catch(() => null);
  return { status: res.status, body };
}

function check(name, condition, detail = "") {
  if (condition) {
    console.log(`  PASS  ${name}`);
  } else {
    failures++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

async function main() {
  console.log(`CivicAI smoke test against ${BASE}\n`);

  const health = await call("/health");
  check("health responds", health.status === 200);
  check("CENSUS_API_KEY is set", health.body?.keys?.census === true);
  check("FRED_API_KEY is set", health.body?.keys?.fred === true);
  check("OPENAI_API_KEY is set", health.body?.keys?.openai === true);

  const states = await call("/api/locations");
  check("state list returns 50+ states", (states.body?.states?.length ?? 0) >= 51);

  const counties = await call(`/api/locations?state=${STATE}`);
  check("county list is non-empty", (counties.body?.counties?.length ?? 0) > 0);

  const metrics = await call(`/api/metrics/${STATE}/${COUNTY}`);
  const list = metrics.body?.metrics ?? [];
  check("metrics endpoint responds", metrics.status === 200, JSON.stringify(metrics.body).slice(0, 200));
  check("at least 10 metrics have real data", list.length >= 10, `got ${list.length}`);
  check(
    "every metric carries a source URL",
    list.length > 0 && list.every((m) => typeof m.source?.url === "string" && m.source.url.startsWith("http"))
  );
  check(
    "every metric has multi-year history",
    list.length > 0 && list.every((m) => Array.isArray(m.history) && m.history.length >= 2)
  );
  check(
    "unemployment came from FRED/BLS",
    list.some((m) => m.id === "unemployment_rate")
  );

  if (list[0]) {
    const detail = await call(`/api/metric/${STATE}/${COUNTY}/${list[0].id}`);
    check("metric detail responds", detail.status === 200);
  }

  const ask = await call("/api/ask", {
    method: "POST",
    body: JSON.stringify({ question: "How has housing changed over 10 years?", state: STATE, county: COUNTY }),
  });
  check("ask responds", ask.status === 200, JSON.stringify(ask.body).slice(0, 200));
  check("ask returns a summary", typeof ask.body?.summary === "string" && ask.body.summary.length > 10);
  check("ask cites at least one source", (ask.body?.sources?.length ?? 0) > 0);
  check(
    "key findings use SF Symbols, not emoji",
    (ask.body?.keyFindings ?? []).every((f) => /^[a-z0-9.]+$/i.test(f.sfSymbol ?? ""))
  );

  const compare = await call(
    `/api/compare?state1=${STATE}&county1=${COUNTY}&state2=37&county2=Mecklenburg`
  );
  check("compare responds", compare.status === 200, JSON.stringify(compare.body).slice(0, 200));
  check("compare returns rows", (compare.body?.comparison?.length ?? 0) >= 4);

  console.log(`\n${failures === 0 ? "All checks passed." : `${failures} check(s) failed.`}`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error(`\nSmoke test could not run: ${err.message}`);
  console.error("Is the backend running? Try `npm start` first.");
  process.exit(1);
});
