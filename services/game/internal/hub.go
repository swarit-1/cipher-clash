package game

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for MVP
	},
}

type Hub struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.Mutex
}

func NewHub() *Hub {
	return &Hub{
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()

			// MOCK: Send a random puzzle immediately upon connection
			go func(c *Client) {
				time.Sleep(500 * time.Millisecond) // Wait a bit

				puzzles := []map[string]interface{}{
					{
						"encrypted_text": "WKH TXLFN EURZQ IRA MXPSV RYHU WKH ODCB GRJ",
						"solution":       "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
						"cipher_type":    "CAESAR",
						"difficulty":     1,
					},
					{
						"encrypted_text": "LIPPS ASVPH",
						"solution":       "HELLO WORLD",
						"cipher_type":    "CAESAR",
						"difficulty":     1,
					},
					{
						"encrypted_text": "D OLWWOH ELW KDUGHU",
						"solution":       "A LITTLE BIT HARDER",
						"cipher_type":    "CAESAR",
						"difficulty":     2,
					},
					{
						"encrypted_text": "LXFOPVEFRNHR",
						"solution":       "CRYPTOGRAPHY",
						"cipher_type":    "VIGENERE",
						"difficulty":     3,
					},
				}

				// Simple random selection (using time as seed is not strictly necessary for this mock but good practice)
				randomIndex := rand.Intn(len(puzzles))
				selectedPuzzle := puzzles[randomIndex]

				mockPuzzle := map[string]interface{}{
					"type": "MATCH_STARTED",
					"payload": map[string]interface{}{
						"match_id":          "mock-match-123",
						"opponent_id":       "bot-1",
						"opponent_username": "NEMESIS_X",
						"puzzle":            selectedPuzzle,
					},
				}
				msg, _ := json.Marshal(mockPuzzle)
				c.send <- msg
			}(client)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()
		case message := <-h.broadcast:
			h.mu.Lock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.Unlock()
		}
	}
}

type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		// Echo back for now (or handle actions)
		// In a real game, we'd parse the action and update state
		c.hub.broadcast <- message
	}
}

func (c *Client) writePump() {
	defer func() {
		c.conn.Close()
	}()
	for message := range c.send {
		c.conn.WriteMessage(websocket.TextMessage, message)
	}
	c.conn.WriteMessage(websocket.CloseMessage, []byte{})
}

func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println(err)
		return
	}
	client := &Client{hub: hub, conn: conn, send: make(chan []byte, 256)}
	client.hub.register <- client

	go client.writePump()
	go client.readPump()
}
