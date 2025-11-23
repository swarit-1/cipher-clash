# Cipher Clash

Competitive Cryptography Esports Platform.

## Architecture
- **Frontend**: Flutter (Mobile/Web)
- **Backend**: Go (Microservices)
- **Database**: PostgreSQL + Redis
- **Infrastructure**: Docker + Kubernetes

## Prerequisites
- Go 1.21+
- Flutter 3.0+
- Docker & Docker Compose

## Getting Started

### 1. Start Infrastructure
```bash
docker-compose up -d
```

### 2. Run Backend Services
```bash
# Matchmaker
go run services/matchmaker/main.go

# Puzzle Engine
go run services/puzzle_engine/main.go

# Game Service
go run services/game/main.go
```

### 3. Run Frontend
```bash
cd apps/client
flutter run -d chrome
```

## Project Structure
- `apps/client`: Flutter application
- `services/`: Go microservices
- `pkg/`: Shared Go code and Proto definitions
- `infra/`: Infrastructure configuration (Docker, K8s, SQL)
