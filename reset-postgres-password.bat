@echo off
echo ==========================================
echo PostgreSQL Password Reset Script
echo ==========================================
echo.
echo This script will help you reset the postgres user password.
echo.
echo Current password in .env: Ie=X2^&g3ezg*80U37A42+W+N
echo.
echo OPTION 1: Try connecting with common passwords
echo.

set PGPASSWORD=postgres
psql -h 127.0.0.1 -U postgres -c "SELECT 1;" >nul 2>&1
if %errorlevel% equ 0 (
    echo SUCCESS! Default password 'postgres' works!
    echo.
    echo Updating .env file...
    goto :update_env
)

set PGPASSWORD=
psql -h 127.0.0.1 -U postgres -c "SELECT 1;" >nul 2>&1
if %errorlevel% equ 0 (
    echo SUCCESS! Empty password works!
    echo.
    echo WARNING: Empty password detected - this is insecure!
    echo You should set a password for production use.
    set NEW_PASSWORD=postgres
    goto :update_env
)

echo.
echo OPTION 2: Reset password using trust authentication
echo.
echo To reset the password, you need to:
echo   1. Edit pg_hba.conf (C:\Program Files\PostgreSQL\18\data\pg_hba.conf)
echo   2. Change 'md5' to 'trust' for local connections
echo   3. Restart PostgreSQL
echo   4. Run: psql -U postgres -c "ALTER USER postgres PASSWORD 'newpassword';"
echo   5. Change 'trust' back to 'md5' in pg_hba.conf
echo   6. Restart PostgreSQL again
echo.
echo Manual command to set password:
echo   "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U postgres -c "ALTER USER postgres PASSWORD 'postgres';"
echo.
echo After setting the password, update your .env file:
echo   DATABASE_URL=postgres://postgres:YOURPASSWORD@127.0.0.1:5432/cipher_clash?sslmode=disable
echo.
pause
exit /b 1

:update_env
echo Backing up .env to .env.backup...
copy .env .env.backup >nul

echo Updating DATABASE_URL in .env...
powershell -Command "(Get-Content .env) -replace 'DATABASE_URL=postgres://postgres:.*@', 'DATABASE_URL=postgres://postgres:%NEW_PASSWORD%@' | Set-Content .env"

echo.
echo Done! Your .env has been updated.
echo.
echo Test the connection:
echo   cd services\auth
echo   go run main.go
echo.
pause
