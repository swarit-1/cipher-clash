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
	"github.com/swarit-1/cipher-clash/pkg/httpx"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/game/internal/bot"
	"github.com/swarit-1/cipher-clash/services/game/internal/clients"
	"github.com/swarit-1/cipher-clash/services/game/internal/room"
	"github.com/swarit-1/cipher-clash/services/game/internal/server"
	"github.com/swarit-1/cipher-clash/services/game/internal/store"
)

func main() {
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load()

	port := os.Getenv("GAME_SERVICE_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8088"
	}

	log := logger.New("game")
	log.Info("Starting Game Service...")

	cfg := config.LoadConfig()
	cfg.Server.Port = port

	internalToken := os.Getenv("INTERNAL_API_TOKEN")
	if internalToken == "" {
		log.Warn("INTERNAL_API_TOKEN not set; puzzle/rating calls will be rejected", nil)
	}
	puzzleURL := envOr("PUZZLE_ENGINE_URL", "http://localhost:8087")
	matchmakerURL := envOr("MATCHMAKER_URL", "http://localhost:8086")

	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{"error": err.Error()})
	}
	defer database.Close()

	publisher, err := messaging.NewPublisher(cfg.RabbitMQ, log)
	if err != nil {
		log.Fatal("Failed to connect to RabbitMQ", map[string]interface{}{"error": err.Error()})
	}
	defer publisher.Close()

	if err := messaging.InitializeExchanges(publisher); err != nil {
		log.Fatal("Failed to initialize exchanges", map[string]interface{}{"error": err.Error()})
	}

	st := store.New(database, log)
	puzzleClient := clients.NewPuzzleClient(puzzleURL, internalToken)
	ratingsClient := clients.NewRatingsClient(matchmakerURL, internalToken)
	manager := server.NewManager(st, puzzleClient, ratingsClient, publisher, log)
	manager.SetBotFactory(func(r *room.Room, info room.PlayerInfo, opponentELO int, puzzles []room.Puzzle) room.Participant {
		return bot.New(r, info, opponentELO, puzzles, log)
	})

	// Consume match.created from the matchmaker.
	subscriber, err := messaging.NewSubscriber(cfg.RabbitMQ, log)
	if err != nil {
		log.Fatal("Failed to create subscriber", map[string]interface{}{"error": err.Error()})
	}
	defer subscriber.Close()

	const queueName = "game.match_created"
	if _, err := subscriber.DeclareQueue(queueName); err != nil {
		log.Fatal("Failed to declare queue", map[string]interface{}{"error": err.Error()})
	}
	if err := subscriber.BindQueue(queueName, messaging.ExchangeMatches, "match.created"); err != nil {
		log.Fatal("Failed to bind queue", map[string]interface{}{"error": err.Error()})
	}
	if err := subscriber.Subscribe(queueName, manager.HandleMatchCreated); err != nil {
		log.Fatal("Failed to subscribe", map[string]interface{}{"error": err.Error()})
	}

	jwtManager := auth.NewJWTManager(cfg.JWT)
	wsHandler := server.NewWSHandler(manager, jwtManager, log)
	httpHandler := server.NewHTTPHandler(manager, st, jwtManager, log)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", httpHandler.Health)
	mux.HandleFunc("/ws", wsHandler.ServeWS)
	mux.HandleFunc("/api/v1/match/bot", httpHandler.RequireAuth(httpHandler.CreateBotMatch))
	mux.HandleFunc("/api/v1/matches/history", httpHandler.RequireAuth(httpHandler.GetHistory))
	mux.HandleFunc("/api/v1/matches/replay", httpHandler.GetReplay)
	mux.HandleFunc("/api/v1/matches/live", httpHandler.GetLiveMatches)

	addr := "0.0.0.0:" + port
	httpServer := &http.Server{
		Addr:    addr,
		Handler: httpx.CORS(mux),
		// No global ReadTimeout/WriteTimeout: they would kill long-lived
		// WebSocket connections. Deadlines are managed per-socket.
		IdleTimeout: 120 * time.Second,
	}

	go func() {
		log.Info("Game Service listening", map[string]interface{}{"port": port})
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Server failed to start", map[string]interface{}{"error": err.Error()})
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", map[string]interface{}{"error": err.Error()})
	}
	log.Info("Server stopped")
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
