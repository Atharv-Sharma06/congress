import { STATES, resolveState } from "../data/states.js";
import { fetchCounties } from "./census.js";

const normalize = (s) =>
  String(s || "")
    .toLowerCase()
    .replace(/\b(county|parish|borough|census area|municipality|city and borough)\b/g, "")
    .replace(/[^a-z0-9]/g, "")
    .trim();

export function listStates() {
  return STATES.map(({ fips, abbr, name }) => ({ fips, abbr, name }));
}

export async function listCounties(stateInput) {
  const state = resolveState(stateInput);
  if (!state) return null;
  return fetchCounties(state.fips);
}

/**
 * Resolves a (state, county) pair from anything the app can supply:
 * FIPS codes, abbreviations, or the names CoreLocation reverse-geocoding returns
 * ("York County" / "York").
 */
export async function resolveLocation(stateInput, countyInput) {
  const state = resolveState(stateInput);
  if (!state) return { error: "UNKNOWN_STATE" };

  const counties = await fetchCounties(state.fips);
  const raw = String(countyInput || "").trim();

  const byFips = /^\d{3}$/.test(raw) && counties.find((c) => c.countyFips === raw);
  if (byFips) return { location: byFips };

  const target = normalize(raw);
  const exact = counties.find((c) => normalize(c.county) === target);
  if (exact) return { location: exact };

  const partial = counties.find(
    (c) => normalize(c.county).startsWith(target) || target.startsWith(normalize(c.county))
  );
  if (partial) return { location: partial };

  return { error: "UNKNOWN_COUNTY", state, suggestions: counties.slice(0, 10) };
}

/** Free-text search across every county in every state, for the picker's search field. */
export async function searchCounties(query, limit = 25) {
  const target = normalize(query);
  if (target.length < 2) return [];

  // Search states already loaded first so a typical query returns without 51 fetches.
  const results = [];
  for (const state of STATES) {
    let counties;
    try {
      counties = await fetchCounties(state.fips);
    } catch {
      continue;
    }
    for (const c of counties) {
      const n = normalize(c.county);
      if (n.startsWith(target)) results.push({ ...c, rank: 0 });
      else if (n.includes(target)) results.push({ ...c, rank: 1 });
    }
    if (results.filter((r) => r.rank === 0).length >= limit) break;
  }

  return results
    .sort((a, b) => a.rank - b.rank || a.county.localeCompare(b.county))
    .slice(0, limit)
    .map(({ rank, ...c }) => c);
}
