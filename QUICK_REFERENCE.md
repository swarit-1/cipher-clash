# 🚀 Cipher Clash V2.0 - Quick Reference Guide

## ⚡ Essential Commands

### Start Everything
```bash
make docker-up          # Start infrastructure (PostgreSQL, Redis, RabbitMQ)
make dev-auth           # Terminal 1: Auth service (8080)
make dev-puzzle         # Terminal 2: Puzzle engine (8082)
make dev-matchmaker     # Terminal 3: Matchmaker (8081)
```

### Health Checks
```bash
curl http://localhost:8080/health  # Auth
curl http://localhost:8082/health  # Puzzle
curl http://localhost:8081/health  # Matchmaker
```

### Run Integration Tests
```bash
make test-integration-win  # Windows
make test-integration      # Linux/Mac
```

---

## 📡 API Quick Reference

### Authentication (Port 8080)

#### Register User
```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "player1",
    "email": "test@test.com",
    "password": "password123",
    "region": "US"
  }'
```

**Response:**
```json
{
  "user": {
    "id": "uuid",
    "username": "player1",
    "email": "test@test.com",
    "elo_rating": 1200,
    "rank_tier": "UNRANKED"
  },
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "expires_in": 900
}
```

#### Login
```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@test.com",
    "password": "password123"
  }'
```

#### Get Profile (Protected)
```bash
curl http://localhost:8080/api/v1/auth/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

#### Refresh Token
```bash
curl -X POST http://localhost:8080/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "YOUR_REFRESH_TOKEN"}'
```

---

### Puzzle Engine (Port 8082)

#### Generate Puzzle (Specific Cipher)
```bash
curl -X POST http://localhost:8082/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{
    "cipher_type": "VIGENERE",
    "difficulty": 5
  }'
```

**Available Cipher Types:**
- `CAESAR` - Simple shift cipher
- `VIGENERE` - Keyword polyalphabetic
- `RAIL_FENCE` - Zigzag transposition
- `PLAYFAIR` - 5×5 grid digraph
- `SUBSTITUTION` - Random alphabet
- `TRANSPOSITION` - Columnar
- `XOR` - Bitwise encryption
- `BASE64` - Standard encoding
- `MORSE` - International Morse
- `BINARY` - 8-bit binary
- `HEXADECIMAL` - Hex encoding
- `ROT13` - Fixed shift (13)
- `ATBASH` - Reverse alphabet
- `BOOK_CIPHER` - Position-based
- `RSA_SIMPLE` - Simplified RSA

#### Generate Random Puzzle (Auto-difficulty)
```bash
curl -X POST http://localhost:8082/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{
    "difficulty": 7,
    "player_elo": 1400
  }'
```

**Response:**
```json
{
  "id": "uuid",
  "cipher_type": "VIGENERE",
  "difficulty": 7,
  "encrypted_text": "RIJVS AVDPY",
  "plaintext": "HELLO WORLD",
  "config": {
    "keyword": "LEMON"
  },
  "time_limit": 120,
  "base_score": 700
}
```

#### Validate Solution
```bash
curl -X POST http://localhost:8082/api/v1/puzzle/validate \
  -H "Content-Type: application/json" \
  -d '{
    "puzzle_id": "PUZZLE_UUID",
    "solution": "HELLO WORLD",
    "solve_time_ms": 25000
  }'
```

**Response:**
```json
{
  "is_correct": true,
  "accuracy": 100.0,
  "score": 840,
  "correct_solution": "HELLO WORLD",
  "time_bonus": 1.2
}
```

---

### Matchmaker (Port 8081)

#### Join Queue
```bash
curl -X POST http://localhost:8081/api/v1/matchmaker/join \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER_UUID",
    "username": "player1",
    "elo": 1400,
    "game_mode": "RANKED_1V1",
    "region": "US"
  }'
```

**Response:**
```json
{
  "queue_id": "USER_UUID",
  "estimated_wait_time_seconds": 15,
  "players_in_queue": 8,
  "position": 8
}
```

#### Queue Status
```bash
curl "http://localhost:8081/api/v1/matchmaker/status?user_id=USER_UUID"
```

**Response:**
```json
{
  "in_queue": true,
  "wait_time_seconds": 12,
  "players_in_queue": 10,
  "game_mode": "RANKED_1V1",
  "search_range": 150
}
```

#### Leave Queue
```bash
curl -X POST http://localhost:8081/api/v1/matchmaker/leave \
  -H "Content-Type: application/json" \
  -d '{"user_id": "USER_UUID"}'
```

#### Get Leaderboard
```bash
curl "http://localhost:8081/api/v1/matchmaker/leaderboard?limit=50&offset=0"
```

**Response:**
```json
{
  "entries": [
    {
      "rank": 1,
      "user_id": "uuid",
      "username": "topplayer",
      "elo_rating": 2150,
      "rank_tier": "DIAMOND",
      "total_games": 250,
      "wins": 180,
      "losses": 70,
      "win_rate": 72.0,
      "win_streak": 12
    }
  ],
  "total_count": 50,
  "limit": 50,
  "offset": 0
}
```

#### Regional Leaderboard
```bash
curl "http://localhost:8081/api/v1/matchmaker/leaderboard?region=US&limit=10"
```

---

## 🎮 Game Flow Example

### 1. User Registration & Login
```bash
# Register
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"player1","email":"test@test.com","password":"pass123","region":"US"}')

# Extract tokens
ACCESS_TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.access_token')
USER_ID=$(echo $REGISTER_RESPONSE | jq -r '.user.id')
```

### 2. Join Matchmaking
```bash
# Join queue
curl -X POST http://localhost:8081/api/v1/matchmaker/join \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_ID\",\"username\":\"player1\",\"elo\":1200,\"game_mode\":\"RANKED_1V1\"}"
```

### 3. Get Puzzle
```bash
# Generate puzzle
PUZZLE=$(curl -s -X POST http://localhost:8082/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{"difficulty":5}')

PUZZLE_ID=$(echo $PUZZLE | jq -r '.id')
ENCRYPTED_TEXT=$(echo $PUZZLE | jq -r '.encrypted_text')
```

### 4. Solve & Submit
```bash
# Submit solution
curl -X POST http://localhost:8082/api/v1/puzzle/validate \
  -H "Content-Type: application/json" \
  -d "{\"puzzle_id\":\"$PUZZLE_ID\",\"solution\":\"YOUR SOLUTION\",\"solve_time_ms\":30000}"
```

### 5. Check Leaderboard
```bash
curl "http://localhost:8081/api/v1/matchmaker/leaderboard?limit=10"
```

---

## 🔧 Development Commands

### Database
```bash
make db-psql          # Connect to PostgreSQL
make db-reset         # Drop and recreate database
make migrate-up       # Run migrations
make migrate-down     # Rollback last migration
```

**Inside PostgreSQL:**
```sql
\dt                           -- List all tables
\d users                      -- Describe users table
SELECT * FROM game_modes;     -- View game modes
SELECT * FROM seasons WHERE is_active = TRUE;  -- Current season
SELECT COUNT(*) FROM users;   -- User count
```

### Docker
```bash
make docker-up        # Start all infrastructure
make docker-down      # Stop all services
make docker-logs      # View logs
make docker-clean     # Remove all containers & volumes
```

### Build
```bash
make build            # Build all Go services
make build-docker     # Build Docker images
make clean            # Clean build artifacts
```

### Testing
```bash
make test                    # Run unit tests
make test-coverage           # Generate coverage report
make test-integration-win    # Run integration tests
```

---

## 📊 Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Client (Web/Mobile)             │
└────────────┬────────────┬────────────┬───────────────────────┘
             │            │            │
             ↓            ↓            ↓
      ┌──────────┐ ┌──────────┐ ┌──────────┐
      │   Auth   │ │  Puzzle  │ │Matchmaker│
      │  :8080   │ │  :8082   │ │  :8081   │
      └────┬─────┘ └────┬─────┘ └────┬─────┘
           │            │            │
           ↓            ↓            ↓
      ┌────────────────────────────────────┐
      │         PostgreSQL :5432           │
      └────────────────────────────────────┘
           ↓            ↓            ↓
      ┌──────────┐ ┌──────────┐ ┌──────────┐
      │  Redis   │ │ RabbitMQ │ │   Game   │
      │  :6379   │ │  :5672   │ │  :8083   │
      └──────────┘ └──────────┘ └──────────┘
```

---

## 🎯 Difficulty Levels

| Level | Description | Recommended Ciphers |
|-------|-------------|---------------------|
| 1-3   | Easy        | Caesar, ROT13, Atbash, Binary, Hex |
| 4-6   | Medium      | Vigenere, Substitution, Rail Fence, Morse |
| 7-8   | Hard        | Playfair, Transposition, XOR |
| 9-10  | Expert      | Book Cipher, RSA Simple |

**Auto-Difficulty Formula:**
```
difficulty = min(10, max(1, (elo - 1000) / 100))
```
- ELO 1200 → Difficulty 2
- ELO 1400 → Difficulty 4
- ELO 1800 → Difficulty 8
- ELO 2000+ → Difficulty 10

---

## 🏆 Rank Tiers

| Tier | ELO Range |
|------|-----------|
| UNRANKED | < 1000 |
| BRONZE | 1000-1199 |
| SILVER | 1200-1399 |
| GOLD | 1400-1599 |
| PLATINUM | 1600-1799 |
| DIAMOND | 1800+ |

---

## 🔒 Security Notes

### JWT Tokens
- **Access Token**: 15 minutes TTL
- **Refresh Token**: 7 days TTL
- **Algorithm**: HS256
- **Secret**: Set via `JWT_SECRET` env var (change in production!)

### Rate Limiting
- **Registration**: 5 requests/minute per IP
- **Login**: 5 requests/minute per IP
- **Other endpoints**: No limit (implement as needed)

### Password Requirements
- Minimum 8 characters
- Must contain letters and numbers (recommended)
- Hashed with bcrypt (cost 12)

---

## 🐛 Troubleshooting

### Service won't start
```bash
# Check if port is in use
netstat -ano | findstr :8080   # Windows
lsof -i :8080                  # Mac/Linux

# Check logs
make docker-logs

# Restart infrastructure
make docker-down
make docker-up
```

### Database connection error
```bash
# Verify PostgreSQL is running
docker ps | grep postgres

# Check connection
docker exec -it cipher-clash-1-postgres-1 psql -U postgres -c "SELECT 1"

# Reset database
make db-reset
```

### Redis not working
```bash
# Test Redis connection
docker exec -it cipher-clash-1-redis-1 redis-cli ping
# Should return: PONG
```

### RabbitMQ issues
```bash
# Check RabbitMQ status
docker exec -it cipher-clash-1-rabbitmq-1 rabbitmq-diagnostics ping

# Access management UI
# Open: http://localhost:15672
# User: admin, Password: password
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| [README.md](README.md) | Main project documentation |
| [FINAL_SUMMARY.md](FINAL_SUMMARY.md) | V2.0 transformation summary |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Production deployment |
| [TRANSFORMATION_STATUS.md](TRANSFORMATION_STATUS.md) | Overall project status |
| [FLUTTER_INTEGRATION.md](FLUTTER_INTEGRATION.md) | Flutter client integration |
| [PHASE1_COMPLETE.md](PHASE1_COMPLETE.md) | Foundation details |
| [.env.example](.env.example) | Environment variables template |

---

## 🚀 Production Deployment

### Quick Deploy
```bash
# Copy environment template
cp .env.example .env

# Edit with production values
nano .env

# Deploy with Docker
docker-compose up -d

# Verify all services are healthy
curl http://your-domain.com/health
```

### Production Checklist
- [ ] Change `JWT_SECRET` to random 32+ character string
- [ ] Update `DATABASE_URL` with production credentials
- [ ] Set `ENVIRONMENT=production`
- [ ] Configure SSL/TLS certificates
- [ ] Set up reverse proxy (Nginx)
- [ ] Enable rate limiting
- [ ] Configure monitoring (Prometheus + Grafana)
- [ ] Set up backups (daily database dumps)
- [ ] Review CORS settings
- [ ] Test all endpoints

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for complete instructions.

---

## 💡 Tips & Best Practices

### Development Workflow
1. Start infrastructure: `make docker-up`
2. Run services in separate terminals
3. Use integration tests to verify changes
4. Check logs for errors
5. Use health endpoints to verify status

### Testing
```bash
# Quick health check
curl http://localhost:8080/health
curl http://localhost:8082/health
curl http://localhost:8081/health

# Full integration test
make test-integration-win
```

### Database Changes
1. Create migration: `migrate create -ext sql -dir infra/postgres/migrations -seq description`
2. Edit up/down SQL files
3. Apply: `make migrate-up`
4. Rollback if needed: `make migrate-down`

---

**Quick Start**: `make docker-up` → `make dev-auth dev-puzzle dev-matchmaker` → `make test-integration-win` ✅
