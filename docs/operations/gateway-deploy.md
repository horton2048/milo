# MILO AI Gateway · Deployment Guide

The gateway is a plain Express + TypeScript service that proxies `/v1/recall/*`
to the MiniMax upstream. It runs anywhere Node 20+ runs. Pick the option
below that matches where you already have an account.

## Prerequisite

1. Get a MiniMax API key from the MiniMax platform console.
2. **Never** commit it. Inject it as an environment variable on the
   platform you pick.

## 0. Local sanity check

```bash
cd services/ai-gateway
cp .env.example .env
# edit .env, paste your key
npm install
npm test            # 15 tests must pass
npm run build       # tsc → dist/
npm run dev         # http://127.0.0.1:8787
# in another terminal:
curl http://127.0.0.1:8787/health
# expect: {"ok":true,"requestId":"req-..."}
```

## Option A · Vercel (zero-config, free tier)

```bash
npm i -g vercel
cd services/ai-gateway
vercel deploy --prod
```

Then in the Vercel dashboard:

- Project Settings → Environment Variables:
  - `MINIMAX_API_KEY` = your key (Production)
  - `MINIMAX_BASE_URL` = `https://api.minimax.chat/v1` (optional)
  - `MINIMAX_MODEL` = `MiniMax-M2.7` (optional)

The included `vercel.json` + `api/index.js` mount the Express app as a
single Serverless Function.

Health check:
```bash
curl https://<your-project>.vercel.app/health
```

## Option B · Fly.io (single region, containerized)

```bash
brew install flyctl
cd services/ai-gateway
fly launch --copy-config --no-deploy    # creates the app, uses fly.toml
fly secrets set MINIMAX_API_KEY=<your-key>
fly deploy
```

Health check (the included `fly.toml` already configures this on `/health`):
```bash
curl https://milo-gateway.fly.dev/health
```

## Option C · Railway (one-click)

```bash
npm i -g @railway/cli
cd services/ai-gateway
railway init
railway variables set MINIMAX_API_KEY=<your-key>
railway up
```

Railway auto-detects the included `Dockerfile` and exposes `/health`.

## Option D · Plain Docker (your own VPS)

```bash
cd services/ai-gateway
cp .env.example .env   # edit, paste key
docker build -t milo-gateway .
docker run --rm -d \
  --name milo-gateway \
  -p 8787:8787 \
  --env-file .env \
  milo-gateway
```

Health check:
```bash
curl http://<server>:8787/health
```

## Where to plug the URL into the HarmonyOS app

After the gateway is live, edit
`apps/harmony/entry/src/main/ets/core/config/AppConfig.ets` and set
`GATEWAY_BASE_URL` to your HTTPS URL. The committed empty value deliberately
keeps the app in its offline-first fallback mode; it never attempts a
developer-machine loopback address on a user device.

Rebuild:
```bash
cd apps/harmony
./hvigorw assembleHap
```

The HarmonyOS app then talks to the public gateway automatically.

## Security checklist

- [ ] Gateway is HTTPS (Vercel / Fly / Railway do this automatically)
- [ ] `MINIMAX_API_KEY` is set as a secret, never committed
- [ ] Rate limit stays at the default (60/min/IP)
- [ ] Logs rotate every 7 days (default Express logging only; no persistent storage)
- [ ] The HarmonyOS bundle name stays `com.milo.echoes` (matches AGC)
