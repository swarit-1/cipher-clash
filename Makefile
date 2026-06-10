# Cipher Clash - Makefile

SERVICES := achievement missions auth matchmaker puzzle_engine game tutorial practice mastery social cosmetics

.PHONY: help build test lint docker-up docker-down migrate clean deps

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build
build: ## Build all services
	@echo "Building services..."
	@for svc in $(SERVICES); do \
		echo "  > $$svc"; \
		go build -o bin/$$svc ./services/$$svc || exit 1; \
	done
	@echo "Build complete!"

build-docker: ## Build Docker images
	@docker compose build

# Testing
test: ## Run all tests with race detector
	@go test -race -cover ./...

test-coverage: ## Run tests with coverage report
	@go test -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

smoke: ## Run API smoke test against running services
	@bash scripts/smoke.sh

lint: ## Run linters
	@golangci-lint run ./...

vet: ## Run go vet
	@go vet ./...

# Docker (infrastructure only; use ./start.sh for the full stack)
docker-infra: ## Start postgres/redis/rabbitmq
	@docker compose up -d postgres redis rabbitmq

docker-up: ## Start everything (infra + all services) in Docker
	@docker compose up -d --build
	@echo "Services: achievement:8083 missions:8084 auth:8085 matchmaker:8086"
	@echo "          puzzle:8087 game:8088 tutorial:8089 practice:8090"
	@echo "          mastery:8091 social:8092 cosmetics:8093"

docker-down: ## Stop all containers
	@docker compose down

docker-logs: ## Tail logs
	@docker compose logs -f

docker-clean: ## Remove containers and volumes
	@docker compose down -v

# Database
migrate: ## Apply pending migrations
	@bash scripts/migrate.sh up

db-psql: ## Open a psql shell
	@docker compose exec postgres psql -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-cipher_clash}

db-reset: ## Drop volumes and re-migrate from scratch
	@docker compose down -v
	@docker compose up -d postgres
	@sleep 3
	@bash scripts/migrate.sh up

# Clean
clean: ## Clean build artifacts
	@rm -rf bin/ coverage.out coverage.html

# Dependencies
deps: ## Install Go dependencies
	@go mod download && go mod tidy

# Flutter
flutter-get: ## Install Flutter dependencies
	@cd apps/client && flutter pub get

flutter-run: ## Run Flutter web app on port 3000
	@cd apps/client && flutter run -d web-server --web-port 3000

flutter-build-web: ## Build Flutter web app
	@cd apps/client && flutter build web --release

flutter-build-demo: ## Build Flutter web app in demo mode (no backend needed)
	@cd apps/client && flutter build web --release --dart-define=DEMO_MODE=true

# All-in-one
setup: deps flutter-get ## Complete project setup
	@echo "Setup complete! Run ./start.sh to launch the full stack."
