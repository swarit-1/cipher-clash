package main

import (
	"log"
	"net/http"
)

func main() {
	log.Println("Puzzle Engine Service listening on :8082")
	// Placeholder for gRPC server or HTTP handlers
	if err := http.ListenAndServe(":8082", nil); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
