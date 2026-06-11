# Deploying the backend to Railway

The Go services are plain Docker images built from the repo root with
`infra/docker/go.Dockerfile`, so they map 1:1 onto Railway services.

> **[ACTION REQUIRED]** You need a Railway account (https://railway.app),
> the CLI (`npm i -g @railway/cli`), and `railway login` before any of the
> steps below.

## 1. Provision the project + datastores

```bash
railway init           # create a project, e.g. "cipher-clash"
```

In the Railway dashboard add:

- **PostgreSQL** (plugin) — note the `DATABASE_URL` it provisions.
- **Redis** (plugin) — note host/password (`REDIS_ADDR`, `REDIS_PASSWORD`).
- **RabbitMQ** — Railway has a community template ("RabbitMQ"); deploy it
  inside the project. Alternative: a free CloudAMQP instance, then set
  `RABBITMQ_URL` to its AMQP URL.

## 2. Run migrations once

From any machine that can reach the Railway Postgres:

```bash
psql "$DATABASE_URL" -f infra/postgres/migrations/0001_baseline.up.sql
psql "$DATABASE_URL" -f infra/postgres/migrations/0002_seed.up.sql
```

## 3. Create one Railway service per Go service

For each of the 11 services (minimum for the core loop: `auth`,
`matchmaker`, `puzzle_engine`, `game`; recommended all):

- New Service → GitHub repo → root directory `/`
- Build: Dockerfile `infra/docker/go.Dockerfile`, build arg
  `SERVICE_NAME=<service>` (e.g. `auth`)
- Networking: enable a public domain for services the client calls
  (`auth`, `matchmaker`, `puzzle_engine`, `game`, `tutorial`, `practice`,
  `achievement`, `missions`, `mastery`, `social`, `cosmetics`); the game
  service domain also carries the WebSocket
- Variables (shared across services — use a Railway "shared variables"
  group):

```
DATABASE_URL=<railway postgres url>
REDIS_ADDR=<redis host:port>
REDIS_PASSWORD=<redis password>
RABBITMQ_URL=<amqp url>
JWT_SECRET=<openssl rand -hex 32 — SAME value for every service>
INTERNAL_API_TOKEN=<openssl rand -hex 32 — same for matchmaker/puzzle/game>
PORT=<canonical port for the service, e.g. 8085 for auth>
ALLOWED_ORIGINS=https://<your-vercel-domain>
PUZZLE_ENGINE_URL=http://puzzle_engine.railway.internal:8087   # game service
MATCHMAKER_URL=http://matchmaker.railway.internal:8086         # game service
```

Railway's private networking (`*.railway.internal`) keeps internal
endpoints (`/internal/v1/...`) off the public internet if you front the
public domains with the per-service ports only.

## 4. Point the Vercel frontend at it

Each service gets its own public domain on Railway, so pass them
explicitly:

```bash
cd apps/client
flutter build web --release \
  --dart-define=AUTH_URL=https://auth-xxxx.up.railway.app/api/v1 \
  --dart-define=MATCHMAKER_URL=https://matchmaker-xxxx.up.railway.app/api/v1 \
  --dart-define=PUZZLE_URL=https://puzzle-xxxx.up.railway.app/api/v1 \
  --dart-define=GAME_URL=https://game-xxxx.up.railway.app/api/v1 \
  --dart-define=GAME_WS_URL=wss://game-xxxx.up.railway.app/ws \
  --dart-define=TUTORIAL_URL=... --dart-define=PRACTICE_URL=... \
  --dart-define=ACHIEVEMENT_URL=... --dart-define=MISSIONS_URL=... \
  --dart-define=MASTERY_URL=... --dart-define=SOCIAL_URL=... \
  --dart-define=COSMETICS_URL=...
cp vercel.json build/web/ && cd build/web && vercel deploy --prod --yes
```

The DEMO_MODE deployment (`scripts/deploy_vercel.sh demo`) remains the
zero-dependency fallback if the backend is ever down.
