package main

import (
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	game "github.com/swarit-1/cipher-clash/services/game/internal"
)

func main() {
	// Load .env file from root directory (../../.env) or current directory
	_ = godotenv.Load("../../.env")
	_ = godotenv.Load() // Fallback to current directory

	// Determine the port with proper priority:
	// 1. GAME_SERVICE_PORT (service-specific from .env) - highest priority
	// 2. PORT (generic override) - for Docker/special cases
	// 3. Default 8088 - sensible fallback
	port := os.Getenv("GAME_SERVICE_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8088"
	}

	hub := game.NewHub()
	go hub.Run()

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		game.ServeWs(hub, w, r)
	})

	addr := "0.0.0.0:" + port
	log.Printf("Game Service listening on port %s\n", port)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
