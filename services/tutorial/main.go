package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

const (
	ServiceName    = "tutorial-service"
	DefaultPort    = "8089"
	ShutdownTimeout = 15 * time.Second
)

func main() {
	// Initialize logger
	log := logger.NewLogger(ServiceName)
	log.LogInfo("Starting Tutorial Service...")

	// Load configuration
	cfg := config.LoadConfig()
	port := os.Getenv("TUTORIAL_SERVICE_PORT")
	if port == "" {
		port = DefaultPort
	}

	// Initialize database connection
	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{"error": err})
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

	// Setup router
	router := setupRouter(tutorialHandler)

	// Configure CORS
	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	}).Handler(router)

	// Create HTTP server
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      corsHandler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.LogInfo(fmt.Sprintf("Tutorial Service listening on port %s", port))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server", map[string]interface{}{"error": err})
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down Tutorial Service...")

	ctx, cancel := context.WithTimeout(context.Background(), ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError("Server forced to shutdown", "error", err)
	}

	log.LogInfo("Tutorial Service stopped")
}

func setupRouter(h *handler.TutorialHandler) *mux.Router {
	r := mux.NewRouter()

	// API version prefix
	api := r.PathPrefix("/api/v1").Subrouter()

	// Tutorial routes
	api.HandleFunc("/tutorial/steps", h.GetTutorialSteps).Methods("GET")
	api.HandleFunc("/tutorial/progress", h.GetUserProgress).Methods("GET")
	api.HandleFunc("/tutorial/progress", h.UpdateProgress).Methods("POST")
	api.HandleFunc("/tutorial/complete", h.CompleteStep).Methods("POST")
	api.HandleFunc("/tutorial/skip", h.SkipTutorial).Methods("POST")

	// Visualizer routes
	api.HandleFunc("/tutorial/visualize/{cipher_type}", h.GetCipherVisualization).Methods("POST")
	api.HandleFunc("/tutorial/visualizers", h.GetAvailableVisualizers).Methods("GET")

	// Bot battle route (first match)
	api.HandleFunc("/tutorial/bot-battle/start", h.StartBotBattle).Methods("POST")
	api.HandleFunc("/tutorial/bot-battle/submit", h.SubmitBotBattleSolution).Methods("POST")

	// Health check
	r.HandleFunc("/health", healthCheck).Methods("GET")

	return r
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"service": ServiceName,
		"time":    time.Now().Format(time.RFC3339),
	})
}
