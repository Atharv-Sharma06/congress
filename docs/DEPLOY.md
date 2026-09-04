# Deploying the CivicAI backend

The backend is a plain Node 18+ Express app with no database. Any host that runs
Node and injects environment variables will work. Pick one.

## Environment variables

| Name | Required | Notes |
|---|---|---|
| `CENSUS_API_KEY` | yes | Census rejects keyless requests |
| `FRED_API_KEY` | yes | Unemployment, labor force, per capita income |
| `OPENAI_API_KEY` | yes | Ask CivicAI and the Compare explanation |
| `OPENAI_MODEL` | no | Defaults to `gpt-4o-mini` |
| `PORT` | no | Most hosts set this for you |
| `ALLOWED_ORIGINS` | no | Comma-separated. Leave blank for a native-app-only backend |
| `APP_SHARED_SECRET` | no | Strongly recommended — see below |

### About `APP_SHARED_SECRET`

The iOS app sends it as `x-civicai-key`. It is not user authentication — anyone who
extracts the binary can read it. What it does buy you is that a stranger who finds
your URL cannot casually run up your OpenAI bill. Combined with the per-IP rate
limits, that is proportionate for a public civic-data app. If you later need real
protection, put the backend behind App Attest or a signed-request scheme.

Generate one:

```bash
node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))"
```

Set the same value in the backend environment and in `ios/Config/Release.xcconfig`.

---

## Option A — Fly.io

```bash
cd backend
fly launch --no-deploy          # accept the generated fly.toml
fly secrets set \
  CENSUS_API_KEY=... \
  FRED_API_KEY=... \
  OPENAI_API_KEY=... \
  APP_SHARED_SECRET=...
fly deploy
```

Fly gives you HTTPS on `https://<app>.fly.dev` automatically. Keep at least one
machine warm (`fly scale count 1 --region <yours>`) — the county index warms at boot,
and a cold start otherwise re-fetches it.

## Option B — Render

1. New → Web Service → connect the repo, root directory `backend`.
2. Build `npm install`, start `npm start`.
3. Add the environment variables above.
4. Render provides HTTPS on `https://<service>.onrender.com`.

On the free tier the instance sleeps and loses its in-memory cache. That is
functionally fine — the first request after a sleep is just slower.

## Option C — Railway / any container host

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
ENV PORT=8080
EXPOSE 8080
CMD ["node", "src/server.js"]
```

---

## After deploying

```bash
curl https://your-host/health
```

All three keys should read `true`. Then run the full check:

```bash
cd backend
BASE=https://your-host APP_SHARED_SECRET=... npm run smoke
```

Finally, point the app at it: set `CIVICAI_API_BASE_URL` (and `CIVICAI_APP_KEY`) in
`ios/Config/Release.xcconfig`. The app refuses to start on a non-HTTPS release URL.

## Cost

Census, FRED, BLS and BEA are free. OpenAI is the only metered cost, and only
`/api/ask` and `/api/compare` call it. With `gpt-4o-mini`, 30-minute answer caching
and a 12/min cap, a demo or classroom rollout costs cents. Watch it at
https://platform.openai.com/usage and set a hard billing limit before you publish.

## Operational notes

- **Cache is in-process.** Restarting clears it; multiple instances each keep their
  own. For a bigger deployment, swap `src/cache.js` for Redis behind the same
  `remember(key, ttl, fn)` interface.
- **County index warm-up** runs 51 Census requests at boot, staggered 120ms apart
  (~6 seconds). This is what makes picker search instant.
- **ACS vintages** are listed in `src/config.js` as `acsYears` / `latestAcsYear`.
  When the Census publishes a new 5-year release (each December), add the year to
  the front of `acsYears` and bump `latestAcsYear`. Nothing else changes.
