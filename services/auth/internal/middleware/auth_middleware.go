package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

// AuthMiddleware validates JWT tokens
type AuthMiddleware struct {
	jwtManager *auth.JWTManager
	log        *logger.Logger
}

// NewAuthMiddleware creates a new auth middleware
func NewAuthMiddleware(jwtManager *auth.JWTManager, log *logger.Logger) *AuthMiddleware {
	return &AuthMiddleware{
		jwtManager: jwtManager,
		log:        log,
	}
}

// RequireAuth validates JWT and adds user context
func (m *AuthMiddleware) RequireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Extract token from Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			m.respondError(w, errors.NewUnauthorizedError("Missing authorization header"))
			return
		}

		// Check Bearer prefix
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			m.respondError(w, errors.NewUnauthorizedError("Invalid authorization header format"))
			return
		}

		token := parts[1]

		// Validate token
		claims, err := m.jwtManager.ValidateToken(token, auth.AccessToken)
		if err != nil {
			m.respondError(w, errors.NewUnauthorizedError("Invalid or expired token"))
			return
		}

		// Add user info to context
		ctx := context.WithValue(r.Context(), "user_id", claims.UserID)
		ctx = context.WithValue(ctx, "username", claims.Username)

		// Call next handler
		next.ServeHTTP(w, r.WithContext(ctx))
	}
}

// CORS middleware
func (m *AuthMiddleware) CORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	}
}

// Logging middleware
func (m *AuthMiddleware) Logging(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m.log.Info("HTTP Request", map[string]interface{}{
			"method": r.Method,
			"path":   r.URL.Path,
			"remote": r.RemoteAddr,
		})
		next.ServeHTTP(w, r)
	}
}

func (m *AuthMiddleware) respondError(w http.ResponseWriter, err error) {
	appErr, ok := err.(*errors.AppError)
	if !ok {
		appErr = errors.NewInternalServerError(err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(appErr.HTTPStatus)
	w.Write([]byte(`{"error":{"code":"` + appErr.Code + `","message":"` + appErr.Message + `"}}`))
}
