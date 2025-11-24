# Running Cipher Clash Services Manually on Windows

## Quick Start

### 1. Start Infrastructure
```powershell
cd c:\Users\swart\cipher-clash\cipher-clash
docker-compose up -d postgres redis rabbitmq
```

### 2. Run Services in Separate Terminals

Open **three separate PowerShell/CMD terminals** and run one command in each:

**Terminal 1 - Auth Service:**
```cmd
cd c:\Users\swart\cipher-clash\cipher-clash
.\run-auth.bat
```

**Terminal 2 - Puzzle Engine:**
```cmd
cd c:\Users\swart\cipher-clash\cipher-clash
.\run-puzzle.bat
```

**Terminal 3 - Matchmaker Service:**
```cmd
cd c:\Users\swart\cipher-clash\cipher-clash
.\run-matchmaker.bat
```

### 3. Verify Services

In another terminal:
```powershell
curl http://localhost:8080/health  # Auth Service
curl http://localhost:8082/health  # Puzzle Engine
curl http://localhost:8081/health  # Matchmaker
```

## Troubleshooting Database Connection

If you see "password authentication failed for user postgres", try:

1. **Restart Postgres with trust auth (development only):**
```powershell
docker-compose down
docker run --name cipher-clash-postgres-dev -p 5432:5432 -e POSTGRES_PASSWORD=password -e POSTGRES_DB=cipher_clash -v ${PWD}/infra/postgres/schema_v2.sql:/docker-entrypoint-initdb.d/schema_v2.sql -d postgres:15-alpine
docker-compose up -d redis rabbitmq
```

2. **Test connection:**
```powershell
docker exec cipher-clash-postgres-dev psql -U postgres -d cipher_clash -c "SELECT 1"
```

3. **Then retry running the services using the batch scripts above.**

## Service Ports

- **Postgres**: localhost:5432
- **Redis**: localhost:6379
- **RabbitMQ**: localhost:5672 (Management: http://localhost:15672)
- **Auth Service**: localhost:8080
- **Puzzle Engine**: localhost:8082
- **Matchmaker**: localhost:8081

## Stopping Services

```powershell
# Stop infrastructure
docker-compose down

# Services will stop when you close their terminal windows or press Ctrl+C
```
