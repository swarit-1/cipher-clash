@echo off
set DATABASE_URL=postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable
set REDIS_ADDR=localhost:6379
set JWT_SECRET=dev-secret-key
go run services/auth/main.go
