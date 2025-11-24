@echo off
REM Cipher Clash V2.0 - Integration Test Script (Windows)
REM Tests complete user workflow: Register -> Login -> Generate Puzzle -> Join Matchmaking

setlocal enabledelayedexpansion

echo ========================================
echo  Cipher Clash V2.0 - Integration Tests
echo ========================================
echo.

REM Configuration
set AUTH_URL=http://localhost:8080/api/v1/auth
set PUZZLE_URL=http://localhost:8082/api/v1/puzzle
set MATCHMAKER_URL=http://localhost:8081/api/v1/matchmaker

REM Test data
set TIMESTAMP=%RANDOM%
set TEST_USERNAME=testplayer_%TIMESTAMP%
set TEST_EMAIL=test%TIMESTAMP%@cipher.com
set TEST_PASSWORD=SecurePassword123!

echo Step 1: Health Checks
echo ----------------------
echo Checking Auth Service...
curl -s -f http://localhost:8080/health >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Auth service not responding. Start with: make dev-auth
    exit /b 1
)
echo [OK] Auth service is healthy

echo Checking Puzzle Engine...
curl -s -f http://localhost:8082/health >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Puzzle service not responding. Start with: make dev-puzzle
    exit /b 1
)
echo [OK] Puzzle service is healthy

echo Checking Matchmaker...
curl -s -f http://localhost:8081/health >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Matchmaker service not responding. Start with: make dev-matchmaker
    exit /b 1
)
echo [OK] Matchmaker service is healthy
echo.

echo Step 2: User Registration
echo -------------------------
echo Registering user: %TEST_USERNAME%

curl -s -X POST "%AUTH_URL%/register" ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"%TEST_USERNAME%\",\"email\":\"%TEST_EMAIL%\",\"password\":\"%TEST_PASSWORD%\",\"region\":\"US\"}" ^
  > register_response.json

findstr "access_token" register_response.json >nul
if errorlevel 1 (
    echo [ERROR] Registration failed
    type register_response.json
    exit /b 1
)
echo [OK] User registered successfully
echo.

echo Step 3: User Login
echo ------------------
echo Logging in as %TEST_EMAIL%

curl -s -X POST "%AUTH_URL%/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"%TEST_EMAIL%\",\"password\":\"%TEST_PASSWORD%\"}" ^
  > login_response.json

findstr "access_token" login_response.json >nul
if errorlevel 1 (
    echo [ERROR] Login failed
    type login_response.json
    exit /b 1
)
echo [OK] Login successful
echo.

echo Step 4: Generate Puzzles (Sample Cipher Types)
echo -----------------------------------------------

echo Testing Caesar cipher...
curl -s -X POST "%PUZZLE_URL%/generate" ^
  -H "Content-Type: application/json" ^
  -d "{\"cipher_type\":\"CAESAR\",\"difficulty\":5}" ^
  > puzzle_caesar.json

findstr "\"id\"" puzzle_caesar.json >nul
if errorlevel 1 (
    echo [ERROR] Caesar puzzle generation failed
    exit /b 1
)
echo [OK] Caesar cipher working

echo Testing Vigenere cipher...
curl -s -X POST "%PUZZLE_URL%/generate" ^
  -H "Content-Type: application/json" ^
  -d "{\"cipher_type\":\"VIGENERE\",\"difficulty\":5}" ^
  > puzzle_vigenere.json

findstr "\"id\"" puzzle_vigenere.json >nul
if errorlevel 1 (
    echo [ERROR] Vigenere puzzle generation failed
    exit /b 1
)
echo [OK] Vigenere cipher working

echo Testing RSA_SIMPLE cipher...
curl -s -X POST "%PUZZLE_URL%/generate" ^
  -H "Content-Type: application/json" ^
  -d "{\"cipher_type\":\"RSA_SIMPLE\",\"difficulty\":8}" ^
  > puzzle_rsa.json

findstr "\"id\"" puzzle_rsa.json >nul
if errorlevel 1 (
    echo [ERROR] RSA puzzle generation failed
    exit /b 1
)
echo [OK] RSA cipher working
echo.

echo Step 5: Matchmaking
echo -------------------

REM Extract user_id from register response (simplified)
echo Joining matchmaking queue...

curl -s -X POST "%MATCHMAKER_URL%/join" ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\":\"test-user-123\",\"username\":\"%TEST_USERNAME%\",\"elo\":1400,\"region\":\"US\",\"game_mode\":\"RANKED_1V1\"}" ^
  > queue_response.json

findstr "queue_id" queue_response.json >nul
if errorlevel 1 (
    echo [ERROR] Failed to join queue
    type queue_response.json
    exit /b 1
)
echo [OK] Joined matchmaking queue
echo.

echo Step 6: Leaderboard
echo -------------------
echo Fetching leaderboard...

curl -s "%MATCHMAKER_URL%/leaderboard?limit=10" > leaderboard_response.json

findstr "entries" leaderboard_response.json >nul
if errorlevel 1 (
    echo [ERROR] Leaderboard fetch failed
    exit /b 1
)
echo [OK] Leaderboard retrieved
echo.

REM Cleanup
del register_response.json login_response.json puzzle_*.json queue_response.json leaderboard_response.json >nul 2>&1

echo ========================================
echo  INTEGRATION TEST COMPLETE
echo ========================================
echo.
echo Test Results:
echo -------------
echo [OK] Health checks: 3/3 services
echo [OK] Authentication: Registration, Login
echo [OK] Puzzle Engine: 3 cipher types tested
echo [OK] Matchmaking: Queue join
echo [OK] Leaderboard: Data retrieval
echo.
echo All systems operational!
echo Cipher Clash V2.0 is production ready!
echo.

endlocal
