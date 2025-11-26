@echo off
echo ================================================================
echo   CIPHER CLASH V2.0 - STARTING ALL SERVICES
echo ================================================================
echo.

REM Check if required ports are available
echo [1/6] Checking ports...
netstat -an | findstr ":8085 :8086 :8087 :8088 :8089" >nul
if %errorlevel% equ 0 (
    echo WARNING: Some ports are already in use!
    echo Please close any running services first.
    pause
    exit /b 1
)
echo All ports are available!
echo.

REM Start PostgreSQL check
echo [2/6] Checking PostgreSQL connection...
psql -U postgres -d cipher_clash -c "SELECT 1;" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Cannot connect to PostgreSQL!
    echo Please ensure PostgreSQL is running and cipher_clash database exists.
    pause
    exit /b 1
)
echo PostgreSQL is running!
echo.

REM Start Redis check
echo [3/6] Checking Redis connection...
redis-cli ping >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Redis is not running. Some features may not work.
    echo Continuing anyway...
)
echo.

echo [4/6] Building services...
cd services\puzzle_engine
go build -o ..\..\bin\puzzle_engine.exe
cd ..\auth
go build -o ..\..\bin\auth_service.exe
cd ..\matchmaker
go build -o ..\..\bin\matchmaker.exe
cd ..\achievement
go build -o ..\..\bin\achievement.exe
cd ..\game
go build -o ..\..\bin\game_service.exe
cd ..\tutorial
go build -o ..\..\bin\tutorial.exe 2>nul
cd ..\..
echo Services built successfully!
echo.

echo [5/6] Starting services...
echo.
echo Starting Auth Service (Port 8085)...
start "Auth Service" cmd /c "bin\auth_service.exe"
timeout /t 2 >nul

echo Starting Matchmaker Service (Port 8086)...
start "Matchmaker Service" cmd /c "bin\matchmaker.exe"
timeout /t 2 >nul

echo Starting Puzzle Engine (Port 8087)...
start "Puzzle Engine" cmd /c "bin\puzzle_engine.exe"
timeout /t 2 >nul

echo Starting Game Service (Port 8088)...
start "Game Service" cmd /c "bin\game_service.exe"
timeout /t 2 >nul

echo Starting Tutorial Service (Port 8089)...
start "Tutorial Service" cmd /c "bin\tutorial.exe"
timeout /t 2 >nul

echo Starting Achievement Service (Port 8083)...
start "Achievement Service" cmd /c "bin\achievement.exe"
timeout /t 2 >nul

echo.
echo [6/6] All services started!
echo.
echo ================================================================
echo   CIPHER CLASH V2.0 - SERVICES RUNNING
echo ================================================================
echo.
echo   Auth Service:        http://localhost:8085/health
echo   Matchmaker:          http://localhost:8086/health
echo   Puzzle Engine:       http://localhost:8087/health
echo   Game Service:        http://localhost:8088/health
echo   Tutorial Service:    http://localhost:8089/health
echo   Achievement Service: http://localhost:8083/health
echo.
echo ================================================================
echo.
echo Press any key to open health check dashboard in browser...
pause >nul

REM Open health checks in browser
start http://localhost:8085/health
start http://localhost:8087/health
start http://localhost:8089/health

echo.
echo All services are now running!
echo Close this window to stop monitoring.
echo To stop services, close their individual terminal windows.
echo.
pause
