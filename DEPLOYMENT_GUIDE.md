# 🚀 Cipher Clash V2.0 - Deployment Guide

## Production Deployment Checklist

### Pre-Deployment

- [ ] Review and update `.env` with production secrets
- [ ] Set strong `JWT_SECRET` (minimum 32 characters)
- [ ] Configure production database URL
- [ ] Set up SSL/TLS certificates
- [ ] Review CORS settings
- [ ] Enable rate limiting
- [ ] Set up monitoring alerts

---

## Quick Deploy with Docker

### 1. Prepare Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with production values
nano .env
```

**Critical Variables:**
```env
# MUST CHANGE FOR PRODUCTION
JWT_SECRET=CHANGE-THIS-TO-RANDOM-32-CHAR-STRING
DATABASE_URL=postgres://user:password@host:5432/cipher_clash?sslmode=require

# Optional but recommended
ENVIRONMENT=production
LOG_LEVEL=INFO
ENABLE_CORS=false
```

### 2. Deploy Services

```bash
# Build and start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Health checks
curl http://localhost:8080/health  # Auth
curl http://localhost:8081/health  # Matchmaker
curl http://localhost:8082/health  # Puzzle
curl http://localhost:8083/health  # Game
```

### 3. Initialize Database

```bash
# Database will auto-initialize from schema_v2.sql
# Verify tables exist
make db-psql
\dt
```

---

## Manual Deployment (Production Servers)

### Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- PostgreSQL 15+
- Redis 7+
- RabbitMQ 3.12+
- Nginx (reverse proxy)
- SSL certificate (Let's Encrypt)

### Step 1: Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install PostgreSQL
sudo apt install postgresql-15 postgresql-contrib

# Install Redis
sudo apt install redis-server

# Install RabbitMQ
sudo apt install rabbitmq-server

# Install Go 1.23
wget https://go.dev/dl/go1.23.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install Nginx
sudo apt install nginx certbot python3-certbot-nginx
```

### Step 2: Setup Database

```bash
# Create database
sudo -u postgres psql
CREATE DATABASE cipher_clash;
CREATE USER cipher_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE cipher_clash TO cipher_user;
\q

# Initialize schema
psql -U cipher_user -d cipher_clash -f infra/postgres/schema_v2.sql
```

### Step 3: Configure Services

```bash
# Clone repository
git clone https://github.com/swarit-1/cipher-clash.git
cd cipher-clash

# Install dependencies
make deps

# Build services
make build

# Binaries will be in ./bin/
```

### Step 4: Create Systemd Services

**Auth Service:** `/etc/systemd/system/cipher-auth.service`
```ini
[Unit]
Description=Cipher Clash Auth Service
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/cipher-clash
Environment="DATABASE_URL=postgres://cipher_user:password@localhost:5432/cipher_clash"
Environment="REDIS_ADDR=localhost:6379"
Environment="JWT_SECRET=your-production-secret"
Environment="PORT=8080"
ExecStart=/opt/cipher-clash/bin/auth
Restart=always

[Install]
WantedBy=multi-user.target
```

Repeat for `cipher-puzzle.service`, `cipher-matchmaker.service`, `cipher-game.service` (ports 8082, 8081, 8083)

```bash
# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable cipher-auth cipher-puzzle cipher-matchmaker cipher-game
sudo systemctl start cipher-auth cipher-puzzle cipher-matchmaker cipher-game

# Check status
sudo systemctl status cipher-*
```

### Step 5: Configure Nginx Reverse Proxy

**/etc/nginx/sites-available/cipher-clash**
```nginx
upstream auth_backend {
    server localhost:8080;
}

upstream puzzle_backend {
    server localhost:8082;
}

upstream matchmaker_backend {
    server localhost:8081;
}

upstream game_backend {
    server localhost:8083;
}

server {
    listen 80;
    server_name api.cipherclash.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.cipherclash.com;

    ssl_certificate /etc/letsencrypt/live/api.cipherclash.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.cipherclash.com/privkey.pem;

    # Auth Service
    location /api/v1/auth {
        proxy_pass http://auth_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Puzzle Engine
    location /api/v1/puzzle {
        proxy_pass http://puzzle_backend;
        proxy_set_header Host $host;
    }

    # Matchmaker
    location /api/v1/matchmaker {
        proxy_pass http://matchmaker_backend;
        proxy_set_header Host $host;
    }

    # Game Service (WebSocket)
    location /ws {
        proxy_pass http://game_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/cipher-clash /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificate
sudo certbot --nginx -d api.cipherclash.com
```

---

## Monitoring & Maintenance

### Health Checks

```bash
# Create health check script
cat > /opt/cipher-clash/health-check.sh << 'EOF'
#!/bin/bash
services=("auth:8080" "puzzle:8082" "matchmaker:8081" "game:8083")

for service in "${services[@]}"; do
    name="${service%%:*}"
    port="${service##*:}"

    if curl -sf "http://localhost:$port/health" > /dev/null; then
        echo "✓ $name is healthy"
    else
        echo "✗ $name is DOWN!"
        systemctl restart "cipher-$name"
    fi
done
EOF

chmod +x /opt/cipher-clash/health-check.sh

# Add to crontab (check every 5 minutes)
crontab -e
*/5 * * * * /opt/cipher-clash/health-check.sh
```

### Log Management

```bash
# Configure logrotate
cat > /etc/logrotate.d/cipher-clash << 'EOF'
/var/log/cipher-clash/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload cipher-*
    endscript
}
EOF
```

### Backup Strategy

```bash
# Daily database backup
cat > /opt/cipher-clash/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/cipher-clash"

mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
pg_dump -U cipher_user cipher_clash | gzip > "$BACKUP_DIR/db_$DATE.sql.gz"

# Backup Redis
redis-cli SAVE
cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"

# Keep only last 7 days
find "$BACKUP_DIR" -type f -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/cipher-clash/backup.sh

# Schedule daily at 2 AM
crontab -e
0 2 * * * /opt/cipher-clash/backup.sh
```

---

## Performance Tuning

### PostgreSQL Optimization

```sql
-- /etc/postgresql/15/main/postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
max_connections = 200
```

### Redis Optimization

```conf
# /etc/redis/redis.conf
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

### System Limits

```bash
# /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536

# Apply
sudo sysctl -p
```

---

## Scaling Strategies

### Horizontal Scaling

1. **Load Balancer**: Use Nginx or HAProxy
2. **Multiple Instances**: Run 2+ instances of each service
3. **Shared State**: PostgreSQL and Redis handle shared state

Example with 3 auth service instances:
```nginx
upstream auth_backend {
    server 10.0.1.10:8080;
    server 10.0.1.11:8080;
    server 10.0.1.12:8080;
}
```

### Database Replication

```bash
# Primary-Replica setup for read scaling
# See PostgreSQL streaming replication documentation
```

---

## Security Hardening

### Firewall Rules

```bash
# UFW firewall
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 22/tcp    # SSH
sudo ufw enable

# Block direct access to service ports
sudo ufw deny 8080:8083/tcp
```

### Environment Security

```bash
# Restrict .env file permissions
chmod 600 .env

# Use environment-specific configs
if [ "$ENVIRONMENT" = "production" ]; then
    # Production-specific settings
    export ENABLE_DEBUG=false
    export LOG_LEVEL=WARN
fi
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u cipher-auth -n 50 --no-pager

# Check port conflicts
sudo netstat -tulpn | grep :8080

# Verify database connection
psql -U cipher_user -d cipher_clash -c "SELECT 1;"
```

### High Memory Usage

```bash
# Check service memory
ps aux | grep cipher

# Restart services
sudo systemctl restart cipher-*

# Clear Redis cache
redis-cli FLUSHALL
```

### Slow Performance

```bash
# Check database connections
psql -U cipher_user -d cipher_clash -c "SELECT count(*) FROM pg_stat_activity;"

# Analyze slow queries
psql -U cipher_user -d cipher_clash -c "SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Check Redis hit rate
redis-cli INFO stats | grep keyspace_hits
```

---

## Testing Production Deployment

```bash
# Run full test suite
./test-production.sh

# Load testing (optional)
# Install: go install github.com/tsenart/vegeta@latest
echo "GET http://api.cipherclash.com/api/v1/auth/health" | \
  vegeta attack -duration=30s -rate=100 | \
  vegeta report
```

---

## Rollback Plan

```bash
# Stop new deployment
sudo systemctl stop cipher-*

# Restore database backup
gunzip < /var/backups/cipher-clash/db_20250123.sql.gz | \
  psql -U cipher_user cipher_clash

# Revert code
git checkout previous-stable-tag
make build

# Restart services
sudo systemctl start cipher-*
```

---

## Support & Monitoring

### Recommended Tools

- **Monitoring**: Prometheus + Grafana
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **Alerts**: PagerDuty or similar
- **Uptime**: UptimeRobot

### Metrics to Track

- Request latency (p50, p95, p99)
- Error rates
- Active users
- Matchmaking queue times
- Database connection pool usage
- Cache hit rates

---

**Production deployment complete!** 🎉

For issues: https://github.com/swarit-1/cipher-clash/issues
