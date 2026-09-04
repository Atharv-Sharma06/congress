# CivicAI — Your Community, Explained.

A civic data intelligence app for iOS. It loads real federal datasets about your
county, charts them, and answers plain-English questions about them — with every
statistic traceable back to the dataset it came from.

Not a chatbot. A public-data research tool with an AI reading layer on top.

```
ios/        SwiftUI app (iOS 17+, Swift Charts, CoreLocation)
backend/    Node.js API — Census + FRED/BLS/BEA + OpenAI
docs/       API reference, deployment, App Store checklist
design-system/  Design tokens and rules the app is built against
```

## What it actually shows

13 county-level measures, all pulled live, none hardcoded:

| Category | Measures | Source |
|---|---|---|
| Economy | Unemployment rate, civilian labor force | BLS LAUS via FRED |
| Economy | Per capita personal income | BEA via FRED |
| Economy | Median household income, poverty rate | Census ACS 5-year |
| Housing | Median home value, median gross rent, housing units, homeownership rate | Census ACS 5-year |
| Population | Total population | Census ACS 5-year |
| Education | High school attainment, college enrollment share, school enrollment | Census ACS 5-year |

Each carries ~11 years of history, a 5-year and 10-year change, a plain-English
definition, and a link to the published dataset. Metrics the Census suppresses for
a given county are simply absent — nothing is interpolated or estimated.

## Quick start

### 1. Get three free API keys

| Key | Where | Notes |
|---|---|---|
| `CENSUS_API_KEY` | https://api.census.gov/data/key_signup.html | Required — the Census API rejects keyless requests |
| `FRED_API_KEY` | https://fred.stlouisfed.org/docs/api/api_key.html | Required for unemployment and income series |
| `OPENAI_API_KEY` | https://platform.openai.com/api-keys | Powers Ask CivicAI and the Compare explanation |

### 2. Run the backend

```bash
cd backend
cp .env.example .env      # then paste your three keys in
npm install
npm start                 # http://localhost:8080
```

Verify it end to end:

```bash
npm run smoke             # checks real data, sources, and the AI path
```

### 3. Run the app

```bash
cd ios
brew install xcodegen     # one time
xcodegen generate         # writes CivicAI.xcodeproj
open CivicAI.xcodeproj
```

Then in Xcode: select the **CivicAI** target → **Signing & Capabilities** → pick your
team, and press Run. `Config/Debug.xcconfig` already points at `localhost:8080`.

No Homebrew? See [`ios/README.md`](ios/README.md) for creating the project manually.

## How Ask CivicAI stays honest

The interesting part of this project is not that it calls a model — it's the
constraints around the call.

1. **The model gets data, not a search engine.** Only the county's loaded datasets
   are sent. It is instructed to answer from those numbers alone.
2. **Structured output, not free text.** The response comes back through a strict
   JSON schema. Icons are constrained to an enum of SF Symbol names, which is why
   no emoji can reach the UI.
3. **Citations are rebuilt server-side.** The model returns metric *ids*; the
   backend looks each one up and discards anything that isn't a real metric, then
   assembles the source list itself. A hallucinated dataset name can't become a
   citation.
4. **It is allowed to say no.** If the data can't answer the question, the response
   is replaced with "I couldn't find reliable public data for that question."
5. **No causal claims.** The system prompt requires "coincided with" / "the data
   shows" phrasing, and forbids policy positions.

## Security

- The app ships **no** provider keys. It knows one HTTPS base URL and an optional
  shared secret, both injected at build time through `.xcconfig` → `Info.plist`.
- All three provider keys live only in the backend's environment.
- Provider error text is logged server-side and never returned to the client;
  the app renders from a fixed table of user-safe messages.
- Rate limits: 90 req/min per IP overall, 12 req/min on the OpenAI-backed routes.

## Privacy

The county you choose is the only thing stored, and it stays in `UserDefaults` on
the device. Location is requested once, on demand, and is reverse-geocoded to a
county name locally — coordinates never leave the phone.

## Docs

- [`docs/API.md`](docs/API.md) — endpoint reference
- [`docs/DEPLOY.md`](docs/DEPLOY.md) — deploying the backend
- [`docs/APP_STORE.md`](docs/APP_STORE.md) — submission assets and checklist
- [`design-system/MASTER.md`](design-system/MASTER.md) — tokens, motion, a11y rules
