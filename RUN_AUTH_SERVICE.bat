@echo off
echo Starting Auth Service with correct configuration...
echo.

cd services\auth

set DATABASE_URL=postgres://postgres:cipherclash2025@127.0.0.1:5432/cipher_clash?sslmode=disable
set REDIS_ADDR=127.0.0.1:6379

echo Database: cipher_clash
echo Password: cipherclash2025
echo.

go run main.go
