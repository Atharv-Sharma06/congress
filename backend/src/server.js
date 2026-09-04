import express from "express";
import helmet from "helmet";
import cors from "cors";
import compression from "compression";
import rateLimit from "express-rate-limit";

import { config } from "./config.js";
import { api, fail } from "./routes/api.js";
import { stats } from "./cache.js";
import { STATES } from "./data/states.js";
import { fetchCounties } from "./services/census.js";

const app = express();
app.set("trust proxy", 1);

app.use(helmet());
app.use(compression());
app.use(express.json({ limit: "16kb" }));
app.use(
  cors({
    origin: config.allowedOrigins.length ? config.allowedOrigins : true,
    methods: ["GET", "POST"],
  })
);

// Native apps send no Origin header, so CORS alone is not access control.
// A shared secret keeps casual scrapers off the OpenAI-backed endpoints.
app.use("/api", (req, res, next) => {
  if (!config.appSharedSecret) return next();
  if (req.get("x-civicai-key") === config.appSharedSecret) return next();
  return res.status(401).json({ error: { code: "UNAUTHORIZED", message: "Not authorized." } });
});

app.use("/api", rateLimit({ windowMs: 60_000, limit: 90, standardHeaders: true, legacyHeaders: false }));
// The AI endpoints cost money per call, so they get a tighter budget.
app.use(["/api/ask", "/api/compare"], rateLimit({ windowMs: 60_000, limit: 12, standardHeaders: true, legacyHeaders: false }));

app.get("/health", (req, res) =>
  res.json({
    status: "ok",
    uptimeSeconds: Math.round(process.uptime()),
    cache: stats(),
    keys: {
      census: Boolean(config.censusKey),
      fred: Boolean(config.fredKey),
      openai: Boolean(config.openaiKey),
    },
  })
);

app.use("/api", api);

app.use((req, res) =>
  res.status(404).json({ error: { code: "NOT_FOUND", message: "That endpoint does not exist." } })
);

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(`[error] ${req.method} ${req.originalUrl}: ${err.stack || err.message}`);
  fail(res, err.code === "RATE_LIMIT" ? "RATE_LIMIT" : err.code === "UPSTREAM" ? "UPSTREAM" : "INTERNAL");
});

app.listen(config.port, () => {
  console.log(`CivicAI backend listening on :${config.port} (model: ${config.openaiModel})`);
  warmCountyIndex();
});

/**
 * Loads every state's county list once at boot so the picker's search is instant
 * and never fans out 51 requests on a user's first keystroke. Staggered to stay
 * well inside the Census rate limit.
 */
async function warmCountyIndex() {
  for (const state of STATES) {
    try {
      await fetchCounties(state.fips);
    } catch (err) {
      console.warn(`[warm] ${state.abbr}: ${err.message}`);
    }
    await new Promise((r) => setTimeout(r, 120));
  }
  console.log(`[warm] county index ready (${stats().entries} cache entries)`);
}
