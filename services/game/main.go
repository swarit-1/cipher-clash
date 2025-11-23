package main

import (
	"log"
	"net/http"

	game "github.com/swarit-1/cipher-clash/services/game/internal"
)

func main() {
	hub := game.NewHub()
	go hub.Run()

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		game.ServeWs(hub, w, r)
	})

	log.Println("Game Service listening on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
