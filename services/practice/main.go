package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"
	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/practice/internal/handler"
	"github.com/swarit-1/cipher-clash/services/practice/internal/repository"
	"github.com/swarit-1/cipher-clash/services/practice/internal/service"
)

func main() {
	// Load .env file from root directory or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load()

	// Determine port
	port := os.Getenv("PRACTICE_SERVICE_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8090"
	}

	// Initialize logger
	log := logger.New("practice-service")
	log.Info("Starting Practice Service...")

	// Load configuration
	cfg := config.LoadConfig()
	cfg.Server.Port = port

	// Initialize database
	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{
			"error": err.Error(),
		})
	}
	defer database.Close()

	// Initialize JWT manager
	jwtManager := auth.NewJWTManager(cfg.JWT)

	// Get puzzle engine URL
	puzzleEngineURL := os.Getenv("PUZZLE_ENGINE_URL")
	if puzzleEngineURL == "" {
		puzzleEngineURL = "http://localhost:8087"
	}

	// Initialize repositories
	practiceRepo := repository.NewPracticeRepository(database.DB)

	// Initialize services
	scoringService := service.NewScoringService()
	practiceService := service.NewPracticeService(practiceRepo, scoringService, puzzleEngineURL, log)

	// Initialize handlers
	practiceHandler := handler.NewPracticeHandler(practiceService, jwtManager, log)

	// Setup HTTP router
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", practiceHandler.Health)

	// Practice routes
	mux.HandleFunc("/api/v1/practice/generate", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			practiceHandler.GeneratePuzzle(w, r)
		} else {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/v1/practice/submit", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			practiceHandler.SubmitSolution(w, r)
		} else {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/v1/practice/history", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			practiceHandler.GetHistory(w, r)
		} else {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/v1/practice/leaderboard/", practiceHandler.GetPersonalBests)

	// CORS middleware
	corsMiddleware := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusOK)
				return
			}

			next.ServeHTTP(w, r)
		})
	}

	// Create HTTP server
	addr := "0.0.0.0:" + port
	server := &http.Server{
		Addr:         addr,
		Handler:      corsMiddleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Info("Practice Service listening", map[string]interface{}{
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

	log.Info("Shutting down Practice Service...")

	// Graceful shutdown with 30 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", map[string]interface{}{
			"error": err.Error(),
		})
	}

	log.Info("Practice Service stopped")
}
