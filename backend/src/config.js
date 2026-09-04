import process from "node:process";

// Load .env without a dependency (Node >= 20.12). Real deployments set real env vars.
try {
  process.loadEnvFile?.(new URL("../.env", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));
} catch {
  // No .env file present - fine when the platform injects environment variables.
}

function required(name) {
  const v = process.env[name];
  if (!v) {
    console.error(
      `[config] Missing required environment variable ${name}. ` +
        `Copy .env.example to .env and fill it in.`
    );
  }
  return v || "";
}

export const config = {
  port: Number(process.env.PORT || 8080),
  censusKey: required("CENSUS_API_KEY"),
  fredKey: required("FRED_API_KEY"),
  openaiKey: required("OPENAI_API_KEY"),
  openaiModel: process.env.OPENAI_MODEL || "gpt-4o-mini",
  allowedOrigins: (process.env.ALLOWED_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
  appSharedSecret: process.env.APP_SHARED_SECRET || "",
  // ACS 5-year vintages we pull history from. Newest first.
  acsYears: [2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2013],
  latestAcsYear: 2023,
};

export const TTL = {
  metrics: 24 * 60 * 60 * 1000, // 24 hours
  locations: 7 * 24 * 60 * 60 * 1000, // 7 days
  ask: 30 * 60 * 1000, // 30 minutes
};
