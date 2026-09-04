# App Store submission

## Listing

**Name:** CivicAI
**Subtitle (30 chars):** `Your community, explained.` *(26)*
**Category:** Education (secondary: Reference)
**Age rating:** 4+
**Price:** Free

**Keywords (100 chars max):**

```
civic,census,county,data,local,government,community,statistics,research,school,housing,economy
```
*(94 characters)*

**Description:**

```
CivicAI: Your Community, Explained

Understand the public data behind your community.

Public data about where you live is abundant — and scattered across a dozen
government websites in formats nobody reads. CivicAI brings it into one place.

• Explore real federal data for any U.S. county: unemployment, income, poverty,
  home values, rent, housing, population, and education
• See ten years of history for every measure, charted and explained
• Ask questions in plain English and get answers drawn only from that data
• Compare your county with anywhere else in the country
• Trace every single statistic back to the dataset it came from

CivicAI never invents a number. Every figure comes from a published federal
dataset, and every screen is one tap from its source, its methodology, and a link
to the original data. When the data can't answer your question, CivicAI says so
instead of guessing.

Built for students, teachers, parents, journalists, and anyone researching their
own community.

Data sources: U.S. Census Bureau (American Community Survey), Bureau of Labor
Statistics (Local Area Unemployment Statistics), and Bureau of Economic Analysis.

Civic data, made simple.
```

**Support URL / Privacy policy URL:** required — a plain page on any host is fine.

## Privacy policy — content to publish

Cover exactly what the app does:

- **Location.** Requested only when the user taps "Detect my county". Used once, on
  device, to reverse-geocode a county name. Coordinates are never transmitted or
  stored. The app works fully without it.
- **What is stored.** The selected county, in `UserDefaults` on the device only.
- **What is sent to the server.** The county's FIPS code, and — when the user asks a
  question — the text of that question.
- **Third parties.** Questions are processed by OpenAI to generate an explanation.
  No user identifier is attached. Data is retrieved from Census, FRED, BLS and BEA.
- **What is not collected.** No accounts, no analytics, no advertising identifiers,
  no tracking across apps or websites.

## App Privacy questionnaire answers

| Question | Answer |
|---|---|
| Does the app collect data? | Yes — "Coarse Location" and "Other User Content" |
| Location: linked to identity? | No |
| Location: used for tracking? | No |
| Location: purpose | App Functionality |
| User content (question text): linked to identity? | No |
| User content: used for tracking? | No |
| User content: purpose | App Functionality |

## Required assets

- [x] App icon 1024×1024 — `ios/CivicAI/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- [ ] Screenshots, 6.7" (1290×2796) — required
- [ ] Screenshots, 6.5" (1284×2778) — required if you don't use 6.7" for all
- [ ] Screenshots, 5.5" (1242×2208) — only if supporting older devices

### Suggested five screenshots

1. **Dashboard** — headline cards, real county, real numbers
2. **Metric detail** — the 10-year chart with a year selected
3. **Ask CivicAI answer** — key findings + chart + "View sources"
4. **Source sheet** — dataset, organization, methodology, last updated
5. **Compare** — two counties side by side

Take them on an iPhone 15 Pro Max simulator with a real backend attached. Do not
use mock data in screenshots; the whole claim of the app is that the numbers are real.

## Review notes to include

```
CivicAI displays U.S. federal public data (Census Bureau ACS, BLS LAUS, BEA) for
any U.S. county, and uses an LLM to summarize that data in plain English.

The AI is constrained to the retrieved datasets: it is given only the county's
loaded metrics, returns structured output through a fixed JSON schema, and its
citations are rebuilt server-side from real metric identifiers, so it cannot cite
a dataset the app does not have. If the data cannot answer a question, the app
says so rather than answering.

The app takes no political position and does not editorialize. Location access is
optional; a full manual county picker is provided.

No account is required. To test, launch and either allow location or search for
"York" and select York County, South Carolina.
```

## Pre-submission checklist

**Build**
- [ ] `CIVICAI_API_BASE_URL` in `Config/Release.xcconfig` is your live HTTPS backend
- [ ] `CIVICAI_APP_KEY` matches `APP_SHARED_SECRET` on the server
- [ ] Backend `/health` reports all three keys `true`
- [ ] `npm run smoke` passes against the production host
- [ ] Archive validates in Xcode Organizer

**Functionality**
- [ ] Launches without crash on iPhone SE and iPhone 15 Pro Max
- [ ] Location picker works via detect, browse, and search
- [ ] 10+ metrics load with real data
- [ ] Charts render and scrub smoothly
- [ ] Ask CivicAI returns a sourced answer end to end
- [ ] Source links open in Safari
- [ ] Airplane mode shows the network error state with a working retry

**Accessibility**
- [ ] VoiceOver reads every card as one coherent phrase
- [ ] Chart data points reachable via the VoiceOver rotor
- [ ] Largest Dynamic Type size — nothing truncated or clipped
- [ ] Reduce Motion — shimmer and press animation are off
- [ ] Contrast checked in both light and dark

**Data integrity**
- [ ] Every displayed number traces to a source with a working URL
- [ ] No hardcoded or placeholder statistics anywhere in the shipped build
- [ ] No API keys in the app binary (`strings` the archive to confirm)
