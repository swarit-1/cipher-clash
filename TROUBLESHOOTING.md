# 🔧 Cipher Clash - Troubleshooting Guide

## Common Issues and Solutions

---

## 🔴 CURRENT ISSUE: Password Authentication Failed

### Error Message:
```
FATAL: Failed to connect to database
error: password authentication failed for user "postgres"
```

### Status:
✅ PostgreSQL 18 is installed and **RUNNING**
✅ Server is accepting connections on 127.0.0.1:5432
✅ .env file updated to use 127.0.0.1 (IPv6 issue fixed)
❌ **Password in .env doesn't match PostgreSQL**

### Quick Fix:

**The password in your .env file needs to match your PostgreSQL postgres user password.**

See **[DATABASE_CONNECTION_FIX.md](DATABASE_CONNECTION_FIX.md)** for complete instructions on:
- Finding your PostgreSQL password
- Resetting the password if forgotten
- Updating the .env file correctly

**Commands to start PostgreSQL (if needed):**
```cmd
# PostgreSQL 18
"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe" start -D "C:\Program Files\PostgreSQL\18\data"

# Check status
pg_isready -h 127.0.0.1 -p 5432
```

---

## 🔴 Database Connection Error (Server Not Running)

### Error Message:
```
Failed to connect to database
dial tcp [::1]:5432: connectex: No connection could be made because the target machine actively refused it.
```

### Root Causes:
1. PostgreSQL service is not running
2. PostgreSQL is configured for IPv4 but Go is trying IPv6
3. Wrong connection string
4. PostgreSQL not installed

---

## ✅ SOLUTION 1: Start PostgreSQL Service

### On Windows:

**Method A: Services Manager**
```powershell
# Open Services (Win + R, type services.msc)
# Find "postgresql-x64-15" (or your version)
# Right-click → Start

# Or via PowerShell (as Administrator):
Start-Service postgresql-x64-15
```

**Method B: Command Line**
```cmd
# Check if PostgreSQL is installed
psql --version

# Find PostgreSQL installation
dir "C:\Program Files\PostgreSQL"

# Start service (replace version number)
net start postgresql-x64-15
```

**Method C: Using pg_ctl**
```cmd
# Navigate to PostgreSQL bin directory
cd "C:\Program Files\PostgreSQL\15\bin"

# Start PostgreSQL
pg_ctl start -D "C:\Program Files\PostgreSQL\15\data"
```

### On macOS:
```bash
# Using Homebrew
brew services start postgresql@15

# Or manually
pg_ctl -D /usr/local/var/postgres start
```

### On Linux:
```bash
# Ubuntu/Debian
sudo systemctl start postgresql
sudo systemctl enable postgresql  # Auto-start on boot

# Check status
sudo systemctl status postgresql
```

---

## ✅ SOLUTION 2: Fix Connection String

### Update `.env` file:

```env
# Option 1: Force IPv4 (Recommended)
DATABASE_URL=postgres://postgres:yourpassword@127.0.0.1:5432/cipher_clash?sslmode=disable

# Option 2: Use localhost (may use IPv6)
DATABASE_URL=postgres://postgres:yourpassword@localhost:5432/cipher_clash?sslmode=disable

# Option 3: Full connection string with all parameters
DATABASE_URL=postgresql://postgres:yourpassword@127.0.0.1:5432/cipher_clash?sslmode=disable&connect_timeout=10
```

**Important Notes:**
- Replace `yourpassword` with your actual PostgreSQL password
- Use `127.0.0.1` instead of `localhost` to force IPv4
- Add `sslmode=disable` for local development
- Default password is often `postgres` or empty

### Test Connection:
```bash
# Test with psql
psql -h 127.0.0.1 -U postgres -d cipher_clash

# If this works, your connection string should work
```

---

## ✅ SOLUTION 3: Create Database

If database doesn't exist:

```bash
# Connect to PostgreSQL
psql -h 127.0.0.1 -U postgres

# Create database
CREATE DATABASE cipher_clash;

# Grant permissions
GRANT ALL PRIVILEGES ON DATABASE cipher_clash TO postgres;

# Exit
\q

# Run migrations
psql -h 127.0.0.1 -U postgres -d cipher_clash < infra/postgres/schema.sql
psql -h 127.0.0.1 -U postgres -d cipher_clash < infra/postgres/migrations/001_new_features_v2.sql
```

---

## ✅ SOLUTION 4: Update Go Database Connection Code

Create a helper function to handle connection retries:

**File:** `pkg/db/db.go`

Add retry logic:

```go
func NewDatabase(connectionString string) (*Database, error) {
    // Parse connection string to force IPv4
    connectionString = strings.Replace(connectionString, "localhost", "127.0.0.1", 1)

    var db *sql.DB
    var err error

    // Retry connection up to 5 times
    for i := 0; i < 5; i++ {
        db, err = sql.Open("postgres", connectionString)
        if err != nil {
            time.Sleep(time.Second * 2)
            continue
        }

        // Test connection
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        err = db.PingContext(ctx)
        cancel()

        if err == nil {
            break // Success!
        }

        log.Printf("Database connection attempt %d failed: %v", i+1, err)
        time.Sleep(time.Second * 2)
    }

    if err != nil {
        return nil, fmt.Errorf("failed to connect after retries: %w", err)
    }

    // ... rest of the code
}
```

---

## ✅ SOLUTION 5: Quick Fix Script

Create this file: `fix-database-connection.bat`

```batch
@echo off
echo Fixing Database Connection...
echo.

echo [1/5] Checking PostgreSQL installation...
psql --version
if %errorlevel% neq 0 (
    echo ERROR: PostgreSQL not found!
    echo Please install PostgreSQL from https://www.postgresql.org/download/
    pause
    exit /b 1
)

echo [2/5] Starting PostgreSQL service...
net start postgresql-x64-15 2>nul
if %errorlevel% equ 0 (
    echo PostgreSQL started successfully!
) else (
    echo PostgreSQL may already be running or service name differs
)

echo.
echo [3/5] Testing connection...
psql -h 127.0.0.1 -U postgres -c "SELECT 1;" 2>nul
if %errorlevel% neq 0 (
    echo.
    echo Cannot connect! Please verify:
    echo 1. PostgreSQL is running
    echo 2. Password is correct
    echo 3. Port 5432 is not blocked
    echo.
    echo Try: psql -h 127.0.0.1 -U postgres
    pause
    exit /b 1
)

echo Connection successful!
echo.

echo [4/5] Checking if database exists...
psql -h 127.0.0.1 -U postgres -lqt | findstr cipher_clash >nul
if %errorlevel% neq 0 (
    echo Creating database...
    psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE cipher_clash;"
    echo Database created!
) else (
    echo Database already exists!
)

echo.
echo [5/5] Updating .env file...
echo DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/cipher_clash?sslmode=disable > .env.temp
echo.
echo Done! Your connection string:
type .env.temp
echo.
echo Copy this to your .env file if needed.
echo.
pause
```

Run: `fix-database-connection.bat`

---

## 🔍 Diagnostic Commands

### Check PostgreSQL Status:
```bash
# Windows
sc query postgresql-x64-15

# macOS/Linux
systemctl status postgresql

# Any OS - Check if port is listening
netstat -an | findstr :5432
```

### Check PostgreSQL Logs:
```bash
# Windows
type "C:\Program Files\PostgreSQL\15\data\log\postgresql-*.log"

# macOS
tail -f /usr/local/var/log/postgresql.log

# Linux
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

### Test Connection Manually:
```bash
# Method 1: psql
psql -h 127.0.0.1 -U postgres -d cipher_clash

# Method 2: pg_isready
pg_isready -h 127.0.0.1 -p 5432

# Method 3: telnet
telnet 127.0.0.1 5432
```

---

## 🔧 Other Common Issues

### Issue: "role 'postgres' does not exist"

**Solution:**
```bash
# Create postgres user
createuser -s postgres

# Or via SQL
psql -h 127.0.0.1 -U youruser -c "CREATE USER postgres WITH SUPERUSER PASSWORD 'postgres';"
```

### Issue: "password authentication failed"

**Solution 1:** Update `pg_hba.conf`
```bash
# Find file (usually in PostgreSQL data directory)
# C:\Program Files\PostgreSQL\15\data\pg_hba.conf

# Add this line at the top of the file:
host    all             all             127.0.0.1/32            md5

# Restart PostgreSQL
net stop postgresql-x64-15
net start postgresql-x64-15
```

**Solution 2:** Reset password
```bash
# As postgres user
psql -h 127.0.0.1 -U postgres
ALTER USER postgres PASSWORD 'newpassword';
\q
```

### Issue: "too many clients"

**Solution:**
```sql
-- Connect and check current connections
SELECT count(*) FROM pg_stat_activity;

-- Increase max connections in postgresql.conf
max_connections = 200

-- Restart PostgreSQL
```

### Issue: Port 5432 already in use

**Solution:**
```bash
# Find what's using the port
netstat -ano | findstr :5432

# Kill the process (replace PID)
taskkill /PID <process_id> /F

# Or change PostgreSQL port in postgresql.conf
port = 5433
```

---

## ✅ Recommended .env Configuration

Create/update your `.env` file:

```env
# Database Configuration
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/cipher_clash?sslmode=disable
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=cipher_clash
DB_MAX_OPEN_CONNS=100
DB_MAX_IDLE_CONNS=10

# Redis Configuration (optional)
REDIS_ADDR=127.0.0.1:6379
REDIS_PASSWORD=
REDIS_DB=0

# RabbitMQ Configuration (optional)
RABBITMQ_URL=amqp://guest:guest@127.0.0.1:5672/

# JWT Configuration
JWT_SECRET=change-this-to-a-secure-random-string-in-production
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=168h

# Service Ports
AUTH_SERVICE_PORT=8085
MATCHMAKER_PORT=8086
PUZZLE_ENGINE_PORT=8087
GAME_SERVICE_PORT=8088
ACHIEVEMENT_SERVICE_PORT=8083
TUTORIAL_SERVICE_PORT=8089
MISSIONS_SERVICE_PORT=8090
MASTERY_SERVICE_PORT=8091
SOCIAL_SERVICE_PORT=8092
COSMETICS_SERVICE_PORT=8093

# Logging
LOG_LEVEL=INFO

# CORS
ENABLE_CORS=true
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# Features
ENABLE_TUTORIAL=true
ENABLE_BOSS_BATTLES=true
ENABLE_SPECTATOR_MODE=true
ENABLE_COSMETICS=true
```

---

## 🚀 Quick Start After Fix

Once PostgreSQL is running:

```bash
# 1. Test connection
psql -h 127.0.0.1 -U postgres -d cipher_clash

# 2. If database doesn't exist, create it
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE cipher_clash;"

# 3. Run migrations
psql -h 127.0.0.1 -U postgres -d cipher_clash < infra/postgres/schema.sql
psql -h 127.0.0.1 -U postgres -d cipher_clash < infra/postgres/migrations/001_new_features_v2.sql

# 4. Start services
cd services/auth
go run main.go

# Should see:
# {"level":"INFO","message":"Auth Service listening on port 8085"}
```

---

## 📞 Still Having Issues?

### Checklist:
- [ ] PostgreSQL service is running
- [ ] Database `cipher_clash` exists
- [ ] Can connect with `psql -h 127.0.0.1 -U postgres`
- [ ] `.env` file has correct `DATABASE_URL`
- [ ] Using `127.0.0.1` instead of `localhost`
- [ ] Port 5432 is not blocked by firewall
- [ ] PostgreSQL is listening on correct port
- [ ] Password is correct

### Get Help:
1. Check PostgreSQL logs
2. Run `fix-database-connection.bat`
3. Test connection with psql
4. Verify `.env` configuration
5. Check service status

---

**Most Common Fix: Just start PostgreSQL service!**

```bash
# Windows
net start postgresql-x64-15

# macOS
brew services start postgresql

# Linux
sudo systemctl start postgresql
```

---

Last updated: January 2025
