# Cipher Clash V2.0 - Makefile

.PHONY: help proto build test docker-up docker-down migrate-up migrate-down clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Protocol Buffers
proto: ## Generate Go code from Protocol Buffers
	@echo "Generating Protocol Buffer code..."
	@protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		proto/*.proto
	@echo "Proto generation complete!"

# Build
build: ## Build all services
	@echo "Building services..."
	@go build -o bin/auth services/auth/main.go
	@go build -o bin/matchmaker services/matchmaker/main.go
	@go build -o bin/puzzle-engine services/puzzle_engine/main.go
	@go build -o bin/game services/game/main.go
	@echo "Build complete!"

build-docker: ## Build Docker images
	@echo "Building Docker images..."
	@docker-compose build
	@echo "Docker build complete!"

# Testing
test: ## Run all tests
	@echo "Running tests..."
	@go test -v -cover ./...

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

test-integration: ## Run integration tests (requires services running)
	@echo "Running integration tests..."
	@bash test-integration.sh

test-integration-win: ## Run integration tests on Windows
	@echo "Running integration tests (Windows)..."
	@test-integration.bat

lint: ## Run linters
	@echo "Running linters..."
	@golangci-lint run ./...

# Docker
docker-up: ## Start all services with Docker Compose
	@echo "Starting services..."
	@docker-compose up -d
	@echo "Services started!"
	@echo "PostgreSQL: localhost:5432"
	@echo "Redis: localhost:6379"
	@echo "RabbitMQ: localhost:5672 (Management UI: http://localhost:15672)"
	@echo "Auth Service: localhost:8080"
	@echo "Matchmaker: localhost:8081"
	@echo "Puzzle Engine: localhost:8082"
	@echo "Game Service: localhost:8083"

docker-down: ## Stop all services
	@echo "Stopping services..."
	@docker-compose down
	@echo "Services stopped!"

docker-logs: ## View logs from all services
	@docker-compose logs -f

docker-clean: ## Remove all containers, volumes, and images
	@echo "Cleaning Docker resources..."
	@docker-compose down -v
	@docker system prune -f
	@echo "Cleanup complete!"

# Database
db-create: ## Create database
	@echo "Creating database..."
	@docker exec -it cipher-clash-1-postgres-1 createdb -U postgres cipher_clash || true

db-drop: ## Drop database
	@echo "Dropping database..."
	@docker exec -it cipher-clash-1-postgres-1 dropdb -U postgres cipher_clash || true

db-reset: db-drop db-create ## Reset database
	@echo "Database reset complete!"

db-psql: ## Connect to PostgreSQL
	@docker exec -it cipher-clash-1-postgres-1 psql -U postgres -d cipher_clash

migrate-install: ## Install golang-migrate tool
	@echo "Installing golang-migrate..."
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@echo "golang-migrate installed!"

migrate-up: ## Apply all database migrations
	@echo "Applying migrations..."
	@migrate -path infra/postgres/migrations -database "postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" up
	@echo "Migrations applied!"

migrate-down: ## Rollback last migration
	@echo "Rolling back last migration..."
	@migrate -path infra/postgres/migrations -database "postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" down 1
	@echo "Rollback complete!"

migrate-force: ## Force migration version (use: make migrate-force VERSION=1)
	@migrate -path infra/postgres/migrations -database "postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" force $(VERSION)

# Development
dev-auth: ## Run auth service locally
	@echo "Starting auth service..."
	@DATABASE_URL="postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" \
	 REDIS_ADDR="localhost:6379" \
	 JWT_SECRET="dev-secret-key" \
	 go run services/auth/main.go

dev-matchmaker: ## Run matchmaker service locally
	@echo "Starting matchmaker service..."
	@DATABASE_URL="postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" \
	 REDIS_ADDR="localhost:6379" \
	 RABBITMQ_URL="amqp://admin:password@localhost:5672/cipher_clash" \
	 go run services/matchmaker/main.go

dev-puzzle: ## Run puzzle engine locally
	@echo "Starting puzzle engine service..."
	@DATABASE_URL="postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" \
	 REDIS_ADDR="localhost:6379" \
	 go run services/puzzle_engine/main.go

dev-game: ## Run game service locally
	@echo "Starting game service..."
	@DATABASE_URL="postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" \
	 REDIS_ADDR="localhost:6379" \
	 RABBITMQ_URL="amqp://admin:password@localhost:5672/cipher_clash" \
	 go run services/game/main.go

# Clean
clean: ## Clean build artifacts
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -f coverage.out coverage.html
	@go clean -cache
	@echo "Clean complete!"

# Dependencies
deps: ## Install Go dependencies
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy
	@echo "Dependencies installed!"

deps-update: ## Update Go dependencies
	@echo "Updating dependencies..."
	@go get -u ./...
	@go mod tidy
	@echo "Dependencies updated!"

# Tools
install-tools: ## Install development tools
	@echo "Installing tools..."
	@go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	@go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@echo "Tools installed!"

# Flutter
flutter-get: ## Install Flutter dependencies
	@echo "Installing Flutter dependencies..."
	@cd apps/client && flutter pub get
	@echo "Flutter dependencies installed!"

flutter-run: ## Run Flutter app
	@echo "Running Flutter app..."
	@cd apps/client && flutter run -d chrome

flutter-build-web: ## Build Flutter web app
	@echo "Building Flutter web app..."
	@cd apps/client && flutter build web
	@echo "Build complete! Output: apps/client/build/web"

# All-in-one commands
setup: install-tools deps flutter-get ## Complete project setup
	@echo "Setup complete! Run 'make docker-up' to start services."

start: docker-up ## Start all services
	@echo "All services started!"

stop: docker-down ## Stop all services
	@echo "All services stopped!"

restart: docker-down docker-up ## Restart all services
	@echo "All services restarted!"
