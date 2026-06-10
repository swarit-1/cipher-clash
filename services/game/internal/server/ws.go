package server

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/httpx"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/game/internal/room"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 25 * time.Second
	maxMessageSize = 8 * 1024
	sendBuffer     = 64
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return httpx.AllowedOrigin(r.Header.Get("Origin"))
	},
}

// wsParticipant adapts a WebSocket connection to room.Participant.
type wsParticipant struct {
	conn   *websocket.Conn
	send   chan room.Envelope
	closed chan struct{}
	once   sync.Once
	log    *logger.Logger
}

// Send implements room.Participant: non-blocking, drops on full buffer.
func (w *wsParticipant) Send(env room.Envelope) {
	select {
	case w.send <- env:
	case <-w.closed:
	default:
		w.log.Warn("WS send buffer full, dropping message", map[string]interface{}{"type": env.Type})
	}
}

// Close implements room.Participant.
func (w *wsParticipant) Close() {
	w.once.Do(func() {
		close(w.closed)
		w.conn.Close()
	})
}

// WSHandler upgrades /ws?match_id=&token=[&spectate=true] connections,
// authenticates the JWT, and binds the socket to its room.
type WSHandler struct {
	manager    *Manager
	jwtManager *auth.JWTManager
	log        *logger.Logger
}

// NewWSHandler creates the WebSocket handler.
func NewWSHandler(manager *Manager, jwtManager *auth.JWTManager, log *logger.Logger) *WSHandler {
	return &WSHandler{manager: manager, jwtManager: jwtManager, log: log}
}

// ServeWS handles the upgrade.
func (h *WSHandler) ServeWS(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	matchID := query.Get("match_id")
	token := query.Get("token")
	spectate := query.Get("spectate") == "true"

	if matchID == "" || token == "" {
		http.Error(w, "match_id and token are required", http.StatusBadRequest)
		return
	}

	// Browsers cannot set headers on WebSocket upgrades, so the access
	// token rides in the query string. Validate before upgrading.
	claims, err := h.jwtManager.ValidateToken(token, auth.AccessToken)
	if err != nil {
		http.Error(w, "invalid or expired token", http.StatusUnauthorized)
		return
	}

	gameRoom, ok := h.manager.Get(matchID)
	if !ok {
		http.Error(w, "match not found or already finished", http.StatusNotFound)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.log.Error("WS upgrade failed", map[string]interface{}{"error": err.Error()})
		return
	}

	p := &wsParticipant{
		conn:   conn,
		send:   make(chan room.Envelope, sendBuffer),
		closed: make(chan struct{}),
		log:    h.log,
	}

	if err := gameRoom.Join(claims.UserID, p, spectate); err != nil {
		p.Send(room.NewEnvelope(room.TypeError, room.ErrorPayload{
			Code: "JOIN_REJECTED", Message: err.Error(),
		}))
		// Flush the error before closing.
		go func() {
			h.writePump(p)
		}()
		time.AfterFunc(time.Second, p.Close)
		return
	}

	h.log.Info("WS connected", map[string]interface{}{
		"match_id": matchID, "user_id": claims.UserID, "spectate": spectate,
	})

	go h.writePump(p)
	go h.readPump(p, gameRoom, claims.UserID)
}

func (h *WSHandler) readPump(p *wsParticipant, gameRoom *room.Room, userID string) {
	defer func() {
		gameRoom.Leave(userID, p)
		p.Close()
	}()

	p.conn.SetReadLimit(maxMessageSize)
	p.conn.SetReadDeadline(time.Now().Add(pongWait))
	p.conn.SetPongHandler(func(string) error {
		p.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, raw, err := p.conn.ReadMessage()
		if err != nil {
			return
		}
		// App-level PING also refreshes the read deadline (browser
		// WebSocket APIs cannot send protocol-level pings).
		p.conn.SetReadDeadline(time.Now().Add(pongWait))

		var env room.Envelope
		if err := json.Unmarshal(raw, &env); err != nil {
			p.Send(room.NewEnvelope(room.TypeError, room.ErrorPayload{
				Code: "BAD_ENVELOPE", Message: "Messages must be {type, payload} JSON",
			}))
			continue
		}
		gameRoom.HandleMessage(userID, env)
	}
}

func (h *WSHandler) writePump(p *wsParticipant) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		p.Close()
	}()

	for {
		select {
		case env := <-p.send:
			p.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := p.conn.WriteJSON(env); err != nil {
				return
			}
		case <-ticker.C:
			p.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := p.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		case <-p.closed:
			p.conn.SetWriteDeadline(time.Now().Add(writeWait))
			p.conn.WriteMessage(websocket.CloseMessage,
				websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
			return
		}
	}
}
