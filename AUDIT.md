# Cipher Clash — Full Codebase Audit

> **Status: remediation complete.** This document is the *baseline* audit
> the production-hardening effort started from; every Partial/Stubbed/
> Broken/Dead item below has since been fixed or removed (see the commit
> history from `78ff352` onward). It is kept as an honest record of the
> before-state. Current verification: 24/24 API smoke checks, Go `-race`
> suites, an 18-cipher round-trip suite, and Playwright browser E2E against
> both the live stack and the zero-backend demo build.

**Date:** 2026-06-09 · **Auditor:** automated function-by-function review of every service and the Flutter client.
**Classification scale:** `Working` (does what it claims, end to end) · `Partial` (real implementation with gaps) · `Stubbed` (placeholder/mock pretending to work) · `Broken` (incorrect behavior/bug) · `Dead` (unreachable or unused code).

This audit is the baseline for the production-hardening effort. Every `Partial`/`Stubbed`/`Broken` item below is scheduled to be fixed; every `Dead` item to be removed.

---

## 1. Executive summary

The backend is more real than the docs suggest: bcrypt password hashing, JWT access+refresh tokens, 18 cipher implementations, ELO-adaptive difficulty, and time-based ELO range expansion all genuinely exist. The two load-bearing fakes are:

1. **The game service is a mock.** The WebSocket hub broadcasts one of four hardcoded puzzles to *every* connecting client, has no concept of a match/room, no auth, no scoring, no ELO update, no persistence, and no reconnect handling.
2. **The Flutter client fakes the core loop.** The queue screen "finds a match" with a random 15–30 s timer; the live-game screen plays three hardcoded puzzles against a scripted opponent; menu, profile, leaderboard, and achievements render hardcoded mock data; auth can be bypassed with a "SKIP FOR DEV" button.

Additional systemic problems: three conflicting port schemes (docker-compose 8080–8083 vs code defaults 8083–8093 vs README), docker-compose defines only 4 of 11 services, missions and practice both default to port 8090, migrations are numbered 001/001/003, and the matchmaker contains a mathematically broken `pow10` used in ELO expected-score calculation.

---

## 2. Backend services

### 2.1 auth (port 8085) — **Working**

| Component | Status | Evidence |
|---|---|---|
| bcrypt password hashing | Working | `pkg/auth/password.go` — `bcrypt.GenerateFromPassword`, cost 12. README claim verified true. |
| JWT access + refresh | Working | `pkg/auth/jwt.go` — HS256, typed claims (access 15 m / refresh 7 d), `ValidateToken` enforces token type. |
| register/login/refresh/profile/logout | Working | `services/auth/internal/handler`, Redis-backed login rate limiting. |
| Auth middleware | Working | `services/auth/internal/middleware/auth_middleware.go` — no server-side bypass exists. |
| `services/auth/internal/jwt/token.go` | **Dead** | Second, unused JWT implementation with hardcoded secret `super-secret-key-change-me`. `main.go` uses `pkg/auth.NewJWTManager(cfg.JWT)`. Must be deleted (secret hygiene). |

### 2.2 puzzle_engine (port 8087) — **Working**

| Component | Status | Evidence |
|---|---|---|
| Cipher algorithms | Working | `services/puzzle_engine/internal/ciphers/all_ciphers.go` — **18 ciphers**: the 15 README-claimed (CAESAR, VIGENERE, RAIL_FENCE, PLAYFAIR, SUBSTITUTION, TRANSPOSITION, XOR, BASE64, MORSE, BINARY, HEXADECIMAL, ROT13, ATBASH, BOOK_CIPHER, RSA_SIMPLE) plus AFFINE, AUTOKEY, ENIGMA_LITE. |
| ELO-adaptive difficulty | Working | `internal/service/puzzle_service.go:254` — `difficulty = (elo-1200)/200 + 3`, clamped 1–10. README claim verified true. |
| generate/validate/get endpoints | Working | Includes scoring (base × difficulty, time bonus) and puzzle stats tracking. |
| Solution exposure for internal callers | Missing | No way for the game service to obtain plaintext for server-side validation. Needed for real matches. |

### 2.3 matchmaker (port 8086) — **Partial / Broken in spots**

| Component | Status | Evidence |
|---|---|---|
| Queue + ELO range expansion | Working | `internal/queue/matchmaking_queue.go` — starts ±100, +50 per 15 s waited, cap 500; RWMutex-guarded. README claim verified true. |
| "Priority queue" | **Partial** | Resume claims a priority queue; implementation is `map[gameMode][]*QueueEntry` with FIFO scan — no heap/priority structure exists. |
| `pow10()` | **Broken** | `internal/service/matchmaker_service.go:382` — computes `1.1^(10x)` ≈ `10^0.414x`, and returns 1.0 for negative exponents. Used in ELO expected-score → ratings math is wrong whenever it runs. |
| `/status` wait time | **Broken** | Returns `entry.QueuedAt.Unix()` (an epoch timestamp) as `wait_time_seconds`. |
| Match-found handoff to client | **Missing** | `createMatch` (line 314) inserts the match row and publishes `match.created`, but the client has no way to learn a match was found — `/status` doesn't report it. (The client fakes it; see §3.) |
| Glicko-2 | Stubbed | `internal/matchmaking/glicko.go` — labeled Glicko-2, actually simplified ELO (K=32) with phi inflation. Constants declared, unused. |
| Leaderboard endpoint | Working | `/api/v1/matchmaker/leaderboard` queries users by ELO. |
| Active season | Partial | `seasonID := 1 // TODO` hardcoded (line 316). |

### 2.4 game (port 8088) — **Stubbed (the critical gap)**

| Component | Status | Evidence |
|---|---|---|
| WebSocket hub | **Stubbed** | `internal/hub.go:47-93` — on every connection, sleeps 500 ms and sends `MATCH_STARTED` with `match_id: "mock-match-123"`, opponent `NEMESIS_X`, and one of 4 hardcoded puzzles. |
| Match rooms | Missing | One global hub; every client's messages are broadcast to *all* clients (`readPump` → `broadcast`). |
| WS authentication | Missing | `/ws` upgrades any request; `CheckOrigin` returns true unconditionally. |
| Match scoring / winner / ELO update | Missing | No result handling of any kind. |
| Persistence | Missing | Never writes `matches` / `match_participants` / `puzzle_attempts` despite schema support (incl. `matches.replay_data`). |
| Disconnect/reconnect | Missing | Client removed from map on error; no session, no resync, no forfeit logic. |
| RabbitMQ `match.created` consumption | Missing | Matchmaker publishes; nobody consumes. The two halves of matchmaking were never connected. |

### 2.5 achievement (port 8083) — **Partial**

CRUD endpoints (list, detail, user achievements, progress, stats) work against real tables. Gaps: no event consumer — nothing ever *unlocks* an achievement from gameplay; `// TODO: Award XP to user` (`internal/service/achievement_service.go:261`).

### 2.6 tutorial (port 8089) — **Working**

Steps + progress endpoints function. Client tutorial screen exists but tracks progress locally only (not wired to this service).

### 2.7 practice (port 8090) — **Working**

The one long-tail service genuinely wired end-to-end: client practice lobby/session → generate/submit/history/leaderboard endpoints → puzzle_engine. Four modes (UNTIMED/TIMED/SPEED_RUN/ACCURACY).

### 2.8 missions (port **8090 — collides with practice**) — **Partial**

Full template/assign/progress/complete/claim/refresh API exists, but: default port duplicates practice (both 8090 — they cannot run together); claim has `// TODO: Add rewards to user wallet/profile` (`internal/service/missions_service.go:247`); no event consumer, so progress only moves via manual POST; client never calls it (menu's "daily quests" UI is hardcoded).

### 2.9 mastery (port 8091) — **Partial**

Per-cipher XP/tier endpoints work; nothing feeds it (no event consumer, no client calls).

### 2.10 social (port 8092) — **Partial**

Friends/invites/spectator CRUD endpoints work against real tables; zero client integration; spectator endpoints have no live-match backend to attach to (game service has no rooms).

### 2.11 cosmetics (port 8093) — **Partial + Dead code**

Catalog/inventory/loadout/purchase endpoints work, but purchase doesn't validate or deduct coins (`internal/service/cosmetics_service.go:110` TODO). `internal/all_in_one.go` is a second, unwired copy of the whole service (Dead) with its own duplicate TODO at line 242. No client integration.

---

## 3. Flutter client (`apps/client`)

| Screen / module | Status | Evidence |
|---|---|---|
| Login / Register | Partial | Real calls to auth service; **"SKIP FOR DEV" button** (`login_screen.dart` ~line 340) injects `dev-mock-token` via `AuthService.setDevMockAuth()` and bypasses auth entirely. |
| Token handling | **Broken** | Tokens held in static in-memory vars (`auth_service.dart`) — lost on refresh; `refreshAccessToken()` exists but is never called; `flutter_secure_storage`/`hive` declared in pubspec, unused. |
| Main menu | Stubbed | Hardcoded user stats and daily quests (`main_menu_screen.dart:20-28`). |
| Matchmaking mode select | Working | UI only; mode selection real. |
| Queue screen | **Stubbed** | `queue_screen.dart:59-72` — `Timer.periodic` + comment `// Simulate match found after random time (15-30 seconds)`; never told by the backend about a real match. Join/leave/status calls exist in `matchmaker_service.dart` but the found-match path is fiction. |
| Live game | **Stubbed** | `enhanced_game_screen.dart:34-56` — three hardcoded puzzles (all solving to "HELLO WORLD"), scripted opponent; **does not use WebSocket at all**. |
| WebSocket client | Dead | `features/game/game_service.dart` (Riverpod + `web_socket_channel`) is only referenced by `duel_screen.dart`, which is unreachable from the app's routes. |
| Match summary | Partial | Polished UI (confetti, ELO count-up) fed by faked inputs. |
| Leaderboard | Stubbed | Hardcoded list (`leaderboard_screen.dart:19-28`); refresh marked TODO. Real endpoint exists server-side. |
| Profile | Stubbed | All stats/matches/achievements hardcoded (`profile_screen.dart:19-39`). |
| Achievements | Stubbed | Hardcoded list; `// TODO: replace with API call`. |
| Settings | Partial | Toggles render; persistence TODO. |
| Practice lobby/session | Working | Real generate/submit against practice service. |
| Tutorial | Partial | 8 interactive steps with real cipher widgets; progress/XP local-only. |
| Social | Dead | Route renders "Social features coming soon!". |
| API configuration | **Broken (for deploy)** | `api_config.dart` hardcodes `http://localhost:8083-8092` and `ws://localhost:8088/ws`; no `--dart-define` support — undeployable without code edits. |
| Models | Risk | No typed model layer; ad-hoc `Map<String,dynamic>` parsing throughout (snake_case mismatch risk). |
| Theme | Working | Coherent cyberpunk system (`app_theme.dart`): cyber blue/neon purple/green on dark, Space Grotesk/Inter/JetBrains Mono, 8 px spacing scale. Needs consistent application + loading/empty/error states. |
| Dependencies | Dead weight | `dio`, `grpc`, `protobuf`, `hive`, `flutter_secure_storage`, `provider` declared but unused. |

Dart `TODO` count: 21. Go `TODO` count: 5 (all listed above).

---

## 4. Cross-cutting findings

| Finding | Status | Detail |
|---|---|---|
| Port chaos | **Broken** | docker-compose maps 8080–8083 for 4 services; code defaults are 8083–8093 for 11; README documents a third mix. `START_EVERYTHING.bat` uses 8085–8089. Nothing agrees. |
| docker-compose coverage | Partial | Only auth/matchmaker/puzzle/game defined; the other 7 services have no compose entry. |
| missions vs practice | **Broken** | Both default to port 8090 — cannot run simultaneously. |
| Migrations | **Broken** | `infra/postgres/migrations/` contains `001_initial_schema.*`, `001_new_features_v2.sql` (duplicate number, no down), `003_add_engagement_features.sql` (no 002). Compose *also* initdb-mounts `schema_v2.sql`, so fresh containers and migration runs diverge. |
| Secrets | Mostly OK | `.gitignore` covers `.env`; `.env.example` uses placeholders. One hardcoded secret in dead code (`services/auth/internal/jwt/token.go`) — delete. Makefile dev targets embed `postgres:password` (local-dev only, acceptable but will be env-driven). |
| RabbitMQ topology | Partial | `pkg/messaging` defines exchanges/events (`match.created`, `match.completed`, `achievement.unlocked`); only `match.created` is ever published and **nothing consumes any event**. |
| proto/ | Dead (as transport) | 11 .proto files; all services speak REST/JSON. Kept as documentation; no gRPC code generated into the build. |
| Stale docs | Dead | `COMPILATION_FIXES.md`, `IMPLEMENTATION_COMPLETE.md`, `IMPLEMENTATION_GUIDE.md`, `PHASE1_SUMMARY.md` describe interim states that no longer match the code; superseded by this audit (removed in this commit). |
| README | Overclaims | "PRODUCTION READY", "6 complete services" (repo has 11 at varying completeness), port table wrong. Rewrite scheduled as final phase. |
| CI | Partial | `.github/workflows/{backend,flutter}.yml` reference Docker Hub/Firebase/SSH secrets that don't exist in this repo's settings; deploy jobs are aspirational. |

---

## 5. Resume-claim verification

| Claim | Verdict today | Action |
|---|---|---|
| 6 Go microservices (auth, matchmaker, puzzle_engine, game live) | 11 directories exist; game is a mock | Finish all 11 to the same bar (decision: keep all). |
| 15 cipher algorithms incl. RSA, Vigenère, Playfair, XOR | **True** — 18 implemented | Keep; exercise all in tests. |
| ELO-adaptive difficulty | **True** | Keep; wire into live matches (currently only generate-time). |
| Priority-queue matchmaking + dynamic range expansion | Half-true — expansion real, priority queue absent | Implement `container/heap` queue. |
| WebSocket-synchronized live matches | **False** — mock hub, client doesn't use WS | Full game-service rewrite + client match screen. |
| JWT auth with access + refresh | **True** server-side | Client must persist tokens + use refresh; remove dev bypass. |
| bcrypt password hashing (README) | **True** | None. |

## 6. Fix plan

Remediation proceeds in 16 incremental commits (config canonicalization → matchmaker fixes → game-service room engine with bot opponent, replay, reconnect → event consumers for achievement/missions/mastery → client real-data wiring + UI overhaul → DEMO_MODE → `./start.sh` → deploy + honest README). Each commit leaves `main` buildable.
