// Package httpx provides shared HTTP middleware for all services.
package httpx

import (
	"net/http"
	"os"
	"strings"
)

// CORS returns middleware that applies the ALLOWED_ORIGINS policy.
// ALLOWED_ORIGINS is a comma-separated list of origins; unset or "*" allows
// any origin (development default).
func CORS(next http.Handler) http.Handler {
	allowed := parseAllowedOrigins(os.Getenv("ALLOWED_ORIGINS"))

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" {
			if allowed == nil {
				w.Header().Set("Access-Control-Allow-Origin", "*")
			} else if _, ok := allowed[origin]; ok {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Vary", "Origin")
			}
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Internal-Token")
			w.Header().Set("Access-Control-Max-Age", "600")
		}

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// AllowedOrigin reports whether a WebSocket upgrade Origin is permitted.
func AllowedOrigin(origin string) bool {
	allowed := parseAllowedOrigins(os.Getenv("ALLOWED_ORIGINS"))
	if allowed == nil || origin == "" {
		return true
	}
	_, ok := allowed[origin]
	return ok
}

func parseAllowedOrigins(raw string) map[string]struct{} {
	raw = strings.TrimSpace(raw)
	if raw == "" || raw == "*" {
		return nil // allow all
	}
	set := make(map[string]struct{})
	for _, o := range strings.Split(raw, ",") {
		o = strings.TrimSpace(strings.TrimSuffix(o, "/"))
		if o != "" {
			set[o] = struct{}{}
		}
	}
	return set
}
