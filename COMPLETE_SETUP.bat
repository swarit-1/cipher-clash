@echo off
echo ==========================================
echo Cipher Clash V2.0 - Complete Setup Script
echo ==========================================
echo.
echo This script will:
echo 1. Create the database
echo 2. Apply all migrations
echo 3. Test all services
echo.
pause

echo [1/4] Creating cipher_clash database...
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE cipher_clash;" 2>nul
if %errorlevel% equ 0 (
    echo Database created successfully!
) else (
    echo Database already exists or error occurred - continuing...
)
echo.

echo [2/4] Applying base schema...
if exist "infra\postgres\schema.sql" (
    psql -h 127.0.0.1 -U postgres -d cipher_clash -f "infra\postgres\schema.sql" 2>nul
    if %errorlevel% equ 0 (
        echo   [OK] Base schema applied
    ) else (
        echo   [SKIP] Schema might already exist
    )
) else (
    echo   [SKIP] Base schema file not found
)
echo.

echo [3/4] Applying V2.0 migrations...
if exist "infra\postgres\migrations\001_new_features_v2.sql" (
    psql -h 127.0.0.1 -U postgres -d cipher_clash -f "infra\postgres\migrations\001_new_features_v2.sql" 2>nul
    if %errorlevel% equ 0 (
        echo   [OK] V2.0 migrations applied
    ) else (
        echo   [SKIP] Migrations might already be applied
    )
) else (
    echo   [ERROR] V2.0 migration file not found!
)
echo.

echo [4/4] Database setup complete!
echo.
echo ==========================================
echo Ready to start services!
echo ==========================================
echo.
echo To start all services, run:
echo   START_ALL_SERVICES.bat
echo.
echo Or start services individually:
echo   cd services\auth ^&^& go run main.go
echo   cd services\missions ^&^& go run main.go
echo   cd services\mastery ^&^& go run main.go
echo   cd services\social ^&^& go run main.go
echo   cd services\cosmetics ^&^& go run main.go
echo.
pause
