# 🧪 Cipher Clash V2.0 - Complete API Testing Guide

**Quick reference for testing all 50+ endpoints**

---

## 🚀 Quick Setup

```bash
# Start all services
START_ALL_SERVICES.bat

# Or manually start what you need
cd services/puzzle_engine && go run main.go  # Port 8087
cd services/auth && go run main.go           # Port 8085
cd services/tutorial && go run main.go       # Port 8089
```

---

## 📡 Service Endpoints

| Service | Port | Health Check |
|---------|------|--------------|
| Auth | 8085 | http://localhost:8085/health |
| Matchmaker | 8086 | http://localhost:8086/health |
| Puzzle Engine | 8087 | http://localhost:8087/health |
| Game | 8088 | http://localhost:8088/health |
| Tutorial | 8089 | http://localhost:8089/health |
| Achievement | 8083 | http://localhost:8083/health |

---

## 🔐 1. Authentication Service (Port 8085)

### Register User
```bash
curl -X POST http://localhost:8085/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "SecurePassword123!"
  }'
```

**Expected Response:**
```json
{
  "user": {
    "id": "uuid",
    "username": "testuser",
    "email": "test@example.com"
  },
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc..."
}
```

### Login
```bash
curl -X POST http://localhost:8085/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePassword123!"
  }'
```

### Get Profile (Authenticated)
```bash
curl http://localhost:8085/api/v1/auth/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Refresh Token
```bash
curl -X POST http://localhost:8085/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "YOUR_REFRESH_TOKEN"
  }'
```

---

## 🧩 2. Puzzle Engine (Port 8087)

### Test NEW Affine Cipher ✨
```bash
curl -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{
    "cipher_type": "AFFINE",
    "difficulty": 5,
    "player_elo": 1500
  }'
```

**Expected Response:**
```json
{
  "puzzle": {
    "id": "uuid",
    "cipher_type": "AFFINE",
    "difficulty": 5,
    "encrypted_text": "RCLLA",
    "config": "{\"a\":5,\"b\":8}",
    "estimated_solve_time_ms": 45000
  }
}
```

### Test NEW Autokey Cipher ✨
```bash
curl -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{
    "cipher_type": "AUTOKEY",
    "difficulty": 6
  }'
```

### Test NEW Enigma-lite Cipher ✨
```bash
curl -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{
    "cipher_type": "ENIGMA_LITE",
    "difficulty": 7
  }'
```

### Test All 18 Cipher Types
```bash
for cipher in CAESAR VIGENERE RAIL_FENCE PLAYFAIR SUBSTITUTION TRANSPOSITION XOR BASE64 MORSE BINARY HEXADECIMAL ROT13 ATBASH BOOK_CIPHER RSA_SIMPLE AFFINE AUTOKEY ENIGMA_LITE
do
  echo "Testing $cipher..."
  curl -X POST http://localhost:8087/api/v1/puzzle/generate \
    -H "Content-Type: application/json" \
    -d "{\"cipher_type\": \"$cipher\", \"difficulty\": 5}" \
    -s | jq '.puzzle.cipher_type'
done
```

### Validate Solution
```bash
curl -X POST http://localhost:8087/api/v1/puzzle/validate \
  -H "Content-Type: application/json" \
  -d '{
    "puzzle_id": "your-puzzle-id",
    "submitted_solution": "HELLO",
    "solve_time_ms": 12500
  }'
```

---

## 🎯 3. Matchmaker (Port 8086)

### Join Queue
```bash
curl -X POST http://localhost:8086/api/v1/matchmaker/join \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "user_id": "your-user-id",
    "game_mode": "ranked"
  }'
```

### Get Queue Status
```bash
curl http://localhost:8086/api/v1/matchmaker/status \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Get Leaderboard
```bash
curl http://localhost:8086/api/v1/matchmaker/leaderboard?limit=100
```

---

## 🎓 4. Tutorial Service (Port 8089) ✨ NEW

### Get All Tutorial Steps
```bash
curl http://localhost:8089/api/v1/tutorial/steps
```

**Expected Response:**
```json
{
  "steps": [
    {
      "id": "tutorial_welcome",
      "title": "Welcome to Cipher Clash",
      "category": "intro",
      "xp_reward": 25
    },
    {
      "id": "tutorial_caesar_intro",
      "title": "Caesar Cipher Basics",
      "category": "cipher_basics",
      "cipher_type": "CAESAR",
      "xp_reward": 50
    }
  ]
}
```

### Get User Progress
```bash
curl "http://localhost:8089/api/v1/tutorial/progress?user_id=YOUR_USER_ID" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Complete a Step
```bash
curl -X POST http://localhost:8089/api/v1/tutorial/complete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "user_id": "YOUR_USER_ID",
    "step_id": "tutorial_caesar_intro",
    "attempts": 2,
    "hints_used": 1,
    "time_taken_ms": 45000
  }'
```

### Get Cipher Visualization
```bash
curl -X POST http://localhost:8089/api/v1/tutorial/visualize/CAESAR \
  -H "Content-Type: application/json" \
  -d '{
    "input_text": "HELLO",
    "key": "3"
  }'
```

**Expected Response:**
```json
{
  "steps": [
    {
      "step_number": 1,
      "description": "Shifting letter H by 3 positions",
      "intermediate_value": "K",
      "metadata": {
        "input": "H",
        "shift": "3",
        "output": "K"
      }
    }
  ],
  "final_output": "KHOOR"
}
```

---

## 🎮 5. Game Service (Port 8088)

### Start Game (WebSocket)
```javascript
const ws = new WebSocket('ws://localhost:8088/ws');

ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'START_MATCH',
    user_id: 'your-user-id',
    match_id: 'match-id'
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Game update:', data);
};
```

### Submit Solution
```javascript
ws.send(JSON.stringify({
  type: 'SUBMIT_SOLUTION',
  match_id: 'match-id',
  puzzle_id: 'puzzle-id',
  solution: 'HELLO',
  time_taken_ms: 12500
}));
```

---

## 🏆 6. Achievement Service (Port 8083)

### Get All Achievements
```bash
curl http://localhost:8083/api/v1/achievements
```

### Get User Achievements
```bash
curl http://localhost:8083/api/v1/user/achievements \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Unlock Achievement
```bash
curl -X POST http://localhost:8083/api/v1/achievements/unlock \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "achievement_id": "first_win",
    "user_id": "YOUR_USER_ID"
  }'
```

---

## 📝 Testing Checklist

### Core Services
- [ ] Auth: Register, login, refresh token
- [ ] Puzzle Engine: Generate all 18 ciphers
- [ ] Matchmaker: Join queue, get leaderboard
- [ ] Game: WebSocket connection, submit solution
- [ ] Achievement: Get achievements, unlock

### NEW V2.0 Services
- [ ] Tutorial: Get steps, track progress
- [ ] Tutorial: Visualize Caesar cipher
- [ ] Tutorial: Complete step with XP reward

### NEW Ciphers
- [ ] Affine: Generate puzzle
- [ ] Autokey: Generate puzzle
- [ ] Enigma-lite: Generate puzzle
- [ ] All ciphers: Validate solutions

---

## 🐛 Common Issues & Solutions

### "Connection refused"
```bash
# Check if service is running
netstat -an | findstr "8087"

# Start the service
cd services/puzzle_engine && go run main.go
```

### "Unauthorized"
```bash
# Get a fresh token
curl -X POST http://localhost:8085/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password"}'
```

### "Database connection failed"
```bash
# Check PostgreSQL is running
psql -U postgres -c "SELECT 1;"

# Verify database exists
psql -U postgres -l | grep cipher_clash
```

---

## 📊 Load Testing

### Using Apache Bench
```bash
# Test puzzle generation (100 requests, 10 concurrent)
ab -n 100 -c 10 -p puzzle.json -T application/json \
  http://localhost:8087/api/v1/puzzle/generate
```

**puzzle.json:**
```json
{"cipher_type": "CAESAR", "difficulty": 5}
```

### Using k6
```javascript
// load-test.js
import http from 'k6/http';

export default function () {
  const payload = JSON.stringify({
    cipher_type: 'AFFINE',
    difficulty: 5
  });

  http.post('http://localhost:8087/api/v1/puzzle/generate', payload, {
    headers: { 'Content-Type': 'application/json' },
  });
}

export const options = {
  vus: 10,
  duration: '30s',
};
```

Run: `k6 run load-test.js`

---

## 📈 Performance Benchmarks

### Target Response Times

| Endpoint | Target | Acceptable |
|----------|--------|------------|
| Health Check | <10ms | <50ms |
| Puzzle Generate | <50ms | <100ms |
| Auth Login | <100ms | <200ms |
| Validate Solution | <30ms | <75ms |
| Get Leaderboard | <100ms | <300ms |

### Test Results

```bash
# Measure puzzle generation time
time curl -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{"cipher_type": "ENIGMA_LITE", "difficulty": 10}' \
  -s -o /dev/null

# Should be < 100ms
```

---

## 🔍 Debugging Tools

### View Logs
```bash
# Windows PowerShell
Get-Content -Wait .\logs\puzzle-engine.log -Tail 50

# Or start service with verbose logging
set LOG_LEVEL=DEBUG && go run main.go
```

### Database Inspection
```sql
-- Check tutorial progress
SELECT * FROM tutorial_progress WHERE user_id = 'your-id';

-- Check puzzle generation stats
SELECT cipher_type, COUNT(*) as generated
FROM puzzles
GROUP BY cipher_type
ORDER BY generated DESC;

-- Check recent user activity
SELECT * FROM user_activity
WHERE user_id = 'your-id'
ORDER BY activity_date DESC
LIMIT 7;
```

### Redis Cache Inspection
```bash
redis-cli
> KEYS *
> GET user:profile:user-id
> TTL user:profile:user-id
```

---

## ✅ Automated Test Script

```bash
#!/bin/bash
# test-all-endpoints.sh

echo "🧪 Testing Cipher Clash V2.0 APIs..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test health checks
echo "\n📊 Testing Health Checks..."
for port in 8085 8087 8086 8088 8083 8089
do
  response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health)
  if [ $response -eq 200 ]; then
    echo -e "${GREEN}✓${NC} Port $port is healthy"
  else
    echo -e "${RED}✗${NC} Port $port failed (HTTP $response)"
  fi
done

# Test new ciphers
echo "\n🔐 Testing NEW Ciphers..."
for cipher in AFFINE AUTOKEY ENIGMA_LITE
do
  response=$(curl -s -X POST http://localhost:8087/api/v1/puzzle/generate \
    -H "Content-Type: application/json" \
    -d "{\"cipher_type\": \"$cipher\", \"difficulty\": 5}")

  if echo $response | grep -q "puzzle"; then
    echo -e "${GREEN}✓${NC} $cipher cipher works"
  else
    echo -e "${RED}✗${NC} $cipher cipher failed"
  fi
done

echo "\n✅ Test suite complete!"
```

Make executable: `chmod +x test-all-endpoints.sh`
Run: `./test-all-endpoints.sh`

---

## 🎯 Quick Test Commands

```bash
# Test everything at once
curl http://localhost:8085/health && \
curl http://localhost:8087/health && \
curl http://localhost:8089/health && \
echo "All services running!"

# Generate one of each new cipher
curl -s -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{"cipher_type": "AFFINE", "difficulty": 5}' | jq '.puzzle.encrypted_text'

curl -s -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{"cipher_type": "AUTOKEY", "difficulty": 5}' | jq '.puzzle.encrypted_text'

curl -s -X POST http://localhost:8087/api/v1/puzzle/generate \
  -H "Content-Type: application/json" \
  -d '{"cipher_type": "ENIGMA_LITE", "difficulty": 5}' | jq '.puzzle.encrypted_text'
```

---

**Happy Testing! 🚀**

*For issues, check the logs in each service directory or the main error log.*
