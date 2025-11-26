package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/missions/internal/handler"
	"github.com/swarit-1/cipher-clash/services/missions/internal/repository"
	"github.com/swarit-1/cipher-clash/services/missions/internal/service"
)

const (
	ServiceName     = "missions-service"
	DefaultPort     = "8090"
	ShutdownTimeout = 15 * time.Second
)

func main() {
	// Initialize logger
	log := logger.NewLogger(ServiceName)
	log.LogInfo("Starting Missions Service...")

	// Load configuration
	cfg := config.LoadConfig()

	// Initialize database
	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{"error": err})
	}
	defer database.Close()

	log.LogInfo("Connected to database successfully")

	// Initialize repositories
	missionsRepo := repository.NewMissionsRepository(database.DB)
	userMissionsRepo := repository.NewUserMissionsRepository(database.DB)

	// Initialize service
	missionsService := service.NewMissionsService(missionsRepo, userMissionsRepo, log)

	// Initialize handler
	missionsHandler := handler.NewMissionsHandler(missionsService, log)

	// Setup router
	router := setupRouter(missionsHandler)

	// Setup CORS
	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: true,
	}).Handler(router)

	// Get port from environment or use default
	port := os.Getenv("MISSIONS_SERVICE_PORT")
	if port == "" {
		port = DefaultPort
	}

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
		log.LogInfo("Missions Service listening on port " + port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server", map[string]interface{}{"error": err})
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down Missions Service...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError("Server forced to shutdown", "error", err)
	}

	log.LogInfo("Missions Service stopped")
}

func setupRouter(h *handler.MissionsHandler) *mux.Router {
	r := mux.NewRouter()

	// API v1 routes
	api := r.PathPrefix("/api/v1").Subrouter()

	// Mission templates
	api.HandleFunc("/missions/templates", h.GetMissionTemplates).Methods("GET")
	api.HandleFunc("/missions/templates/{id}", h.GetMissionTemplate).Methods("GET")

	// User missions
	api.HandleFunc("/missions/user/{user_id}", h.GetUserMissions).Methods("GET")
	api.HandleFunc("/missions/user/{user_id}/active", h.GetActiveMissions).Methods("GET")
	api.HandleFunc("/missions/assign", h.AssignDailyMissions).Methods("POST")
	api.HandleFunc("/missions/progress", h.UpdateMissionProgress).Methods("POST")
	api.HandleFunc("/missions/complete", h.CompleteMission).Methods("POST")
	api.HandleFunc("/missions/claim", h.ClaimMissionReward).Methods("POST")
	api.HandleFunc("/missions/refresh", h.RefreshMissions).Methods("POST")

	// Stats
	api.HandleFunc("/missions/stats/{user_id}", h.GetMissionStats).Methods("GET")

	// Health check
	r.HandleFunc("/health", healthCheck).Methods("GET")

	return r
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy","service":"missions-service"}`))
}
