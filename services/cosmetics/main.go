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
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/handler"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/repository"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/service"
)

const (
	ServiceName     = "cosmetics-service"
	DefaultPort     = "8093"
	ShutdownTimeout = 15 * time.Second
)

func main() {
	log := logger.NewLogger(ServiceName)
	log.LogInfo("Starting Cosmetics Service...")

	cfg := config.LoadConfig()
	database, err := db.New(cfg.Database, log)
	if err != nil {
		log.Fatal("Failed to connect to database", map[string]interface{}{"error": err})
	}
	defer database.Close()

	log.LogInfo("Connected to database successfully")

	catalogRepo := repository.NewCatalogRepository(database.DB)
	inventoryRepo := repository.NewInventoryRepository(database.DB)
	loadoutRepo := repository.NewLoadoutRepository(database.DB)

	cosmeticsService := service.NewCosmeticsService(catalogRepo, inventoryRepo, loadoutRepo, log)
	cosmeticsHandler := handler.NewCosmeticsHandler(cosmeticsService, log)

	router := setupRouter(cosmeticsHandler)
	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: true,
	}).Handler(router)

	port := os.Getenv("COSMETICS_SERVICE_PORT")
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
		log.LogInfo("Cosmetics Service listening on port " + port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server", map[string]interface{}{"error": err})
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.LogInfo("Shutting down Cosmetics Service...")
	ctx, cancel := context.WithTimeout(context.Background(), ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.LogError("Server forced to shutdown", "error", err)
	}

	log.LogInfo("Cosmetics Service stopped")
}

func setupRouter(h *handler.CosmeticsHandler) *mux.Router {
	r := mux.NewRouter()
	api := r.PathPrefix("/api/v1").Subrouter()

	// Catalog
	api.HandleFunc("/cosmetics/catalog", h.GetCatalog).Methods("GET")
	api.HandleFunc("/cosmetics/catalog/{id}", h.GetCosmeticItem).Methods("GET")

	// Inventory
	api.HandleFunc("/cosmetics/inventory/{user_id}", h.GetInventory).Methods("GET")
	api.HandleFunc("/cosmetics/purchase", h.PurchaseCosmetic).Methods("POST")

	// Loadout
	api.HandleFunc("/cosmetics/loadout/{user_id}", h.GetLoadout).Methods("GET")
	api.HandleFunc("/cosmetics/loadout/equip", h.EquipCosmetic).Methods("POST")
	api.HandleFunc("/cosmetics/loadout/unequip", h.UnequipCosmetic).Methods("POST")

	r.HandleFunc("/health", healthCheck).Methods("GET")
	return r
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy","service":"cosmetics-service"}`))
}
