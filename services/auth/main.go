package main

import (
	"log"
	"net/http"
)

func main() {
	log.Println("Auth Service listening on :8083")
	// Placeholder for gRPC server or HTTP handlers
	if err := http.ListenAndServe(":8083", nil); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
