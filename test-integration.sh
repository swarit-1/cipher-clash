#!/bin/bash

# Cipher Clash V2.0 - Integration Test Script
# Tests complete user workflow: Register → Login → Generate Puzzle → Join Matchmaking

set -e  # Exit on error

echo "🚀 Cipher Clash V2.0 - Integration Test Suite"
echo "=============================================="
echo ""

# Configuration
AUTH_URL="http://localhost:8080/api/v1/auth"
PUZZLE_URL="http://localhost:8082/api/v1/puzzle"
MATCHMAKER_URL="http://localhost:8081/api/v1/matchmaker"

# Test data
TIMESTAMP=$(date +%s)
TEST_USERNAME="testplayer_${TIMESTAMP}"
TEST_EMAIL="test${TIMESTAMP}@cipher.com"
TEST_PASSWORD="SecurePassword123!"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check if services are running
check_health() {
    local service=$1
    local url=$2

    info "Checking ${service} health..."
    if curl -s -f "${url}/health" > /dev/null; then
        success "${service} is healthy"
    else
        error "${service} is not responding. Start it with: make dev-${service}"
    fi
}

echo "Step 1: Health Checks"
echo "----------------------"
check_health "auth" "http://localhost:8080"
check_health "puzzle" "http://localhost:8082"
check_health "matchmaker" "http://localhost:8081"
echo ""

# Test 1: User Registration
echo "Step 2: User Registration"
echo "-------------------------"
info "Registering user: ${TEST_USERNAME}"

REGISTER_RESPONSE=$(curl -s -X POST "${AUTH_URL}/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${TEST_USERNAME}\",
    \"email\": \"${TEST_EMAIL}\",
    \"password\": \"${TEST_PASSWORD}\",
    \"region\": \"US\"
  }")

# Extract tokens
ACCESS_TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
USER_ID=$(echo $REGISTER_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    error "Registration failed: ${REGISTER_RESPONSE}"
fi

success "User registered successfully"
info "User ID: ${USER_ID}"
echo ""

# Test 2: Login
echo "Step 3: User Login"
echo "------------------"
info "Logging in as ${TEST_EMAIL}"

LOGIN_RESPONSE=$(curl -s -X POST "${AUTH_URL}/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${TEST_EMAIL}\",
    \"password\": \"${TEST_PASSWORD}\"
  }")

LOGIN_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$LOGIN_TOKEN" ]; then
    error "Login failed: ${LOGIN_RESPONSE}"
fi

success "Login successful"
echo ""

# Test 3: Get Profile
echo "Step 4: Get User Profile"
echo "------------------------"
info "Fetching profile for ${TEST_USERNAME}"

PROFILE_RESPONSE=$(curl -s "${AUTH_URL}/profile" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

PROFILE_USERNAME=$(echo $PROFILE_RESPONSE | grep -o '"username":"[^"]*' | cut -d'"' -f4)

if [ "$PROFILE_USERNAME" != "$TEST_USERNAME" ]; then
    error "Profile fetch failed: ${PROFILE_RESPONSE}"
fi

success "Profile retrieved successfully"
info "ELO: $(echo $PROFILE_RESPONSE | grep -o '"elo_rating":[0-9]*' | cut -d':' -f2)"
echo ""

# Test 4: Generate Puzzles (All 15 Cipher Types)
echo "Step 5: Generate Puzzles (All 15 Cipher Types)"
echo "-----------------------------------------------"

CIPHER_TYPES=("CAESAR" "VIGENERE" "RAIL_FENCE" "PLAYFAIR" "SUBSTITUTION"
              "TRANSPOSITION" "XOR" "BASE64" "MORSE" "BINARY"
              "HEXADECIMAL" "ROT13" "ATBASH" "BOOK_CIPHER" "RSA_SIMPLE")

PUZZLE_COUNT=0

for CIPHER in "${CIPHER_TYPES[@]}"; do
    info "Generating ${CIPHER} puzzle..."

    PUZZLE_RESPONSE=$(curl -s -X POST "${PUZZLE_URL}/generate" \
      -H "Content-Type: application/json" \
      -d "{
        \"cipher_type\": \"${CIPHER}\",
        \"difficulty\": 5
      }")

    PUZZLE_ID=$(echo $PUZZLE_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)

    if [ -z "$PUZZLE_ID" ]; then
        error "Failed to generate ${CIPHER} puzzle"
    fi

    ((PUZZLE_COUNT++))
    success "${CIPHER} puzzle generated (ID: ${PUZZLE_ID})"
done

success "All ${PUZZLE_COUNT}/15 cipher types working!"
echo ""

# Test 5: Generate Random Difficulty Puzzle
echo "Step 6: Auto-Difficulty Puzzle"
echo "-------------------------------"
info "Generating puzzle with auto-difficulty"

AUTO_PUZZLE_RESPONSE=$(curl -s -X POST "${PUZZLE_URL}/generate" \
  -H "Content-Type: application/json" \
  -d "{
    \"difficulty\": 7,
    \"player_elo\": 1400
  }")

AUTO_PUZZLE_ID=$(echo $AUTO_PUZZLE_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
AUTO_CIPHER_TYPE=$(echo $AUTO_PUZZLE_RESPONSE | grep -o '"cipher_type":"[^"]*' | cut -d'"' -f4)

if [ -z "$AUTO_PUZZLE_ID" ]; then
    error "Auto-difficulty puzzle generation failed"
fi

success "Auto-difficulty puzzle generated"
info "Cipher: ${AUTO_CIPHER_TYPE}, Difficulty: 7"
echo ""

# Test 6: Validate Solution (Intentional Fail)
echo "Step 7: Solution Validation"
echo "----------------------------"
info "Testing solution validation (incorrect solution)"

VALIDATE_RESPONSE=$(curl -s -X POST "${PUZZLE_URL}/validate" \
  -H "Content-Type: application/json" \
  -d "{
    \"puzzle_id\": \"${AUTO_PUZZLE_ID}\",
    \"solution\": \"WRONG ANSWER\",
    \"solve_time_ms\": 15000
  }")

IS_CORRECT=$(echo $VALIDATE_RESPONSE | grep -o '"is_correct":[a-z]*' | cut -d':' -f2)

if [ "$IS_CORRECT" == "true" ]; then
    error "Solution validation failed - accepted wrong answer"
fi

success "Solution validation working (correctly rejected wrong answer)"
echo ""

# Test 7: Join Matchmaking Queue
echo "Step 8: Matchmaking Queue"
echo "-------------------------"
info "Joining matchmaking queue"

QUEUE_RESPONSE=$(curl -s -X POST "${MATCHMAKER_URL}/join" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"${USER_ID}\",
    \"username\": \"${TEST_USERNAME}\",
    \"elo\": 1400,
    \"region\": \"US\",
    \"game_mode\": \"RANKED_1V1\"
  }")

QUEUE_ID=$(echo $QUEUE_RESPONSE | grep -o '"queue_id":"[^"]*' | cut -d'"' -f4)

if [ -z "$QUEUE_ID" ]; then
    error "Failed to join queue: ${QUEUE_RESPONSE}"
fi

success "Joined matchmaking queue"
info "Queue ID: ${QUEUE_ID}"
info "Estimated wait: $(echo $QUEUE_RESPONSE | grep -o '"estimated_wait_time_seconds":[0-9]*' | cut -d':' -f2) seconds"
echo ""

# Test 8: Queue Status
echo "Step 9: Queue Status Check"
echo "--------------------------"
info "Checking queue status"

STATUS_RESPONSE=$(curl -s "${MATCHMAKER_URL}/status?user_id=${USER_ID}")

IN_QUEUE=$(echo $STATUS_RESPONSE | grep -o '"in_queue":[a-z]*' | cut -d':' -f2)

if [ "$IN_QUEUE" != "true" ]; then
    error "Queue status check failed: ${STATUS_RESPONSE}"
fi

success "Queue status retrieved"
echo ""

# Test 9: Leave Queue
echo "Step 10: Leave Matchmaking Queue"
echo "---------------------------------"
info "Leaving queue"

LEAVE_RESPONSE=$(curl -s -X POST "${MATCHMAKER_URL}/leave" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"${USER_ID}\"
  }")

if echo $LEAVE_RESPONSE | grep -q "success"; then
    success "Left queue successfully"
else
    error "Failed to leave queue: ${LEAVE_RESPONSE}"
fi
echo ""

# Test 10: Leaderboard
echo "Step 11: Leaderboard"
echo "--------------------"
info "Fetching leaderboard"

LEADERBOARD_RESPONSE=$(curl -s "${MATCHMAKER_URL}/leaderboard?limit=10")

ENTRY_COUNT=$(echo $LEADERBOARD_RESPONSE | grep -o '"entries":\[' | wc -l)

if [ "$ENTRY_COUNT" -lt 1 ]; then
    error "Leaderboard fetch failed: ${LEADERBOARD_RESPONSE}"
fi

success "Leaderboard retrieved"
info "Total entries: $(echo $LEADERBOARD_RESPONSE | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
echo ""

# Test 11: Token Refresh
echo "Step 12: Token Refresh"
echo "----------------------"
info "Testing token refresh"

REFRESH_TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"refresh_token":"[^"]*' | cut -d'"' -f4)

REFRESH_RESPONSE=$(curl -s -X POST "${AUTH_URL}/refresh" \
  -H "Content-Type: application/json" \
  -d "{
    \"refresh_token\": \"${REFRESH_TOKEN}\"
  }")

NEW_ACCESS_TOKEN=$(echo $REFRESH_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$NEW_ACCESS_TOKEN" ]; then
    error "Token refresh failed: ${REFRESH_RESPONSE}"
fi

success "Token refreshed successfully"
echo ""

# Final Summary
echo "=============================================="
echo "🎉 INTEGRATION TEST SUITE COMPLETE"
echo "=============================================="
echo ""
echo "Test Results:"
echo "-------------"
echo "✅ Health checks: 3/3 services"
echo "✅ Authentication: Registration, Login, Profile, Token Refresh"
echo "✅ Puzzle Engine: All 15 cipher types working"
echo "✅ Solution Validation: Working correctly"
echo "✅ Matchmaking: Join, Status, Leave"
echo "✅ Leaderboard: Data retrieval working"
echo ""
echo "📊 Test Statistics:"
echo "-------------------"
echo "Total Tests: 12"
echo "Passed: 12"
echo "Failed: 0"
echo ""
echo "🎮 Test User Created:"
echo "Username: ${TEST_USERNAME}"
echo "Email: ${TEST_EMAIL}"
echo "User ID: ${USER_ID}"
echo ""
success "All systems operational! Cipher Clash V2.0 is production ready! 🚀"
