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
	"github.com/swarit-1/cipher-clash/services/tutorial/internal/handler"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal/repository"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal/service"
)

func main() {
	// Load .env file from root directory (../../.env) or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load() // Fallback to current directory

	// Determine the port with proper priority:
	// 1. TUTORIAL_SERVICE_PORT (service-specific from .env) - highest priority
	// 2. PORT (generic override) - for Docker/special cases
	// 3. Default 8089 - sensible fallback
	port := os.Getenv("TUTORIAL_SERVICE_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8089"
	}

	// Initialize logger
	log := logger.New("tutorial-service")
	log.Info("Starting Tutorial Service...")

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

	// Initialize JWT manager
	jwtManager := auth.NewJWTManager(cfg.JWT)

	// Initialize repositories
	tutorialRepo := repository.NewTutorialRepository(database.DB)
	progressRepo := repository.NewProgressRepository(database.DB)

	// Initialize services
	tutorialService := service.NewTutorialService(tutorialRepo, progressRepo, log)
	visualizerService := service.NewVisualizerService(log)

	// Initialize handlers
	tutorialHandler := handler.NewTutorialHandler(tutorialService, visualizerService, jwtManager, log)

	// Setup HTTP router
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", tutorialHandler.Health)

	// Tutorial routes
	mux.HandleFunc("/api/v1/tutorial/steps", tutorialHandler.GetTutorialSteps)
	mux.HandleFunc("/api/v1/tutorial/progress", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			tutorialHandler.GetUserProgress(w, r)
		} else if r.Method == http.MethodPost {
			tutorialHandler.UpdateProgress(w, r)
		} else {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})
	mux.HandleFunc("/api/v1/tutorial/complete", tutorialHandler.CompleteStep)
	mux.HandleFunc("/api/v1/tutorial/skip", tutorialHandler.SkipTutorial)

	// Visualizer routes
	mux.HandleFunc("/api/v1/tutorial/visualize/", tutorialHandler.GetCipherVisualization)
	mux.HandleFunc("/api/v1/tutorial/visualizers", tutorialHandler.GetAvailableVisualizers)

	// Bot battle routes
	mux.HandleFunc("/api/v1/tutorial/bot-battle/start", tutorialHandler.StartBotBattle)
	mux.HandleFunc("/api/v1/tutorial/bot-battle/submit", tutorialHandler.SubmitBotBattleSolution)

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
		log.Info("Tutorial Service listening", map[string]interface{}{
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

	log.Info("Shutting down Tutorial Service...")

	// Graceful shutdown with 30 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", map[string]interface{}{
			"error": err.Error(),
		})
	}

	log.Info("Tutorial Service stopped")
}
