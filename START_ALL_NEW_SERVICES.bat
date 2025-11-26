@echo off
echo ===============================================
echo Starting ALL Cipher Clash V2.0 Services
echo ===============================================
echo.

set DATABASE_URL=postgres://postgres:cipherclash2025@127.0.0.1:5432/cipher_clash?sslmode=disable
set REDIS_ADDR=127.0.0.1:6379

echo Starting services in background...
echo.

REM Start each service in a new window
start "Missions Service (8090)" cmd /k "cd services\missions && set DATABASE_URL=%DATABASE_URL% && echo Starting Missions Service... && timeout /t 2 && echo Service would start here - import cycle needs fixing"

start "Mastery Service (8091)" cmd /k "cd services\mastery && set DATABASE_URL=%DATABASE_URL% && echo Starting Mastery Service... && timeout /t 2 && echo Service would start here - import cycle needs fixing"

start "Social Service (8092)" cmd /k "cd services\social && set DATABASE_URL=%DATABASE_URL% && echo Starting Social Service... && timeout /t 2 && echo Service would start here - import cycle needs fixing"

start "Cosmetics Service (8093)" cmd /k "cd services\cosmetics && set DATABASE_URL=%DATABASE_URL% && echo Starting Cosmetics Service... && timeout /t 2 && echo Service would start here - import cycle needs fixing"

echo.
echo ===============================================
echo All services are launching...
echo ===============================================
echo.
echo Service Ports:
echo   - Missions:   http://localhost:8090
echo   - Mastery:    http://localhost:8091
echo   - Social:     http://localhost:8092
echo   - Cosmetics:  http://localhost:8093
echo.
echo Note: Services have import cycle errors that need fixing
echo Press any key to exit...
pause > nul
