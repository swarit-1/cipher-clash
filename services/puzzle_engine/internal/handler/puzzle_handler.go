package handler

import (
	"encoding/json"
	"net/http"

	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/puzzle_engine/internal/service"
)

// PuzzleHandler handles HTTP requests for puzzles
type PuzzleHandler struct {
	puzzleService *service.PuzzleService
	log           *logger.Logger
}

// NewPuzzleHandler creates a new puzzle handler
func NewPuzzleHandler(puzzleService *service.PuzzleService, log *logger.Logger) *PuzzleHandler {
	return &PuzzleHandler{
		puzzleService: puzzleService,
		log:           log,
	}
}

// GeneratePuzzle handles puzzle generation
func (h *PuzzleHandler) GeneratePuzzle(w http.ResponseWriter, r *http.Request) {
	var req service.GeneratePuzzleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	puzzle, err := h.puzzleService.GeneratePuzzle(r.Context(), &req)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, puzzle)
}

// ValidateSolution handles solution validation
func (h *PuzzleHandler) ValidateSolution(w http.ResponseWriter, r *http.Request) {
	var req service.ValidateSolutionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	result, err := h.puzzleService.ValidateSolution(r.Context(), &req)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, result)
}

// GetPuzzle retrieves a puzzle by ID
func (h *PuzzleHandler) GetPuzzle(w http.ResponseWriter, r *http.Request) {
	puzzleID := r.URL.Query().Get("id")
	if puzzleID == "" {
		h.respondError(w, errors.NewInvalidInputError("Puzzle ID is required"))
		return
	}

	puzzle, err := h.puzzleService.GetPuzzle(r.Context(), puzzleID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, puzzle)
}

// Health check endpoint
func (h *PuzzleHandler) Health(w http.ResponseWriter, r *http.Request) {
	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "healthy",
		"service": "puzzle-engine",
	})
}

// Helper methods

func (h *PuzzleHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		h.log.Error("Failed to encode response", map[string]interface{}{
			"error": err.Error(),
		})
	}
}

func (h *PuzzleHandler) respondError(w http.ResponseWriter, err error) {
	var appErr *errors.AppError
	var ok bool
	if appErr, ok = err.(*errors.AppError); !ok {
		appErr = errors.NewInternalServerError(err)
	}

	h.log.Error("Request error", map[string]interface{}{
		"code":    appErr.Code,
		"message": appErr.Message,
		"error":   appErr.Error(),
	})

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(appErr.HTTPStatus)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]interface{}{
			"code":    appErr.Code,
			"message": appErr.Message,
		},
	})
}
