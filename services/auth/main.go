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
	// Load .env file from root directory (../../.env) or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load() // Fallback to current directory

	// Determine the port with proper priority:
	// 1. AUTH_SERVICE_PORT (service-specific from .env) - highest priority
	// 2. PORT (generic override) - for Docker/special cases
	// 3. Default 8085 - sensible fallback
	port := os.Getenv("AUTH_SERVICE_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8085"
	}

	// Initialize logger
	log := logger.New("auth-service")
	log.Info("Starting Auth Service...")

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

	// Initialize cache (optional - warn but continue if Redis unavailable)
	cacheClient, err := cache.New(cfg.Redis, log)
	if err != nil {
		log.Warn("Redis unavailable - continuing without cache", map[string]interface{}{
			"error": err.Error(),
		})
		cacheClient = nil // Service will handle nil cache gracefully
	} else {
		defer cacheClient.Close()
	}

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
		log.Info("Auth Service listening", map[string]interface{}{
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
