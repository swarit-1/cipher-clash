package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/handler"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/queue"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/service"
)

func main() {
	// Load .env file from root directory (../../.env) or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load() // Fallback to current directory

	// Determine the port with proper priority:
	// 1. MATCHMAKER_PORT (service-specific from .env) - highest priority
	// 2. PORT (generic override) - for Docker/special cases
	// 3. Default 8086 - sensible fallback
	port := os.Getenv("MATCHMAKER_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8086"
	}

	// Initialize logger
	log := logger.New("matchmaker")
	log.Info("Starting Matchmaker Service...")

	// Load configuration
	cfg := config.LoadConfig()

	// Override config port to ensure consistency across the app
	cfg.Server.Port = port

	// Initialize database
	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{
			"error": err.Error(),
		})
	}
	defer database.Close()

	// Initialize cache
	cacheClient, err := cache.New(cfg.Redis, log)
	if err != nil {
		log.Fatal("Failed to connect to Redis", map[string]interface{}{
			"error": err.Error(),
		})
	}
	defer cacheClient.Close()

	// Initialize messaging publisher
	publisher, err := messaging.NewPublisher(cfg.RabbitMQ, log)
	if err != nil {
		log.Fatal("Failed to connect to RabbitMQ", map[string]interface{}{
			"error": err.Error(),
		})
	}
	defer publisher.Close()

	// Initialize exchanges
	if err := messaging.InitializeExchanges(publisher); err != nil {
		log.Fatal("Failed to initialize exchanges", map[string]interface{}{
			"error": err.Error(),
		})
	}

	// Initialize matchmaking queue
	matchmakingQueue := queue.NewMatchmakingQueue(cacheClient, log)
	defer matchmakingQueue.Stop()

	// Initialize services
	matchmakerService := service.NewMatchmakerService(database, cacheClient, matchmakingQueue, publisher, log)

	// Initialize handlers
	matchmakerHandler := handler.NewMatchmakerHandler(matchmakerService, log)

	// Setup HTTP router
	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("/health", matchmakerHandler.Health)
	mux.HandleFunc("/api/v1/matchmaker/join", matchmakerHandler.JoinQueue)
	mux.HandleFunc("/api/v1/matchmaker/leave", matchmakerHandler.LeaveQueue)
	mux.HandleFunc("/api/v1/matchmaker/status", matchmakerHandler.GetQueueStatus)
	mux.HandleFunc("/api/v1/matchmaker/leaderboard", matchmakerHandler.GetLeaderboard)

	// Create HTTP server
	addr := "0.0.0.0:" + port
	server := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Info("Matchmaker Service listening", map[string]interface{}{
			"port": port,
		})
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Server failed to start", map[string]interface{}{
				"error": err.Error(),
			})
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down server...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", map[string]interface{}{
			"error": err.Error(),
		})
	}

	log.Info("Server stopped")
}
