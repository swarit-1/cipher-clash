#!/usr/bin/env bash
# Cipher Clash — one-command startup.
#
#   ./start.sh          boot infra + migrate + all 11 services + web client
#   ./start.sh stop     stop services and containers
#   ./start.sh status   health table
#   ./start.sh logs     tail all service logs
#
# Works from a fresh clone: generates .env with random secrets on first run.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

SERVICES=(achievement missions auth matchmaker puzzle_engine game tutorial practice mastery social cosmetics)
PORTS=(8083 8084 8085 8086 8087 8088 8089 8090 8091 8092 8093)
PID_DIR=".run"
LOG_DIR="logs"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✘\033[0m %s\n' "$*"; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "$1 is required. $2"
    exit 1
  fi
}

ensure_env() {
  if [[ -f .env ]]; then return; fi
  bold "Generating .env with random secrets…"
  local pg_pw redis_pw rabbit_pw jwt internal
  pg_pw="$(openssl rand -hex 16)"
  redis_pw="$(openssl rand -hex 16)"
  rabbit_pw="$(openssl rand -hex 16)"
  jwt="$(openssl rand -hex 32)"
  internal="$(openssl rand -hex 32)"
  cat > .env <<ENV
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${pg_pw}
POSTGRES_DB=cipher_clash
DATABASE_URL=postgres://postgres:${pg_pw}@localhost:5432/cipher_clash?sslmode=disable
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=${redis_pw}
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=${rabbit_pw}
RABBITMQ_VHOST=cipher_clash
RABBITMQ_URL=amqp://admin:${rabbit_pw}@localhost:5672/cipher_clash
JWT_SECRET=${jwt}
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=168h
INTERNAL_API_TOKEN=${internal}
PUZZLE_ENGINE_URL=http://localhost:8087
MATCHMAKER_URL=http://localhost:8086
ALLOWED_ORIGINS=http://localhost:3000
LOG_LEVEL=INFO
ENVIRONMENT=development
ENV
  ok ".env created (secrets are local to this machine)"
}

wait_for() { # name, command, timeout_s
  local name="$1" cmd="$2" timeout="${3:-90}" i=0
  while (( i < timeout )); do
    if eval "$cmd" >/dev/null 2>&1; then ok "$name ready"; return 0; fi
    sleep 1; ((i++))
  done
  err "$name did not become ready within ${timeout}s"
  return 1
}

start_infra() {
  bold "Starting infrastructure (PostgreSQL, Redis, RabbitMQ)…"
  docker compose up -d postgres redis rabbitmq
  set -a; source .env; set +a
  wait_for "PostgreSQL" "docker compose exec -T postgres pg_isready -U \$POSTGRES_USER"
  wait_for "Redis"      "docker compose exec -T redis redis-cli -a \$REDIS_PASSWORD ping | grep -q PONG"
  wait_for "RabbitMQ"   "docker compose exec -T rabbitmq rabbitmq-diagnostics -q ping"
}

run_migrations() {
  bold "Applying database migrations…"
  bash scripts/migrate.sh up
}

build_services() {
  bold "Building ${#SERVICES[@]} Go services…"
  mkdir -p bin
  for svc in "${SERVICES[@]}"; do
    go build -o "bin/$svc" "./services/$svc"
  done
  ok "binaries in ./bin"
}

start_services() {
  bold "Starting services…"
  mkdir -p "$PID_DIR" "$LOG_DIR"
  set -a; source .env; set +a
  for i in "${!SERVICES[@]}"; do
    local svc="${SERVICES[$i]}"
    if [[ -f "$PID_DIR/$svc.pid" ]] && kill -0 "$(cat "$PID_DIR/$svc.pid")" 2>/dev/null; then
      ok "$svc already running"
      continue
    fi
    "./bin/$svc" > "$LOG_DIR/$svc.log" 2>&1 &
    echo $! > "$PID_DIR/$svc.pid"
  done
  for i in "${!SERVICES[@]}"; do
    wait_for "${SERVICES[$i]} (:${PORTS[$i]})" "curl -sf -m 2 http://localhost:${PORTS[$i]}/health" 30
  done
}

stop_services() {
  bold "Stopping services…"
  if [[ -d "$PID_DIR" ]]; then
    for pidfile in "$PID_DIR"/*.pid; do
      [[ -f "$pidfile" ]] || continue
      local pid; pid="$(cat "$pidfile")"
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        ok "stopped $(basename "$pidfile" .pid)"
      fi
      rm -f "$pidfile"
    done
  fi
}

status_table() {
  bold "Service status"
  printf '  %-14s %-7s %s\n' "SERVICE" "PORT" "HEALTH"
  for i in "${!SERVICES[@]}"; do
    if curl -sf -m 2 "http://localhost:${PORTS[$i]}/health" >/dev/null 2>&1; then
      printf '  %-14s %-7s \033[32m%s\033[0m\n' "${SERVICES[$i]}" "${PORTS[$i]}" "healthy"
    else
      printf '  %-14s %-7s \033[31m%s\033[0m\n' "${SERVICES[$i]}" "${PORTS[$i]}" "down"
    fi
  done
  printf '  %-14s %-7s %s\n' "postgres" "5432" "$(docker compose ps postgres --format '{{.State}}' 2>/dev/null || echo down)"
  printf '  %-14s %-7s %s\n' "redis" "6379" "$(docker compose ps redis --format '{{.State}}' 2>/dev/null || echo down)"
  printf '  %-14s %-7s %s\n' "rabbitmq" "5672" "$(docker compose ps rabbitmq --format '{{.State}}' 2>/dev/null || echo down)"
}

start_client() {
  bold "Starting the web client…"
  echo
  echo "  ┌─────────────────────────────────────────────────┐"
  echo "  │  Cipher Clash → http://localhost:3000           │"
  echo "  │  Open a second (incognito) tab to play 1v1.     │"
  echo "  │  Ctrl-C stops the client AND the backend.       │"
  echo "  └─────────────────────────────────────────────────┘"
  echo
  trap 'echo; stop_services; echo "Infra containers left running (docker compose stop to halt)."' EXIT INT TERM
  (cd apps/client && flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0)
}

case "${1:-up}" in
  up)
    require docker "Install Docker Desktop: https://docs.docker.com/get-docker/"
    require go "brew install go"
    require flutter "brew install --cask flutter"
    require curl ""
    ensure_env
    start_infra
    run_migrations
    build_services
    start_services
    status_table
    start_client
    ;;
  stop)
    stop_services
    docker compose stop
    ;;
  status)
    status_table
    ;;
  logs)
    tail -f "$LOG_DIR"/*.log
    ;;
  *)
    echo "usage: ./start.sh [up|stop|status|logs]"
    exit 1
    ;;
esac
