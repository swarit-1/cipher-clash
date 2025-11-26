# 🔧 Database Connection Fix - Complete Solution

## Current Status

✅ **PostgreSQL 18 is installed** at `C:\Program Files\PostgreSQL\18`
✅ **PostgreSQL server is NOW RUNNING** and accepting connections on 127.0.0.1:5432
✅ **.env file updated** to use 127.0.0.1 instead of localhost (fixing IPv6 issue)
❌ **Password authentication is failing** - The password in .env doesn't match PostgreSQL

---

## The Problem

When you run `cd services\auth && go run main.go`, you get:
```
FATAL: Failed to connect to database
error: password authentication failed for user "postgres"
```

**Root Cause:** The password in your `.env` file (`Ie=X2&g3ezg*80U37A42+W+N`) doesn't match the actual PostgreSQL postgres user password.

---

## Solution Options

### Option 1: Find the Correct Password (RECOMMENDED)

The PostgreSQL password was set during installation. Check these locations:

1. **Installation notes** - PostgreSQL installer might have saved it
2. **Environment variables** - Check Windows environment variables
3. **Password manager** - If you saved it during installation
4. **Installation summary** - Check `C:\Program Files\PostgreSQL\18\installation_summary.log`

Once found, update your `.env` file line 7:
```env
DATABASE_URL=postgres://postgres:YOUR_ACTUAL_PASSWORD@127.0.0.1:5432/cipher_clash?sslmode=disable
```

### Option 2: Reset PostgreSQL Password

If you can't remember the password, reset it:

#### Step 1: Edit pg_hba.conf
```bash
# Open in notepad as Administrator
notepad "C:\Program Files\PostgreSQL\18\data\pg_hba.conf"
```

Find this line:
```
host    all             all             127.0.0.1/32            scram-sha-256
```

Change to:
```
host    all             all             127.0.0.1/32            trust
```

#### Step 2: Restart PostgreSQL
```bash
"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe" restart -D "C:\Program Files\PostgreSQL\18\data"
```

#### Step 3: Set New Password
```bash
psql -h 127.0.0.1 -U postgres -c "ALTER USER postgres PASSWORD 'postgres';"
```

#### Step 4: Restore security in pg_hba.conf
Change `trust` back to `scram-sha-256` and restart PostgreSQL again.

#### Step 5: Update .env
```env
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/cipher_clash?sslmode=disable
```

### Option 3: Quick Fix Script

Run the provided script:
```bash
reset-postgres-password.bat
```

This will test common passwords and help you update the .env file.

---

## What Has Been Fixed Already

1. ✅ **IPv6 to IPv4 Issue**
   - Changed `localhost` to `127.0.0.1` in .env
   - This prevents the `dial tcp [::1]:5432: connectex` error

2. ✅ **PostgreSQL Server Not Running**
   - Started PostgreSQL server using pg_ctl
   - Server is now accepting connections
   - Verified with: `pg_isready -h 127.0.0.1 -p 5432`

3. ✅ **Created Helper Scripts**
   - `fix-database-and-start.bat` - Full database setup
   - `reset-postgres-password.bat` - Password reset helper

---

## Testing After Fix

Once you have the correct password in .env:

```bash
# 1. Test PostgreSQL connection directly
psql -h 127.0.0.1 -U postgres -c "SELECT 1;"

# 2. Create database if needed
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE cipher_clash;"

# 3. Apply migrations
psql -h 127.0.0.1 -U postgres -d cipher_clash -f infra/postgres/schema.sql
psql -h 127.0.0.1 -U postgres -d cipher_clash -f infra/postgres/migrations/001_new_features_v2.sql

# 4. Test auth service
cd services/auth
go run main.go
```

Expected output:
```json
{"level":"INFO","message":"Auth Service listening on port 8085"}
```

---

## Quick Commands Reference

### Start PostgreSQL Server
```bash
"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe" start -D "C:\Program Files\PostgreSQL\18\data"
```

### Stop PostgreSQL Server
```bash
"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe" stop -D "C:\Program Files\PostgreSQL\18\data"
```

### Check PostgreSQL Status
```bash
"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe" status -D "C:\Program Files\PostgreSQL\18\data"
pg_isready -h 127.0.0.1 -p 5432
```

### Test Connection with Password
```bash
# Windows CMD (set password first)
set PGPASSWORD=your_password
psql -h 127.0.0.1 -U postgres -c "SELECT 1;"
```

---

## Current .env Configuration

Your `.env` file (line 7) currently has:
```env
DATABASE_URL=postgres://postgres:Ie=X2&g3ezg*80U37A42+W+N@127.0.0.1:5432/cipher_clash?sslmode=disable
```

This password needs to match your PostgreSQL postgres user password.

---

## Next Steps

1. **Find or reset your PostgreSQL password**
2. **Update .env with correct password**
3. **Run the auth service**: `cd services\auth && go run main.go`
4. **If successful, start all services**: `START_ALL_SERVICES.bat`

---

## Additional Help

If you continue to have issues:

1. Check PostgreSQL logs:
   ```bash
   type "C:\Program Files\PostgreSQL\18\data\logfile"
   ```

2. Verify PostgreSQL is listening:
   ```bash
   netstat -an | findstr ":5432"
   ```

3. Test with psql directly:
   ```bash
   psql -h 127.0.0.1 -U postgres
   # Enter password when prompted
   ```

---

## Summary of Changes Made

**Files Modified:**
- ✅ `.env` - Updated DATABASE_URL to use 127.0.0.1

**Files Created:**
- ✅ `TROUBLESHOOTING.md` - Comprehensive troubleshooting guide
- ✅ `fix-database-and-start.bat` - Automated database setup script
- ✅ `reset-postgres-password.bat` - Password reset helper
- ✅ `DATABASE_CONNECTION_FIX.md` - This file

**PostgreSQL Status:**
- ✅ Server is running on port 5432
- ✅ Accepting connections on 127.0.0.1
- ❌ Password needs to be verified/updated

---

**Last Updated:** 2025-11-25
**PostgreSQL Version:** 18.0
**Status:** Server running, awaiting correct password configuration
