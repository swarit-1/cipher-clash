package main

import (
	"log"
	"net/http"
)

func main() {
	log.Println("Matchmaker Service listening on :8081")
	// Placeholder for gRPC server or HTTP handlers
	if err := http.ListenAndServe(":8081", nil); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
