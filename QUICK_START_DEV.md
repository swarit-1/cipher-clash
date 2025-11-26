# 🚀 Quick Start for Development

## The Problem You're Having

**"Network error: Unable to connect to server"** happens because:
1. Backend services might not be running
2. Flutter web needs to run on a specific port
3. CORS requires proper configuration

## ✅ Solution: Run Everything Properly

### Step 1: Start Docker Infrastructure

```powershell
# Make sure Docker Desktop is running, then:
docker-compose up -d postgres redis rabbitmq
```

**Verify Docker is running:**
```powershell
docker ps
# Should show: postgres, redis, rabbitmq (all healthy)
```

### Step 2: Start All Backend Services

**Option A: Use the batch file (Easiest!)**
```powershell
.\START_EVERYTHING.bat
```

This opens 5 terminal windows automatically!

**Option B: Manual (5 separate PowerShell windows)**
```powershell
# Terminal 1
cd services\auth
go run main.go

# Terminal 2
cd services\matchmaker
go run main.go

# Terminal 3
cd services\puzzle_engine
go run main.go

# Terminal 4
cd services\game
go run main.go

# Terminal 5
cd services\tutorial
go run main.go
```

### Step 3: Start Flutter Client

**IMPORTANT:** Use `--web-port 3000` to avoid CORS issues!

```powershell
cd apps\client
flutter run -d chrome --web-port 3000
```

### Step 4: Use Dev Skip Button

1. Flutter opens at `http://localhost:3000`
2. Click **"SKIP FOR DEV"** button (bypasses backend auth)
3. You'll land on the main menu
4. All features should work!

## 🔧 If Matchmaking Still Says "Not Authenticated"

The dev skip button now sets mock auth credentials automatically! Just make sure you:
1. **Hot restart** Flutter (not just hot reload) after clicking skip
2. Verify services are running with health checks

## 🩺 Health Checks

Verify all services are running:
```powershell
curl http://localhost:8085/health  # Auth
curl http://localhost:8086/health  # Matchmaker
curl http://localhost:8087/health  # Puzzle
curl http://localhost:8088/health  # Game
curl http://localhost:8089/health  # Tutorial
```

All should return: `{"status":"healthy",...}`

## 📊 Port Summary

| Service | Port | URL |
|---------|------|-----|
| Auth | 8085 | http://localhost:8085 |
| Matchmaker | 8086 | http://localhost:8086 |
| Puzzle Engine | 8087 | http://localhost:8087 |
| Game | 8088 | http://localhost:8088 |
| Tutorial | 8089 | http://localhost:8089 |
| **Flutter Web** | **3000** | **http://localhost:3000** |
| PostgreSQL | 5432 | localhost:5432 |
| Redis | 6379 | localhost:6379 |
| RabbitMQ | 5672, 15672 | localhost:5672 |

## 🐛 Still Having Issues?

### Network Error on Login
- **Cause:** Backend services not running
- **Fix:** Run `START_EVERYTHING.bat` or start services manually

### "Not Authenticated" in Matchmaking
- **Cause:** Didn't use dev skip button properly
- **Fix:** Click "SKIP FOR DEV" → Hot restart Flutter

### CORS Errors in Browser Console
- **Cause:** Flutter not running on port 3000
- **Fix:** Use `flutter run -d chrome --web-port 3000`

### Services Won't Start
- **Cause:** Docker not running
- **Fix:** Start Docker Desktop, then `docker-compose up -d`

## 💡 Pro Tips

1. **Keep service terminals open** - You can see live logs for debugging
2. **Use Ctrl+C** in each terminal to stop services cleanly
3. **Check Docker Desktop** - Make sure containers are healthy
4. **Browser DevTools** - Check Network tab for actual error messages
5. **Hot Restart** - Always hot restart (not reload) after auth changes

## 🎯 Quick Test Flow

```powershell
# 1. Start infrastructure
docker-compose up -d

# 2. Start backend (use batch file)
.\START_EVERYTHING.bat

# 3. Start frontend
cd apps\client
flutter run -d chrome --web-port 3000

# 4. Click "SKIP FOR DEV" button
# 5. Enjoy! 🎉
```
