package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/repository"
	"github.com/swarit-1/cipher-clash/services/auth/internal/handler"
	"github.com/swarit-1/cipher-clash/services/auth/internal/middleware"
	"github.com/swarit-1/cipher-clash/services/auth/internal/service"
)

func main() {
	// Initialize logger
	log := logger.New("auth-service")
	log.Info("Starting Auth Service...")

	// Load configuration
	cfg := config.LoadConfig()

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

	// Initialize JWT manager
	jwtManager := auth.NewJWTManager(cfg.JWT)

	// Initialize repositories
	userRepo := repository.NewUserRepository(database)

	// Initialize services
	authService := service.NewAuthService(userRepo, jwtManager, cacheClient, log)

	// Initialize handlers
	authHandler := handler.NewAuthHandler(authService, log)

	// Initialize middleware
	authMiddleware := middleware.NewAuthMiddleware(jwtManager, log)

	// Setup HTTP router
	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("/health", authMiddleware.CORS(authMiddleware.Logging(authHandler.Health)))
	mux.HandleFunc("/api/v1/auth/register", authMiddleware.CORS(authMiddleware.Logging(authHandler.Register)))
	mux.HandleFunc("/api/v1/auth/login", authMiddleware.CORS(authMiddleware.Logging(authHandler.Login)))
	mux.HandleFunc("/api/v1/auth/refresh", authMiddleware.CORS(authMiddleware.Logging(authHandler.RefreshToken)))

	// Protected routes
	mux.HandleFunc("/api/v1/auth/profile", authMiddleware.CORS(authMiddleware.Logging(authMiddleware.RequireAuth(authHandler.GetProfile))))
	mux.HandleFunc("/api/v1/auth/profile/update", authMiddleware.CORS(authMiddleware.Logging(authMiddleware.RequireAuth(authHandler.UpdateProfile))))
	mux.HandleFunc("/api/v1/auth/logout", authMiddleware.CORS(authMiddleware.Logging(authMiddleware.RequireAuth(authHandler.Logout))))

	// Create HTTP server
	addr := fmt.Sprintf("%s:%s", cfg.Server.Host, cfg.Server.Port)
	server := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Info("Auth Service listening", map[string]interface{}{
			"address": addr,
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

	// Graceful shutdown with 30 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", map[string]interface{}{
			"error": err.Error(),
		})
	}

	log.Info("Server stopped")
}
