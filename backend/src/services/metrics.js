import { fetchCensusMetrics } from "./census.js";
import { fetchFredMetrics } from "./fred.js";

/** Order metrics appear in on the dashboard and inside each category. */
const DISPLAY_ORDER = [
  "unemployment_rate",
  "population",
  "median_income",
  "median_home_value",
  "median_rent",
  "poverty_rate",
  "per_capita_income",
  "labor_force",
  "housing_units",
  "homeownership_rate",
  "hs_attainment_rate",
  "college_enrollment_rate",
  "school_enrollment",
];

/** The four cards shown above the fold on Home. */
export const HEADLINE_METRICS = [
  "unemployment_rate",
  "population",
  "median_income",
  "median_home_value",
];

export const CATEGORIES = [
  { id: "Economy", name: "Economy", sfSymbol: "chart.line.uptrend.xyaxis" },
  { id: "Housing", name: "Housing", sfSymbol: "house" },
  { id: "Population", name: "Population", sfSymbol: "person.3" },
  { id: "Education", name: "Education", sfSymbol: "graduationcap" },
];

const METRIC_SYMBOL = {
  unemployment_rate: "briefcase",
  labor_force: "person.2.badge.gearshape",
  median_income: "dollarsign.circle",
  per_capita_income: "banknote",
  poverty_rate: "exclamationmark.triangle",
  population: "person.3",
  median_home_value: "house",
  median_rent: "key",
  housing_units: "building.2",
  homeownership_rate: "signature",
  hs_attainment_rate: "graduationcap",
  college_enrollment_rate: "books.vertical",
  school_enrollment: "studentdesk",
};

function pctChange(from, to) {
  if (from === 0 || from === null || to === null) return null;
  return Math.round(((to - from) / Math.abs(from)) * 1000) / 10;
}

/** Change over the `span` most recent years actually present in the history. */
function changeOver(history, span) {
  if (history.length < 2) return null;
  const latest = history[history.length - 1];
  const targetYear = latest.year - span;
  // Nearest published year at or before the target; never interpolate.
  const base = [...history].reverse().find((p) => p.year <= targetYear) ?? history[0];
  if (base.year === latest.year) return null;
  return {
    fromYear: base.year,
    toYear: latest.year,
    fromValue: base.value,
    toValue: latest.value,
    absoluteChange: Math.round((latest.value - base.value) * 10) / 10,
    percentChange: pctChange(base.value, latest.value),
  };
}

/** Direction of movement, plus whether that movement is good/bad/neutral for the county. */
function trendFor(change, betterWhen) {
  if (!change || change.absoluteChange === 0) return { direction: "stable", sentiment: "neutral" };
  const direction = change.absoluteChange > 0 ? "up" : "down";
  if (betterWhen === "neutral") return { direction, sentiment: "neutral" };
  const sentiment = direction === betterWhen ? "positive" : "negative";
  return { direction, sentiment };
}

function decorate(metric) {
  const history = metric.history;
  const latest = history[history.length - 1];
  const fiveYear = changeOver(history, 5);
  const tenYear = changeOver(history, 10);
  const primary = fiveYear ?? tenYear;
  return {
    ...metric,
    sfSymbol: METRIC_SYMBOL[metric.id] ?? "chart.bar",
    currentValue: latest.value,
    currentYear: latest.year,
    trend: trendFor(primary, metric.betterWhen),
    changeFiveYear: fiveYear,
    changeTenYear: tenYear,
  };
}

/**
 * Full normalized metric set for a county, merged from Census + FRED.
 * Never throws on a partial upstream failure — missing metrics are just absent.
 */
export async function getMetrics(location) {
  const { stateFips, countyFips } = location;
  const [census, fred] = await Promise.all([
    fetchCensusMetrics(stateFips, countyFips),
    fetchFredMetrics(stateFips, countyFips),
  ]);

  const merged = { ...census.metrics, ...fred };
  const metrics = DISPLAY_ORDER.filter((id) => merged[id]).map((id) => decorate(merged[id]));

  return {
    location: { ...location, displayName: location.displayName || census.name || location.county },
    generatedAt: new Date().toISOString(),
    headline: HEADLINE_METRICS.filter((id) => merged[id]),
    categories: CATEGORIES.filter((c) => metrics.some((m) => m.category === c.id)),
    metrics,
  };
}

export async function getMetric(location, metricId) {
  const all = await getMetrics(location);
  const metric = all.metrics.find((m) => m.id === metricId);
  if (!metric) return null;
  const related = all.metrics
    .filter((m) => m.category === metric.category && m.id !== metric.id)
    .slice(0, 3)
    .map((m) => ({ id: m.id, name: m.name, sfSymbol: m.sfSymbol }));
  return { location: all.location, metric, related };
}

/** Compact, token-cheap view of the data handed to the model. */
export function toModelContext(bundle) {
  return {
    location: bundle.location.displayName,
    metrics: bundle.metrics.map((m) => ({
      id: m.id,
      name: m.name,
      category: m.category,
      unit: m.unit,
      definition: m.definition,
      latest: { year: m.currentYear, value: m.currentValue },
      change_5y: m.changeFiveYear,
      change_10y: m.changeTenYear,
      history: m.history,
      source: `${m.source.organization} — ${m.source.name}`,
    })),
  };
}
