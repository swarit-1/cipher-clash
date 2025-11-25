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
	"github.com/swarit-1/cipher-clash/services/puzzle_engine/internal/handler"
	"github.com/swarit-1/cipher-clash/services/puzzle_engine/internal/service"
)

func main() {
	// Load .env file from root directory (../../.env) or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load() // Fallback to current directory

	// Get port from environment or use default
	// Determine which port to use
	port := os.Getenv("PORT") // Can be used for overrides
	if port == "" {
		port = os.Getenv("PUZZLE_ENGINE_PORT") // Service-specific port from .env
	}
	if port == "" {
		port = "8087" // Final fallback
	}

	// Initialize logger
	log := logger.New("puzzle-engine")
	log.Info("Starting Puzzle Engine Service...")

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

	// Initialize services
	puzzleService := service.NewPuzzleService(database, cacheClient, log)

	// Initialize handlers
	puzzleHandler := handler.NewPuzzleHandler(puzzleService, log)

	// Setup HTTP router
	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("/health", puzzleHandler.Health)
	mux.HandleFunc("/api/v1/puzzle/generate", puzzleHandler.GeneratePuzzle)
	mux.HandleFunc("/api/v1/puzzle/validate", puzzleHandler.ValidateSolution)
	mux.HandleFunc("/api/v1/puzzle/get", puzzleHandler.GetPuzzle)

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
		log.Info("Puzzle Engine Service listening", map[string]interface{}{
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
