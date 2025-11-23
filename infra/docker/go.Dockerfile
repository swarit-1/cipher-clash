FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the specific service passed as a build arg
ARG SERVICE_NAME
RUN go build -o /app/bin/service ./services/${SERVICE_NAME}

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/bin/service .

CMD ["./service"]
