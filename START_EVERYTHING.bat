@echo off
echo ========================================
echo  CIPHER CLASH - Starting All Services
echo ========================================
echo.

echo [1/4] Checking Docker services...
docker ps
echo.

echo [2/4] Starting backend services in new windows...
echo.

echo Starting Auth Service (Port 8085)...
start "Auth Service" cmd /k "cd services\auth && go run main.go"
timeout /t 2 /nobreak >nul

echo Starting Matchmaker Service (Port 8086)...
start "Matchmaker Service" cmd /k "cd services\matchmaker && go run main.go"
timeout /t 2 /nobreak >nul

echo Starting Puzzle Engine (Port 8087)...
start "Puzzle Engine" cmd /k "cd services\puzzle_engine && go run main.go"
timeout /t 2 /nobreak >nul

echo Starting Game Service (Port 8088)...
start "Game Service" cmd /k "cd services\game && go run main.go"
timeout /t 2 /nobreak >nul

echo Starting Tutorial Service (Port 8089)...
start "Tutorial Service" cmd /k "cd services\tutorial && go run main.go"
timeout /t 2 /nobreak >nul

echo.
echo [3/4] Waiting for services to initialize...
timeout /t 5 /nobreak >nul

echo.
echo [4/4] Testing service health...
curl -s http://localhost:8085/health
curl -s http://localhost:8086/health
curl -s http://localhost:8087/health
curl -s http://localhost:8088/health
curl -s http://localhost:8089/health

echo.
echo ========================================
echo  All services started!
echo ========================================
echo.
echo Backend Services:
echo   - Auth:       http://localhost:8085
echo   - Matchmaker: http://localhost:8086
echo   - Puzzle:     http://localhost:8087
echo   - Game:       http://localhost:8088
echo   - Tutorial:   http://localhost:8089
echo.
echo Next step: Start Flutter client
echo   cd apps\client
echo   flutter run -d chrome --web-port 3000
echo.
echo Press any key to exit...
pause >nul
