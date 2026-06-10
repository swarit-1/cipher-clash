#!/usr/bin/env bash
# API smoke test of the core loop against running services:
# health → register two users → JWT auth → queue both → match found →
# ELO/leaderboard checks → bot match creation.
set -uo pipefail

PASS=0
FAIL=0

check() { # name, condition-result
  if [[ "$2" == "0" ]]; then
    printf '  \033[32mPASS\033[0m %s\n' "$1"; ((PASS++))
  else
    printf '  \033[31mFAIL\033[0m %s\n' "$1"; ((FAIL++))
  fi
}

jsonget() { python3 -c "import sys,json
try:
    d = json.load(sys.stdin)
    for k in '$1'.split('.'):
        d = d[k]
    print(d)
except Exception:
    sys.exit(1)"; }

echo "── Health checks"
for entry in achievement:8083 missions:8084 auth:8085 matchmaker:8086 puzzle_engine:8087 game:8088 tutorial:8089 practice:8090 mastery:8091 social:8092 cosmetics:8093; do
  name="${entry%%:*}"; port="${entry##*:}"
  curl -sf -m 3 "http://localhost:$port/health" >/dev/null
  check "$name (:$port)" $?
done

TS=$(date +%s)
echo "── Auth"
R1=$(curl -s -X POST http://localhost:8085/api/v1/auth/register -H 'Content-Type: application/json' \
  -d "{\"username\":\"smokea$TS\",\"email\":\"smokea$TS@test.io\",\"password\":\"Sm0keTest!pass\",\"region\":\"US\"}")
T1=$(echo "$R1" | jsonget access_token); check "register user A" $?
R2=$(curl -s -X POST http://localhost:8085/api/v1/auth/register -H 'Content-Type: application/json' \
  -d "{\"username\":\"smokeb$TS\",\"email\":\"smokeb$TS@test.io\",\"password\":\"Sm0keTest!pass\",\"region\":\"US\"}")
T2=$(echo "$R2" | jsonget access_token); check "register user B" $?

L=$(curl -s -X POST http://localhost:8085/api/v1/auth/login -H 'Content-Type: application/json' \
  -d "{\"username\":\"smokea$TS\",\"password\":\"Sm0keTest!pass\"}")
echo "$L" | jsonget refresh_token >/dev/null; check "login returns refresh token" $?

P=$(curl -s http://localhost:8085/api/v1/auth/profile -H "Authorization: Bearer $T1")
echo "$P" | jsonget elo_rating >/dev/null; check "JWT-protected profile" $?

CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8085/api/v1/auth/profile)
[[ "$CODE" == "401" ]]; check "profile rejects missing token (401)" $?

echo "── Puzzle engine"
PZ=$(curl -s -X POST http://localhost:8087/api/v1/puzzle/generate -H 'Content-Type: application/json' \
  -d '{"cipher_type":"VIGENERE","difficulty":3}')
echo "$PZ" | jsonget encrypted_text >/dev/null; check "generate VIGENERE puzzle" $?
echo "$PZ" | jsonget plaintext >/dev/null 2>&1; [[ $? -ne 0 ]]; check "plaintext withheld from clients" $?

echo "── Matchmaking"
curl -s -X POST http://localhost:8086/api/v1/matchmaker/join -H "Authorization: Bearer $T1" \
  -H 'Content-Type: application/json' -d '{"game_mode":"RANKED_1V1"}' | jsonget queue_id >/dev/null
check "user A joins queue" $?
curl -s -X POST http://localhost:8086/api/v1/matchmaker/join -H "Authorization: Bearer $T2" \
  -H 'Content-Type: application/json' -d '{"game_mode":"RANKED_1V1"}' | jsonget queue_id >/dev/null
check "user B joins queue" $?

MATCH_ID=""
for _ in $(seq 1 8); do
  sleep 2
  S=$(curl -s http://localhost:8086/api/v1/matchmaker/status -H "Authorization: Bearer $T1")
  if [[ "$(echo "$S" | jsonget status 2>/dev/null)" == "match_found" ]]; then
    MATCH_ID=$(echo "$S" | jsonget match_id)
    break
  fi
done
[[ -n "$MATCH_ID" ]]; check "match found via status poll" $?

echo "── Bot match"
B=$(curl -s -X POST http://localhost:8088/api/v1/match/bot -H "Authorization: Bearer $T1")
echo "$B" | jsonget match_id >/dev/null; check "bot match created" $?
[[ "$(echo "$B" | jsonget opponent.is_bot 2>/dev/null)" == "True" ]]; check "opponent is a bot" $?

echo "── Leaderboard"
curl -s "http://localhost:8086/api/v1/matchmaker/leaderboard?limit=10" | jsonget entries >/dev/null
check "leaderboard responds" $?

echo
echo "Result: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
