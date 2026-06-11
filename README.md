# Cipher Clash

**A real-time competitive cryptography game.** Two players race to decrypt
the same set of classical ciphers over a live WebSocket match; ELO ratings,
adaptive difficulty, achievements, daily missions, and a coin economy hang
off the result. Built as 11 Go microservices with a Flutter web client.

[![Backend CI](https://github.com/swarit-1/cipher-clash/actions/workflows/backend.yml/badge.svg)](https://github.com/swarit-1/cipher-clash/actions/workflows/backend.yml)
[![Flutter CI](https://github.com/swarit-1/cipher-clash/actions/workflows/flutter.yml/badge.svg)](https://github.com/swarit-1/cipher-clash/actions/workflows/flutter.yml)

> **Live demo:** the Vercel deployment runs in `DEMO_MODE` — the full game
> (matchmaking, live matches vs. a bot, leaderboard, achievements, shop,
> replays) is playable in the browser with no backend at all.
> *(URL added after `vercel login` + `scripts/deploy_vercel.sh demo`.)*

---

## One-command start

```bash
git clone https://github.com/swarit-1/cipher-clash && cd cipher-clash
./start.sh
```

That boots PostgreSQL/Redis/RabbitMQ (Docker), generates a `.env` with
random secrets, applies migrations, builds and launches all 11 services
with health checks, prints a status table, and serves the web client at
**http://localhost:3000**. Open a second (incognito) tab and register a
second account to play a live 1v1; queue alone and a bot challenges you
after 25 seconds.

Prereqs: Docker, Go ≥1.23 (`brew install go`), Flutter
(`brew install --cask flutter`).

Other entry points: `./start.sh stop|status|logs`, `make smoke` (24-check
API test of the core loop), `make test` (Go race-detector tests + 18-cipher
round-trip suite), `cd apps/client && flutter test`.

## The core loop (all real, end to end)

register → login (bcrypt + JWT access/refresh) → priority-queue
matchmaking with ELO range expansion → live WebSocket match (first to
solve 3 of 5 puzzles, difficulty scaled to the players' rating) →
server-side validation → ELO + win/loss persistence → leaderboard →
achievements/missions/mastery updated via RabbitMQ events → replay stored
and watchable.

## Architecture

```
                       Flutter web client (:3000)
                                  │ REST + WebSocket
   ┌──────────┬──────────┬───────┴────┬───────────┬────────────┐
   │ auth     │matchmaker│ puzzle     │ game      │ 7 more     │
   │ :8085    │ :8086    │ engine     │ :8088     │ services   │
   │ JWT      │ heap PQ  │ :8087      │ WS rooms  │ 8083-8093  │
   │ bcrypt   │ ELO      │ 18 ciphers │ bot, ELO  │            │
   └────┬─────┴────┬─────┴─────┬──────┴────┬──────┴─────┬──────┘
        │          │           │           │            │
   PostgreSQL    Redis     RabbitMQ ── match.created / match.completed
   (one schema) (queues,   (event fan-out to achievement, missions,
                 sessions)  mastery consumers)
```

| Service | Port | Role |
|---|---|---|
| achievement | 8083 | unlock evaluation from match events, XP awards |
| missions | 8084 | daily/weekly missions, coin/XP claims |
| auth | 8085 | bcrypt registration, JWT access+refresh, profiles |
| matchmaker | 8086 | `container/heap` priority queue, ±100→±500 ELO range expansion, ratings, leaderboard |
| puzzle_engine | 8087 | 18 cipher implementations, ELO-adaptive difficulty (1–10) |
| game | 8088 | per-match WebSocket rooms, server-side validation, bot opponent, reconnect/forfeit, replays |
| tutorial | 8089 | guided onboarding steps |
| practice | 8090 | solo training with personal bests |
| mastery | 8091 | per-cipher XP and levels |
| social | 8092 | friends, challenge invites (create real matches), spectators |
| cosmetics | 8093 | shop with coin-validated purchases |

**Ciphers (18):** Caesar, Vigenère, Rail Fence, Playfair, Substitution,
Transposition, XOR, Base64, Morse, Binary, Hexadecimal, ROT13, Atbash,
Book Cipher, RSA (simplified), Affine, Autokey, Enigma-lite. Every one is
covered by an encrypt→decrypt round-trip test at all 10 difficulties.

### Details worth reading

- **Matchmaking** ([services/matchmaker/internal/queue](services/matchmaker/internal/queue/matchmaking_queue.go)) —
  a `container/heap` min-heap per game mode keyed by wait time; the ELO
  search window starts at ±100 and widens +50 every 15s (cap ±500).
  Found matches hand off via Redis assignment keys surfaced by the
  status poll, plus a `match.created` event to the game service.
- **Match rooms** ([services/game/internal/room](services/game/internal/room/room.go)) —
  one goroutine owns each match's state, fed by a single command channel
  (race-free by construction; verified with `-race` tests). Disconnects
  start a 45s forfeit timer; reconnecting with the same JWT + match id
  cancels it and resyncs via `ROOM_STATE`.
- **Bot opponent** ([services/game/internal/bot](services/game/internal/bot/bot.go)) —
  implements the same `Participant` interface as a WebSocket client, so
  rooms are opponent-agnostic. Solve pace scales with difficulty and
  relative rating, with jitter and occasional fumbles.
- **Replays** — every match stores a timestamped event log
  (`matches.replay_data`); the client plays it back with a scrubber.
- **DEMO_MODE** ([apps/client/lib/src/data/demo](apps/client/lib/src/data/demo)) —
  a compile-time flag swaps the HTTP transport and the game socket for
  in-memory simulations speaking the same protocol, with puzzles
  pre-generated by the real Go cipher code. The static site is fully
  playable offline-from-backend.

## Deployment

**Frontend (Vercel)** — Vercel hosts only the static Flutter build; the
Go services, WebSockets, and databases cannot run there.

```bash
vercel login                      # once
cd apps/client && vercel link     # once
scripts/deploy_vercel.sh demo     # zero-backend, fully playable demo
scripts/deploy_vercel.sh live https://your-api-host   # against a real backend
```

**Backend (Railway)** — each service deploys from
`infra/docker/go.Dockerfile` with a `SERVICE_NAME` build arg, plus managed
Postgres/Redis and a RabbitMQ template. Step-by-step:
[deploy/RAILWAY.md](deploy/RAILWAY.md).

## Project layout

```
apps/client/          Flutter web client (Riverpod, cyberpunk design system)
services/<name>/      one Go module path per microservice (single go.mod)
pkg/                  shared: JWT+bcrypt, Postgres, Redis, RabbitMQ, CORS, logging
infra/postgres/       squashed migrations (0001 baseline, 0002 seed) + runner
infra/docker/         multi-stage Dockerfiles (Go services, Flutter+nginx)
scripts/              migrate.sh, smoke.sh, deploy_vercel.sh
start.sh              the one-command launcher
AUDIT.md              the honest pre-rewrite audit this work started from
```

## What I built / fixed (highlights)

This repo started as a partially-working prototype; see [AUDIT.md](AUDIT.md)
for the full before-state. The headline work:

- Replaced a mock WebSocket hub with a real room engine: per-match state,
  JWT-authed sockets, server-side validation, reconnect/forfeit handling,
  ELO settlement via an internal matchmaker API, replay recording, and a
  bot opponent.
- Made matchmaking literal: heap-based priority queue, corrected ELO
  expected-score math, and a real match-found handoff to clients.
- Fixed four broken ciphers (XOR decrypt, Autokey keystream, Book cipher
  alphabet coverage, config type panics) and pinned all 18 with a
  round-trip test suite.
- Rewired the entire client from hardcoded mock data to live services,
  with persisted sessions, refresh-token rotation, and consistent
  loading/empty/error states; added social, shop, replay, spectate, and
  an in-match "how this cipher works" codex.
- Event-drove progression: match results fan out over RabbitMQ to
  achievements (with XP awards), missions (with coin claims), and
  per-cipher mastery.
- Verified end to end: 24-check API smoke test, Go `-race` suites,
  18-cipher round-trips, and a Playwright browser run of
  register → bot match → results → leaderboard against both the real
  stack and the demo build.

## License

MIT
