@echo off
echo ==========================================
echo Cipher Clash V2.0 - Database Setup Script
echo ==========================================
echo.

echo [1/8] Checking PostgreSQL installation...
psql --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PostgreSQL not found in PATH!
    echo.
    echo Please install PostgreSQL 15+ from:
    echo https://www.postgresql.org/download/windows/
    echo.
    echo Or add PostgreSQL to your PATH:
    echo   C:\Program Files\PostgreSQL\18\bin
    pause
    exit /b 1
)
psql --version
echo PostgreSQL found!
echo.

echo [2/8] Looking for PostgreSQL service...
echo Trying common PostgreSQL 18 service names...
sc query postgresql-x64-18 >nul 2>&1
if %errorlevel% equ 0 (
    set PG_SERVICE=postgresql-x64-18
    goto :service_found
)
sc query postgresql-x64-17 >nul 2>&1
if %errorlevel% equ 0 (
    set PG_SERVICE=postgresql-x64-17
    goto :service_found
)
sc query postgresql-x64-16 >nul 2>&1
if %errorlevel% equ 0 (
    set PG_SERVICE=postgresql-x64-16
    goto :service_found
)
sc query postgresql-x64-15 >nul 2>&1
if %errorlevel% equ 0 (
    set PG_SERVICE=postgresql-x64-15
    goto :service_found
)

echo WARNING: No PostgreSQL Windows service found!
echo PostgreSQL might need to be started manually.
echo.
echo Try these commands:
echo   pg_ctl -D "C:\Program Files\PostgreSQL\18\data" start
echo   OR
echo   net start postgresql-x64-18
echo.
set PG_SERVICE=none
goto :skip_service_start

:service_found
echo Found PostgreSQL service: %PG_SERVICE%
echo.

echo [3/8] Starting PostgreSQL service...
sc query %PG_SERVICE% | findstr "RUNNING" >nul
if %errorlevel% equ 0 (
    echo PostgreSQL is already running!
) else (
    echo Starting PostgreSQL service...
    net start %PG_SERVICE% 2>nul
    if %errorlevel% equ 0 (
        echo PostgreSQL started successfully!
    ) else (
        echo Note: Service may already be running or requires admin privileges
    )
)
echo.

:skip_service_start
echo [4/8] Testing PostgreSQL connection...
timeout /t 2 /nobreak >nul
pg_isready -h 127.0.0.1 -p 5432
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Cannot connect to PostgreSQL on 127.0.0.1:5432!
    echo.
    echo Possible causes:
    echo   1. PostgreSQL service is not running
    echo   2. PostgreSQL is not configured to accept connections on port 5432
    echo   3. Firewall is blocking port 5432
    echo.
    echo Try manually starting PostgreSQL:
    echo   pg_ctl -D "C:\Program Files\PostgreSQL\18\data" start
    echo.
    pause
    exit /b 1
)
echo PostgreSQL is accepting connections!
echo.

echo [5/8] Verifying database password...
set PGPASSWORD=Ie=X2^&g3ezg*80U37A42+W+N
psql -h 127.0.0.1 -U postgres -c "SELECT 1;" >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Cannot authenticate with PostgreSQL!
    echo.
    echo The password in .env might be incorrect.
    echo Please verify your PostgreSQL password and update .env file.
    echo.
    echo Current .env password: Ie=X2^&g3ezg*80U37A42+W+N
    echo.
    echo To reset password, run as postgres user:
    echo   ALTER USER postgres PASSWORD 'your-new-password';
    echo.
    pause
    exit /b 1
)
echo Authentication successful!
echo.

echo [6/8] Checking if database exists...
psql -h 127.0.0.1 -U postgres -lqt 2>nul | findstr "cipher_clash" >nul
if %errorlevel% neq 0 (
    echo Database 'cipher_clash' not found. Creating...
    psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE cipher_clash;" >nul 2>&1
    if %errorlevel% equ 0 (
        echo Database created successfully!
    ) else (
        echo Note: Database might already exist or creation requires different permissions
    )
) else (
    echo Database 'cipher_clash' already exists!
)
echo.

echo [7/8] Applying database migrations...
echo.
echo Checking for schema file...
if exist "infra\postgres\schema.sql" (
    echo Applying base schema...
    psql -h 127.0.0.1 -U postgres -d cipher_clash -f "infra\postgres\schema.sql" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] Base schema applied
    ) else (
        echo   [SKIP] Schema already applied or error occurred
    )
)

if exist "infra\postgres\migrations\001_new_features_v2.sql" (
    echo Applying V2.0 migrations...
    psql -h 127.0.0.1 -U postgres -d cipher_clash -f "infra\postgres\migrations\001_new_features_v2.sql" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] V2.0 features migration applied
    ) else (
        echo   [SKIP] Migration already applied or error occurred
    )
)
echo.

echo [8/8] Verifying .env configuration...
findstr "127.0.0.1" .env >nul
if %errorlevel% neq 0 (
    echo WARNING: .env still uses 'localhost' instead of '127.0.0.1'
    echo This might cause IPv6 connection issues!
) else (
    echo .env is correctly configured with 127.0.0.1
)
echo.

echo ==========================================
echo Setup Complete!
echo ==========================================
echo.
echo Your database is ready. Connection string:
echo DATABASE_URL=postgres://postgres:****@127.0.0.1:5432/cipher_clash?sslmode=disable
echo.
echo You can now start the services:
echo   cd services\auth
echo   go run main.go
echo.
echo Or start all services at once:
echo   START_ALL_SERVICES.bat
echo.
pause
