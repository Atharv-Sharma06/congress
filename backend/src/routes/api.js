import { Router } from "express";
import { getMetrics, getMetric, toModelContext, HEADLINE_METRICS } from "../services/metrics.js";
import { listStates, listCounties, resolveLocation, searchCounties } from "../services/locations.js";
import { analyzeQuestion, analyzeComparison } from "../services/openai.js";
import { get as cacheGet, set as cacheSet } from "../cache.js";
import { TTL } from "../config.js";

export const api = Router();

/** Maps an internal error code to a user-safe message. Upstream detail never leaks. */
function fail(res, code, extra = {}) {
  const table = {
    UNKNOWN_STATE: [404, "We don't have data for that state."],
    UNKNOWN_COUNTY: [404, "County not found. Please try again."],
    UNKNOWN_METRIC: [404, "Data not available for that measure."],
    NO_DATA: [404, "No public data has been published for this location yet."],
    RATE_LIMIT: [429, "Too many requests. Please wait a moment before trying again."],
    AI_UNAVAILABLE: [503, "Unable to analyze that question right now."],
    BAD_REQUEST: [400, "That request was missing something we need."],
    UPSTREAM: [502, "A data source is unavailable right now."],
  };
  const [status, message] = table[code] ?? [500, "Something went wrong. Please try again."];
  return res.status(status).json({ error: { code, message, ...extra } });
}

async function locationFrom(req, res, stateKey = "state", countyKey = "county") {
  const result = await resolveLocation(req.params[stateKey] ?? req.query[stateKey], req.params[countyKey] ?? req.query[countyKey]);
  if (result.error) {
    fail(res, result.error, result.suggestions ? { suggestions: result.suggestions } : {});
    return null;
  }
  return result.location;
}

// ---------------------------------------------------------------- locations

api.get("/locations", async (req, res, next) => {
  try {
    const { state, q } = req.query;
    if (q) return res.json({ counties: await searchCounties(String(q)) });
    if (state) {
      const counties = await listCounties(state);
      if (!counties) return fail(res, "UNKNOWN_STATE");
      return res.json({ counties });
    }
    res.json({ states: listStates() });
  } catch (err) {
    next(err);
  }
});

/** Resolve a reverse-geocoded place (from CoreLocation) to a county we can query. */
api.get("/locations/resolve", async (req, res, next) => {
  try {
    const result = await resolveLocation(req.query.state, req.query.county);
    if (result.error) return fail(res, result.error, result.suggestions ? { suggestions: result.suggestions } : {});
    res.json({ location: result.location });
  } catch (err) {
    next(err);
  }
});

// ------------------------------------------------------------------ metrics

api.get("/metrics/:state/:county", async (req, res, next) => {
  try {
    const location = await locationFrom(req, res);
    if (!location) return;
    const bundle = await getMetrics(location);
    if (bundle.metrics.length === 0) return fail(res, "NO_DATA");
    res.json(bundle);
  } catch (err) {
    next(err);
  }
});

api.get("/metric/:state/:county/:metric", async (req, res, next) => {
  try {
    const location = await locationFrom(req, res);
    if (!location) return;
    const detail = await getMetric(location, req.params.metric);
    if (!detail) return fail(res, "UNKNOWN_METRIC");
    res.json(detail);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------- ask

api.post("/ask", async (req, res, next) => {
  try {
    const question = String(req.body?.question || "").trim().slice(0, 500);
    if (question.length < 3) return fail(res, "BAD_REQUEST");

    const result = await resolveLocation(req.body?.state, req.body?.county);
    if (result.error) return fail(res, result.error);
    const location = result.location;

    const cacheKey = `ask:${location.id}:${question.toLowerCase()}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const bundle = await getMetrics(location);
    if (bundle.metrics.length === 0) return fail(res, "NO_DATA");

    const answer = await analyzeQuestion(question, toModelContext(bundle));
    const byId = new Map(bundle.metrics.map((m) => [m.id, m]));

    // Drop anything the model referenced that is not a real metric, so a
    // hallucinated id can never turn into a citation.
    const used = (answer.used_metric_ids || []).filter((id) => byId.has(id));
    const chartMetric = byId.get(answer.chart_metric_id) ?? byId.get(used[0]);

    const payload = {
      question,
      location: bundle.location,
      dataAvailable: answer.data_available !== false && used.length > 0,
      summary: answer.summary,
      keyFindings: (answer.key_findings || []).map((f) => ({
        sfSymbol: f.sf_symbol,
        title: f.title,
        value: f.value,
        change: f.change,
        metricId: byId.has(f.metric_id) ? f.metric_id : null,
      })),
      whatThisMeans: answer.what_this_means,
      chart: chartMetric
        ? {
            metricId: chartMetric.id,
            name: chartMetric.name,
            unit: chartMetric.unit,
            format: chartMetric.format,
            history: chartMetric.history,
          }
        : null,
      sources: used.map((id) => ({ metricId: id, metricName: byId.get(id).name, ...byId.get(id).source })),
      generatedAt: new Date().toISOString(),
    };

    if (!payload.dataAvailable) {
      payload.summary = "I couldn't find reliable public data for that question.";
      payload.whatThisMeans =
        "CivicAI only answers from the federal datasets it has loaded for this county. " +
        "Try asking about jobs, income, housing, population, or education.";
      payload.keyFindings = [];
      payload.chart = null;
      payload.sources = [];
    }

    cacheSet(cacheKey, payload, TTL.ask);
    res.json(payload);
  } catch (err) {
    next(err);
  }
});

// ------------------------------------------------------------------ compare

api.get("/compare", async (req, res, next) => {
  try {
    const [a, b] = await Promise.all([
      resolveLocation(req.query.state1, req.query.county1),
      resolveLocation(req.query.state2, req.query.county2),
    ]);
    if (a.error) return fail(res, a.error);
    if (b.error) return fail(res, b.error);

    const [bundleA, bundleB] = await Promise.all([getMetrics(a.location), getMetrics(b.location)]);
    if (!bundleA.metrics.length || !bundleB.metrics.length) return fail(res, "NO_DATA");

    const byA = new Map(bundleA.metrics.map((m) => [m.id, m]));
    const byB = new Map(bundleB.metrics.map((m) => [m.id, m]));
    const shared = [...HEADLINE_METRICS, ...byA.keys()].filter(
      (id, i, arr) => byB.has(id) && byA.has(id) && arr.indexOf(id) === i
    );

    const comparison = shared.slice(0, 8).map((id) => {
      const ma = byA.get(id);
      const mb = byB.get(id);
      return {
        metricId: id,
        name: ma.name,
        category: ma.category,
        unit: ma.unit,
        format: ma.format,
        sfSymbol: ma.sfSymbol,
        a: { value: ma.currentValue, year: ma.currentYear },
        b: { value: mb.currentValue, year: mb.currentYear },
        definition: ma.definition,
      };
    });

    let explanation = null;
    let sources = [];
    try {
      const ai = await analyzeComparison(toModelContext(bundleA), toModelContext(bundleB));
      const used = (ai.used_metric_ids || []).filter((id) => byA.has(id));
      explanation = { summary: ai.summary, whatThisMeans: ai.what_this_means };
      sources = used.map((id) => ({ metricId: id, metricName: byA.get(id).name, ...byA.get(id).source }));
    } catch (err) {
      // Comparison numbers stand on their own; the narrative is optional.
      console.warn(`[compare] AI explanation unavailable: ${err.message}`);
    }

    res.json({
      locationA: bundleA.location,
      locationB: bundleB.location,
      comparison,
      explanation,
      sources: sources.length ? sources : comparison.map((c) => ({ metricId: c.metricId, metricName: c.name, ...byA.get(c.metricId).source })),
      generatedAt: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

export { fail };
