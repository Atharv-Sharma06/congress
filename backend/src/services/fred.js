import { config, TTL } from "../config.js";
import { remember } from "../cache.js";
import { fetchJSONSoft } from "../http.js";

const BASE = "https://api.stlouisfed.org/fred";

/**
 * FRED county-level series follow fixed ID conventions keyed on the 5-digit
 * county FIPS code, so we can build them without a lookup table:
 *   LAUCN{fips}0000000003  BLS Local Area Unemployment Statistics — unemployment rate
 *   LAUCN{fips}0000000006  BLS LAUS — civilian labor force
 *   PCPI{fips}             BEA — per capita personal income
 */
const SERIES = {
  unemployment_rate: {
    id: (fips) => `LAUCN${fips}0000000003`,
    name: "Unemployment Rate",
    category: "Economy",
    unit: "%",
    format: "percent",
    betterWhen: "down",
    aggregation: "avg",
    definition:
      "The share of the labor force that is out of work and actively looking for a job. People who are not looking for work are not counted.",
    organization: "U.S. Bureau of Labor Statistics",
    seriesLabel: "Local Area Unemployment Statistics",
    methodology:
      "Model-based county estimates from the BLS LAUS program. Shown here as the average of the twelve monthly values in each year.",
  },
  labor_force: {
    id: (fips) => `LAUCN${fips}0000000006`,
    name: "Civilian Labor Force",
    category: "Economy",
    unit: "people",
    format: "integer",
    betterWhen: "neutral",
    aggregation: "avg",
    definition:
      "The number of people aged 16 and older who are either working or actively looking for work.",
    organization: "U.S. Bureau of Labor Statistics",
    seriesLabel: "Local Area Unemployment Statistics",
    methodology:
      "Model-based county estimates from the BLS LAUS program, averaged across the twelve months of each year.",
  },
  per_capita_income: {
    id: (fips) => `PCPI${fips}`,
    name: "Per Capita Personal Income",
    category: "Economy",
    unit: "USD",
    format: "currency",
    betterWhen: "up",
    aggregation: "avg",
    definition:
      "Total personal income in the county divided by its population. Unlike median household income, one very large income can pull this number up.",
    organization: "U.S. Bureau of Economic Analysis",
    seriesLabel: "Personal Income by County",
    methodology:
      "Annual estimates from the BEA regional accounts, reported in current dollars (not inflation-adjusted).",
  },
};

const round = (v, format) => (format === "percent" ? Math.round(v * 10) / 10 : Math.round(v));

async function fetchSeries(seriesId, aggregation, startYear) {
  return remember(`fred:${seriesId}:${startYear}`, TTL.metrics, async () => {
    const url =
      `${BASE}/series/observations?series_id=${seriesId}` +
      `&api_key=${config.fredKey}&file_type=json` +
      `&observation_start=${startYear}-01-01` +
      `&frequency=a&aggregation_method=${aggregation}`;
    const json = await fetchJSONSoft(url, { label: `fred ${seriesId}` });
    if (!json?.observations) return null;
    return json.observations
      .filter((o) => o.value !== "." && Number.isFinite(Number(o.value)))
      .map((o) => ({ year: Number(o.date.slice(0, 4)), value: Number(o.value) }));
  });
}

async function fetchSeriesMeta(seriesId) {
  return remember(`fred-meta:${seriesId}`, TTL.metrics, async () => {
    const url = `${BASE}/series?series_id=${seriesId}&api_key=${config.fredKey}&file_type=json`;
    const json = await fetchJSONSoft(url, { label: `fred meta ${seriesId}` });
    return json?.seriess?.[0] ?? null;
  });
}

/**
 * Returns { id: { history, source, ...meta } } for one county.
 * A series that FRED does not publish for this county is simply absent.
 */
export async function fetchFredMetrics(stateFips, countyFips) {
  const fips = `${stateFips}${countyFips}`;
  const startYear = Math.min(...config.acsYears);

  return remember(`fred-metrics:${fips}`, TTL.metrics, async () => {
    const entries = await Promise.all(
      Object.entries(SERIES).map(async ([id, def]) => {
        const seriesId = def.id(fips);
        const [history, meta] = await Promise.all([
          fetchSeries(seriesId, def.aggregation, startYear),
          fetchSeriesMeta(seriesId),
        ]);
        if (!history || history.length === 0) return null;
        return [
          id,
          {
            id,
            name: def.name,
            category: def.category,
            unit: def.unit,
            format: def.format,
            betterWhen: def.betterWhen,
            definition: def.definition,
            history: history.map((p) => ({ year: p.year, value: round(p.value, def.format) })),
            source: {
              name: `${def.seriesLabel} (FRED series ${seriesId})`,
              organization: def.organization,
              url: `https://fred.stlouisfed.org/series/${seriesId}`,
              lastUpdated: meta?.last_updated?.slice(0, 10) ?? null,
              methodology: def.methodology,
            },
          },
        ];
      })
    );
    return Object.fromEntries(entries.filter(Boolean));
  });
}
