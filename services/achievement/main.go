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
	"github.com/swarit-1/cipher-clash/services/achievement/internal/handler"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/middleware"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/repository"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/service"
)

func main() {
	// Load .env file from root directory (../../.env) or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load() // Fallback to current directory

	// Determine the port with proper priority:
	// 1. ACHIEVEMENT_SERVICE_PORT (service-specific from .env) - highest priority
	// 2. PORT (generic override) - for Docker/special cases
	// 3. Default 8083 - sensible fallback
	port := os.Getenv("ACHIEVEMENT_SERVICE_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8083"
	}

	// Initialize logger
	log := logger.New("achievement-service")
	log.Info("Starting Achievement Service...")

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

	// Initialize JWT manager
	jwtManager := auth.NewJWTManager(cfg.JWT)

	// Initialize repositories
	achievementRepo := repository.NewAchievementRepository(database, log)
	userAchievementRepo := repository.NewUserAchievementRepository(database, log)

	// Initialize services
	achievementService := service.NewAchievementService(
		achievementRepo,
		userAchievementRepo,
		cacheClient,
		log,
	)

	// Initialize handlers
	achievementHandler := handler.NewAchievementHandler(achievementService, log)

	// Initialize middleware
	authMiddleware := middleware.NewAuthMiddleware(jwtManager, log)

	// Setup HTTP router
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", authMiddleware.CORS(authMiddleware.Logging(achievementHandler.Health)))

	// Public routes (read-only)
	mux.HandleFunc("/api/v1/achievements", authMiddleware.CORS(authMiddleware.Logging(achievementHandler.ListAchievements)))
	mux.HandleFunc("/api/v1/achievements/", authMiddleware.CORS(authMiddleware.Logging(achievementHandler.GetAchievement)))

	// Protected routes (user-specific)
	mux.HandleFunc("/api/v1/user/achievements", authMiddleware.CORS(authMiddleware.Logging(authMiddleware.RequireAuth(achievementHandler.GetUserAchievements))))
	mux.HandleFunc("/api/v1/user/achievements/progress", authMiddleware.CORS(authMiddleware.Logging(authMiddleware.RequireAuth(achievementHandler.GetUserProgress))))
	mux.HandleFunc("/api/v1/user/achievements/stats", authMiddleware.CORS(authMiddleware.Logging(authMiddleware.RequireAuth(achievementHandler.GetUserStats))))

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
		log.Info("Achievement Service listening", map[string]interface{}{
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

	log.Info("Shutting down Achievement Service...")

	// Graceful shutdown with 30 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", map[string]interface{}{
			"error": err.Error(),
		})
	}

	log.Info("Achievement Service stopped")
}
