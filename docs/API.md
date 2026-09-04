# CivicAI Backend API

Base URL: your deployed host. All responses are JSON.
If `APP_SHARED_SECRET` is set, every `/api/*` request must send `x-civicai-key: <secret>`.

Location parameters are forgiving on purpose — `state` accepts `45`, `SC`, or
`South Carolina`, and `county` accepts `091`, `York`, or `York County`. This is what
lets CoreLocation's reverse-geocoded strings resolve without a lookup table in the app.

---

## `GET /health`

Liveness plus a key-configuration report. Not rate limited by the app secret.

```json
{
  "status": "ok",
  "uptimeSeconds": 412,
  "cache": { "entries": 63, "inflight": 0 },
  "keys": { "census": true, "fred": true, "openai": true }
}
```

---

## `GET /api/locations`

| Query | Behavior |
|---|---|
| *(none)* | `{ "states": [{ fips, abbr, name }] }` — 50 states + DC + PR |
| `?state=SC` | `{ "counties": [...] }` — every county in that state |
| `?q=york` | `{ "counties": [...] }` — nationwide search, prefix matches first, max 25 |

County objects:

```json
{
  "id": "45091",
  "stateFips": "45",
  "countyFips": "091",
  "stateAbbr": "SC",
  "stateName": "South Carolina",
  "county": "York County",
  "displayName": "York County, South Carolina"
}
```

## `GET /api/locations/resolve?state=SC&county=York`

Resolves a reverse-geocoded place to a county. `{ "location": { ... } }`, or
`404 UNKNOWN_COUNTY` with up to 10 `suggestions`.

---

## `GET /api/metrics/:state/:county`

The full dashboard payload.

```json
{
  "location": { "...": "county object" },
  "generatedAt": "2026-09-02T14:00:00.000Z",
  "headline": ["unemployment_rate", "population", "median_income", "median_home_value"],
  "categories": [{ "id": "Economy", "name": "Economy", "sfSymbol": "chart.line.uptrend.xyaxis" }],
  "metrics": [
    {
      "id": "unemployment_rate",
      "name": "Unemployment Rate",
      "category": "Economy",
      "unit": "%",
      "format": "percent",
      "betterWhen": "down",
      "definition": "The share of the labor force that is out of work and actively looking...",
      "sfSymbol": "briefcase",
      "currentValue": 3.4,
      "currentYear": 2024,
      "trend": { "direction": "down", "sentiment": "positive" },
      "changeFiveYear": {
        "fromYear": 2019, "toYear": 2024,
        "fromValue": 3.1, "toValue": 3.4,
        "absoluteChange": 0.3, "percentChange": 9.7
      },
      "changeTenYear": { "...": "same shape" },
      "history": [{ "year": 2013, "value": 6.9 }],
      "source": {
        "name": "Local Area Unemployment Statistics (FRED series LAUCN450910000000003)",
        "organization": "U.S. Bureau of Labor Statistics",
        "url": "https://fred.stlouisfed.org/series/LAUCN450910000000003",
        "lastUpdated": "2025-04-16",
        "methodology": "Model-based county estimates from the BLS LAUS program..."
      }
    }
  ]
}
```

Notes:
- `trend.direction` is which way the number moved; `trend.sentiment` is whether that
  is good, bad or neutral for the county. They are separate because "home values up"
  is not inherently either.
- `history` contains only years the source actually published. Gaps are never filled.
- A metric the Census suppresses for this county is omitted entirely.

## `GET /api/metric/:state/:county/:metric`

One metric plus up to three siblings in its category:
`{ location, metric, related: [{ id, name, sfSymbol }] }`.

---

## `POST /api/ask`

```json
{ "question": "How has housing changed over 10 years?", "state": "SC", "county": "York" }
```

Response:

```json
{
  "question": "How has housing changed over 10 years?",
  "location": { "...": "county object" },
  "dataAvailable": true,
  "summary": "Home values in York County rose faster than rents between 2013 and 2023.",
  "keyFindings": [
    {
      "sfSymbol": "house",
      "title": "Median home value",
      "value": "$168,700 (2013) → $291,300 (2023)",
      "change": "+72.7% over 10 years",
      "metricId": "median_home_value"
    }
  ],
  "whatThisMeans": "…",
  "chart": {
    "metricId": "median_home_value",
    "name": "Median Home Value",
    "unit": "USD",
    "format": "currency",
    "history": [{ "year": 2013, "value": 168700 }]
  },
  "sources": [{ "metricId": "median_home_value", "metricName": "Median Home Value", "...": "source object" }],
  "generatedAt": "2026-09-02T14:00:00.000Z"
}
```

Guarantees enforced by the backend, not by the prompt:
- `sfSymbol` is constrained to an enum of SF Symbol names by the JSON schema, so an
  emoji cannot appear in a finding.
- `sources` is built by looking up `used_metric_ids` against the real metric set.
  Ids that don't exist are dropped, so a fabricated dataset can't be cited.
- If nothing valid remains, `dataAvailable` is `false` and `summary` becomes
  "I couldn't find reliable public data for that question."

Responses are cached per (county, question) for 30 minutes.

---

## `GET /api/compare`

`?state1=SC&county1=York&state2=NC&county2=Mecklenburg`

```json
{
  "locationA": { "...": "county object" },
  "locationB": { "...": "county object" },
  "comparison": [
    {
      "metricId": "median_income",
      "name": "Median Household Income",
      "category": "Economy",
      "unit": "USD",
      "format": "currency",
      "sfSymbol": "dollarsign.circle",
      "a": { "value": 79300, "year": 2023 },
      "b": { "value": 81500, "year": 2023 },
      "definition": "…"
    }
  ],
  "explanation": { "summary": "…", "whatThisMeans": "…" },
  "sources": ["…"],
  "generatedAt": "2026-09-02T14:00:00.000Z"
}
```

Up to 8 shared metrics. If the AI call fails, `explanation` is `null` and the numbers
are still returned — the comparison does not depend on the narrative.

---

## Errors

```json
{ "error": { "code": "UNKNOWN_COUNTY", "message": "County not found. Please try again." } }
```

| Code | HTTP | Message shown to the user |
|---|---|---|
| `UNKNOWN_STATE` | 404 | We don't have data for that state. |
| `UNKNOWN_COUNTY` | 404 | County not found. Please try again. |
| `UNKNOWN_METRIC` | 404 | Data not available for that measure. |
| `NO_DATA` | 404 | No public data has been published for this location yet. |
| `RATE_LIMIT` | 429 | Too many requests. Please wait a moment before trying again. |
| `AI_UNAVAILABLE` | 503 | Unable to analyze that question right now. |
| `UPSTREAM` | 502 | A data source is unavailable right now. |
| `UNAUTHORIZED` | 401 | Not authorized. |

Every `message` is already safe to display. Provider status codes and response
bodies are logged server-side and never forwarded.

## Rate limits and caching

| Scope | Limit |
|---|---|
| `/api/*` | 90 requests / minute / IP |
| `/api/ask`, `/api/compare` | 12 requests / minute / IP |

| Data | Server cache |
|---|---|
| Metrics | 24 hours |
| County and state lists | 7 days |
| Ask responses | 30 minutes per (county, question) |

Identical in-flight requests are de-duplicated, so a cold cache plus a burst of
users produces one upstream call, not many.
