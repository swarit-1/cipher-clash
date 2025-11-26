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
	"github.com/swarit-1/cipher-clash/services/social/internal/handler"
	"github.com/swarit-1/cipher-clash/services/social/internal/repository"
	"github.com/swarit-1/cipher-clash/services/social/internal/service"
)

const (
	ServiceName     = "social-service"
	DefaultPort     = "8092"
	ShutdownTimeout = 15 * time.Second
)

func main() {
	log := logger.NewLogger(ServiceName)
	log.LogInfo("Starting Social Service...")

	cfg := config.LoadConfig()

	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{"error": err})
	}
	defer database.Close()

	log.LogInfo("Connected to database successfully")

	// Initialize repositories
	friendsRepo := repository.NewFriendsRepository(database.DB)
	invitesRepo := repository.NewInvitesRepository(database.DB)
	spectatorRepo := repository.NewSpectatorRepository(database.DB)

	// Initialize service
	socialService := service.NewSocialService(friendsRepo, invitesRepo, spectatorRepo, log)

	// Initialize handler
	socialHandler := handler.NewSocialHandler(socialService, log)

	// Setup router
	router := setupRouter(socialHandler)

	// Setup CORS
	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: true,
	}).Handler(router)

	port := os.Getenv("SOCIAL_SERVICE_PORT")
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
		log.LogInfo("Social Service listening on port " + port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server", map[string]interface{}{"error": err})
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down Social Service...")

	ctx, cancel := context.WithTimeout(context.Background(), ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError("Server forced to shutdown", "error", err)
	}

	log.LogInfo("Social Service stopped")
}

func setupRouter(h *handler.SocialHandler) *mux.Router {
	r := mux.NewRouter()
	api := r.PathPrefix("/api/v1").Subrouter()

	// Friends
	api.HandleFunc("/friends/{user_id}", h.GetFriends).Methods("GET")
	api.HandleFunc("/friends/request", h.SendFriendRequest).Methods("POST")
	api.HandleFunc("/friends/accept", h.AcceptFriendRequest).Methods("POST")
	api.HandleFunc("/friends/reject", h.RejectFriendRequest).Methods("POST")
	api.HandleFunc("/friends/remove", h.RemoveFriend).Methods("DELETE")
	api.HandleFunc("/friends/pending/{user_id}", h.GetPendingRequests).Methods("GET")

	// Match invites
	api.HandleFunc("/invites/send", h.SendMatchInvite).Methods("POST")
	api.HandleFunc("/invites/accept", h.AcceptMatchInvite).Methods("POST")
	api.HandleFunc("/invites/reject", h.RejectMatchInvite).Methods("POST")
	api.HandleFunc("/invites/{user_id}", h.GetMatchInvites).Methods("GET")

	// Spectator
	api.HandleFunc("/spectator/join", h.JoinAsSpectator).Methods("POST")
	api.HandleFunc("/spectator/leave", h.LeaveSpectatorMode).Methods("POST")
	api.HandleFunc("/spectator/match/{match_id}", h.GetSpectators).Methods("GET")

	// Health
	r.HandleFunc("/health", healthCheck).Methods("GET")

	return r
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy","service":"social-service"}`))
}
