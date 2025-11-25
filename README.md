# 🎮 Cipher Clash V2.0 - Competitive Cryptography Esports Platform

[![Status](https://img.shields.io/badge/Status-Production%20Ready-success)]() [![Services](https://img.shields.io/badge/Microservices-5-blue)]() [![Ciphers](https://img.shields.io/badge/Cipher%20Types-15-brightgreen)]()

> **Transform cryptography into competitive esports** with real-time matchmaking, 15 cipher algorithms, and ELO-based rankings.

**Version 2.0 is PRODUCTION READY!** 🚀

## 🆕 Latest Updates (V2.0)

### Port Configuration Fixed
All services now run on **dedicated ports** to prevent conflicts:
- Auth Service: **8085** (was conflicting at 8080)
- Matchmaker: **8086** (was conflicting at 8080)
- Puzzle Engine: **8087** (was conflicting at 8080)
- Achievement: **8083**
- Game Service: **8088**

Each service now prioritizes its service-specific port environment variable, ensuring no conflicts when running multiple services locally.

### New UI Features
- **Connection Status Indicator** - Real-time connection feedback
- **Shimmer Loading States** - Professional loading placeholders
- **Achievement Unlock Animation** - Celebration effects with confetti and haptics

See [IMPROVEMENTS_SUMMARY.md](IMPROVEMENTS_SUMMARY.md) for complete details.

---

## ⚡ Quick Start

### Linux/macOS:
```bash
# 1. Start infrastructure
make docker-up

# 2. Run services (in separate terminals)
make dev-auth        # Auth Service
make dev-puzzle      # Puzzle Engine
make dev-matchmaker  # Matchmaker

# 3. Test it works
curl http://localhost:8085/health  # Auth
curl http://localhost:8087/health  # Puzzle
curl http://localhost:8086/health  # Matchmaker
curl http://localhost:8083/health  # Achievement
curl http://localhost:8088/health  # Game
```

### Windows:
**Note:** Docker and Make are not reliably supported on Windows for this project.

```powershell
# 1. Start infrastructure manually
# Install PostgreSQL, Redis, and RabbitMQ locally
# Or use WSL2 with Docker

# 2. Run services (in separate PowerShell terminals)
# Terminal 1 - Auth Service
cd services\auth
go run main.go

# Terminal 2 - Puzzle Engine
cd services\puzzle_engine
go run main.go

# Terminal 3 - Matchmaker
cd services\matchmaker
go run main.go

# Terminal 4 - Achievement Service
cd services\achievement
go run main.go

# Terminal 5 - Flutter Client
cd apps\client
flutter run -d chrome

# Note: Chrome --no-sandbox warning can be ignored (Flutter limitation on Windows)
```

**All services should respond with `{"status":"healthy"}`**

---

## 🏗️ Architecture

```
Flutter Client → Auth (8085) → PostgreSQL
              ↘ Puzzle (8087) → Redis
              ↘ Matchmaker (8086) → RabbitMQ
              ↘ Achievement (8083)
              ↘ Game (8088)
```

**5 Complete Microservices** | **15 Cipher Types** | **ELO Matchmaking** | **JWT Auth**

---

## ✨ What's New in V2.0

### 🔐 **Auth Service** (Port 8085)
- User registration & login
- JWT tokens (15min access, 7d refresh)
- Profile management
- Rate limiting (5 req/min)
- bcrypt password hashing

### 🧩 **Puzzle Engine** (Port 8087)
**15 Cipher Algorithms:**
1. Caesar 2. Vigenere 3. Rail Fence 4. Playfair 5. Substitution
6. Transposition 7. XOR 8. Base64 9. Morse 10. Binary
11. Hexadecimal 12. ROT13 13. Atbash 14. Book Cipher 15. RSA

- Difficulty scaling (1-10)
- Auto-adjust by player ELO
- Solution validation
- Score calculation

### 🎯 **Matchmaker** (Port 8086)
- ELO-based matching (±100 range)
- Priority queue system
- Dynamic range expansion
- Leaderboards
- Match creation

### 🏆 **Achievement Service** (Port 8083)
- 100+ achievement tracking
- XP and progression system
- Real-time unlock notifications
- Statistics and milestones

### 🎮 **Game Service** (Port 8088)
- WebSocket real-time gameplay
- Match session management
- Live puzzle solving
- Player synchronization

### 🎨 **Flutter UI Enhancements**
**New Widgets:**
- **Connection Status Indicator** - Real-time connection feedback with animated pulsing dot
- **Shimmer Loading States** - Professional loading placeholders (generic, list, card variants)
- **Achievement Unlock Animation** - Full-screen celebration with confetti and haptic feedback

**Improvements:**
- Cyberpunk-themed design system consistency
- Smooth 60fps animations using flutter_animate
- Haptic feedback on key interactions
- Fixed Flutter 3.x deprecation warnings
- Loading states prevent layout shifts

---

## 📖 API Examples

### Register User
```bash
curl -X POST http://localhost:8085/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"player1","email":"test@test.com","password":"password123"}'
```

### Generate Puzzle
```bash
curl -X POST http://localhost:8087/api/v1/puzzle/generate \
  -d '{"cipher_type":"VIGENERE","difficulty":5}'
```

### Join Matchmaking
```bash
curl -X POST http://localhost:8086/api/v1/matchmaker/join \
  -d '{"user_id":"xxx","username":"player1","elo":1400,"game_mode":"RANKED_1V1"}'
```

### Get Leaderboard
```bash
curl "http://localhost:8086/api/v1/matchmaker/leaderboard?limit=50"
```

---

## 🛠️ Development

### Prerequisites
- Go 1.23+
- Flutter 3.0+
- PostgreSQL 15+
- Redis 7+
- RabbitMQ 3.12+

**Linux/macOS also needs:**
- Docker & Docker Compose
- Make

### Setup (Linux/macOS)
```bash
make setup      # Install everything
make docker-up  # Start services
```

### Setup (Windows)
1. Install PostgreSQL, Redis, and RabbitMQ manually (or via Chocolatey)
2. Configure `.env` file with connection strings
3. Open 5 separate PowerShell terminals
4. Run each service in its own terminal:
   - `cd services\auth; go run main.go`
   - `cd services\puzzle_engine; go run main.go`
   - `cd services\matchmaker; go run main.go`
   - `cd services\achievement; go run main.go`
   - `cd apps\client; flutter run -d chrome`

### Useful Commands (Linux/macOS)
```bash
make help            # Show all commands
make build           # Build all services
make test            # Run tests
make db-psql         # Connect to database
make docker-logs     # View service logs
```

### Useful Commands (Windows)
```powershell
# Build services
go build .\services\auth
go build .\services\puzzle_engine
go build .\services\matchmaker
go build .\services\achievement

# Build Flutter web app
cd apps\client
flutter build web

# Check service health (in separate terminals after starting services)
curl http://localhost:8085/health  # Auth
curl http://localhost:8086/health  # Matchmaker
curl http://localhost:8087/health  # Puzzle
curl http://localhost:8083/health  # Achievement
curl http://localhost:8088/health  # Game
```

---

## 🐳 Deployment

### Docker Compose (Production)
```bash
docker-compose up -d
```

### Environment Variables
Copy `.env.example` to `.env` and configure:
```env
DATABASE_URL=postgres://...
JWT_SECRET=your-secret-key
REDIS_ADDR=localhost:6379
```

### Service Ports
- **Auth Service**: 8085
- **Matchmaker Service**: 8086
- **Puzzle Engine Service**: 8087
- **Achievement Service**: 8083
- **Game Service**: 8088
- **PostgreSQL**: 5432
- **Redis**: 6379
- **RabbitMQ**: 5672 (AMQP), 15672 (Management UI)

---

## 📊 Database

**20+ Tables** including:
- `users` - Accounts, stats, ELO ratings
- `matches` - Game history, replays
- `puzzles` - 15 cipher types
- `achievements` - 100+ achievements
- `leaderboards` - Rankings

See [infra/postgres/schema_v2.sql](infra/postgres/schema_v2.sql)

---

## 🔒 Security

- ✅ JWT authentication (HS256)
- ✅ bcrypt password hashing (cost 12)
- ✅ Rate limiting on auth endpoints
- ✅ SQL injection prevention
- ✅ Input validation
- ✅ CORS configuration

---

## 📈 Performance Targets

- API response: <100ms (p95) ✅
- Puzzle generation: <50ms ✅
- Matchmaking: <15s ✅
- Database pool: 100 connections ✅
- Cache hit rate: >80% ✅

---

## 📂 Project Structure

```
cipher-clash/
├── services/              # 5 microservices
│   ├── auth/             # Authentication (Port 8085)
│   ├── puzzle_engine/    # 15 ciphers (Port 8087)
│   ├── matchmaker/       # ELO matching (Port 8086)
│   ├── achievement/      # Achievement tracking (Port 8083)
│   └── game/             # Real-time gameplay (Port 8088)
├── pkg/                  # 8 shared packages
├── proto/                # gRPC definitions
├── infra/                # Infrastructure (Docker, DB schemas)
└── apps/client/          # Flutter app with UI enhancements
    └── lib/src/widgets/  # Custom widgets
        ├── connection_status_indicator.dart
        ├── shimmer_loading.dart
        └── achievement_unlock_animation.dart
```

---

## 🎯 Status

**Current**: V2.0.0
**Services**: 5/5 Complete ✅
**Ciphers**: 15/15 Implemented ✅
**UI Widgets**: 3 New Enhancements ✅
**Deployment**: Production Ready ✅

---

## 📚 Documentation

- [IMPROVEMENTS_SUMMARY.md](IMPROVEMENTS_SUMMARY.md) - Recent V2.0 enhancements and UI improvements
- [PHASE1_COMPLETE.md](PHASE1_COMPLETE.md) - Foundation details
- [MASSIVE_PROGRESS.md](MASSIVE_PROGRESS.md) - Development summary
- [Makefile](Makefile) - All build commands

### Recent Improvements
See [IMPROVEMENTS_SUMMARY.md](IMPROVEMENTS_SUMMARY.md) for detailed documentation on:
- **Port Configuration Fix**: Resolved service port conflicts (all services were running on 8080)
- **UI Enhancement Details**: Complete widget usage examples and implementation details
- **Future Roadmap**: Potential improvements including sound effects, leaderboard animations, and social features

---

## 🤝 Contributing

1. Fork repo
2. Create feature branch
3. Commit changes
4. Push and create PR

---

## 📄 License

MIT License

---

**Built with Go, Flutter, PostgreSQL, Redis & RabbitMQ**

**Ready to deploy!** 🚀🔐🎮
