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
	"github.com/swarit-1/cipher-clash/services/mastery/internal/handler"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/repository"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/service"
)

const (
	ServiceName     = "mastery-service"
	DefaultPort     = "8091"
	ShutdownTimeout = 15 * time.Second
)

func main() {
	log := logger.NewLogger(ServiceName)
	log.LogInfo("Starting Mastery Service...")

	cfg := config.LoadConfig()

	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{"error": err})
	}
	defer database.Close()

	log.LogInfo("Connected to database successfully")

	// Initialize repositories
	masteryNodesRepo := repository.NewMasteryNodesRepository(database.DB)
	userMasteryRepo := repository.NewUserMasteryRepository(database.DB)
	cipherPointsRepo := repository.NewCipherMasteryPointsRepository(database.DB)

	// Initialize service
	masteryService := service.NewMasteryService(masteryNodesRepo, userMasteryRepo, cipherPointsRepo, log)

	// Initialize handler
	masteryHandler := handler.NewMasteryHandler(masteryService, log)

	// Setup router
	router := setupRouter(masteryHandler)

	// Setup CORS
	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: true,
	}).Handler(router)

	port := os.Getenv("MASTERY_SERVICE_PORT")
	if port == "" {
		port = DefaultPort
	}

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      corsHandler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.LogInfo("Mastery Service listening on port " + port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server", map[string]interface{}{"error": err})
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down Mastery Service...")

	ctx, cancel := context.WithTimeout(context.Background(), ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError("Server forced to shutdown", "error", err)
	}

	log.LogInfo("Mastery Service stopped")
}

func setupRouter(h *handler.MasteryHandler) *mux.Router {
	r := mux.NewRouter()
	api := r.PathPrefix("/api/v1").Subrouter()

	// Mastery tree
	api.HandleFunc("/mastery/tree/{cipher_type}", h.GetMasteryTree).Methods("GET")
	api.HandleFunc("/mastery/nodes", h.GetAllNodes).Methods("GET")
	api.HandleFunc("/mastery/node/{node_id}", h.GetNode).Methods("GET")

	// User mastery
	api.HandleFunc("/mastery/user/{user_id}", h.GetUserMastery).Methods("GET")
	api.HandleFunc("/mastery/user/{user_id}/cipher/{cipher_type}", h.GetUserCipherMastery).Methods("GET")
	api.HandleFunc("/mastery/unlock", h.UnlockNode).Methods("POST")

	// Mastery points
	api.HandleFunc("/mastery/points/{user_id}", h.GetUserMasteryPoints).Methods("GET")
	api.HandleFunc("/mastery/points/award", h.AwardMasteryPoints).Methods("POST")

	// Leaderboard
	api.HandleFunc("/mastery/leaderboard/{cipher_type}", h.GetMasteryLeaderboard).Methods("GET")

	// Health
	r.HandleFunc("/health", healthCheck).Methods("GET")

	return r
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy","service":"mastery-service"}`))
}
