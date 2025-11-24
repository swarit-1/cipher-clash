@echo off
set DATABASE_URL=postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable
set REDIS_ADDR=localhost:6379
set RABBITMQ_URL=amqp://admin:password@localhost:5672/cipher_clash
go run services/matchmaker/main.go
