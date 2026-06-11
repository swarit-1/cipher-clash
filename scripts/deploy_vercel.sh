#!/usr/bin/env bash
# Build the Flutter web client and deploy the static output to Vercel.
#
#   scripts/deploy_vercel.sh demo            # DEMO_MODE build (no backend needed)
#   scripts/deploy_vercel.sh live <API_HOST> # live build pointed at a deployed backend
#
# Vercel cannot build Flutter, so we build locally and ship the artifact
# with `vercel deploy --prebuilt`-style static upload.
# Requires: flutter, vercel CLI, `vercel login` + `vercel link` done once.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/apps/client"
MODE="${1:-demo}"

cd "$CLIENT_DIR"

case "$MODE" in
  demo)
    echo "Building DEMO_MODE bundle (fully playable without a backend)…"
    flutter build web --release --dart-define=DEMO_MODE=true
    ;;
  live)
    HOST="${2:?usage: deploy_vercel.sh live <https://api.example.com> [wss://api.example.com]}"
    WS_HOST="${3:-${HOST/https:/wss:}}"
    echo "Building live bundle against $HOST…"
    flutter build web --release \
      --dart-define=AUTH_URL="$HOST/auth/api/v1" \
      --dart-define=MATCHMAKER_URL="$HOST/matchmaker/api/v1" \
      --dart-define=PUZZLE_URL="$HOST/puzzle/api/v1" \
      --dart-define=GAME_URL="$HOST/game/api/v1" \
      --dart-define=GAME_WS_URL="$WS_HOST/game/ws" \
      --dart-define=TUTORIAL_URL="$HOST/tutorial/api/v1" \
      --dart-define=PRACTICE_URL="$HOST/practice/api/v1" \
      --dart-define=ACHIEVEMENT_URL="$HOST/achievement/api/v1" \
      --dart-define=MISSIONS_URL="$HOST/missions/api/v1" \
      --dart-define=MASTERY_URL="$HOST/mastery/api/v1" \
      --dart-define=SOCIAL_URL="$HOST/social/api/v1" \
      --dart-define=COSMETICS_URL="$HOST/cosmetics/api/v1"
    ;;
  *)
    echo "usage: deploy_vercel.sh [demo|live <host>]" >&2
    exit 1
    ;;
esac

cp vercel.json build/web/vercel.json
echo "Deploying build/web to Vercel…"
cd build/web
vercel deploy --prod --yes
