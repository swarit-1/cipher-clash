package errors

import (
	"fmt"
	"net/http"
)

// AppError represents application-specific errors
type AppError struct {
	Code       string `json:"code"`
	Message    string `json:"message"`
	HTTPStatus int    `json:"-"`
	Internal   error  `json:"-"`
}

// Error implements the error interface
func (e *AppError) Error() string {
	if e.Internal != nil {
		return fmt.Sprintf("%s: %s (internal: %v)", e.Code, e.Message, e.Internal)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// Unwrap returns the internal error
func (e *AppError) Unwrap() error {
	return e.Internal
}

// Common error codes
const (
	// Authentication & Authorization
	ErrUnauthorized       = "UNAUTHORIZED"
	ErrForbidden          = "FORBIDDEN"
	ErrInvalidCredentials = "INVALID_CREDENTIALS"
	ErrTokenExpired       = "TOKEN_EXPIRED"
	ErrTokenInvalid       = "TOKEN_INVALID"

	// User Management
	ErrUserNotFound      = "USER_NOT_FOUND"
	ErrUserAlreadyExists = "USER_ALREADY_EXISTS"
	ErrInvalidInput      = "INVALID_INPUT"

	// Game & Matchmaking
	ErrMatchNotFound    = "MATCH_NOT_FOUND"
	ErrPuzzleNotFound   = "PUZZLE_NOT_FOUND"
	ErrAlreadyInQueue   = "ALREADY_IN_QUEUE"
	ErrNotInQueue       = "NOT_IN_QUEUE"
	ErrGameFull         = "GAME_FULL"
	ErrGameNotStarted   = "GAME_NOT_STARTED"
	ErrInvalidSolution  = "INVALID_SOLUTION"

	// System
	ErrInternalServer  = "INTERNAL_SERVER_ERROR"
	ErrDatabaseError   = "DATABASE_ERROR"
	ErrCacheError      = "CACHE_ERROR"
	ErrServiceUnavailable = "SERVICE_UNAVAILABLE"
	ErrRateLimitExceeded  = "RATE_LIMIT_EXCEEDED"
)

// Predefined errors
func NewUnauthorizedError(message string) *AppError {
	return &AppError{
		Code:       ErrUnauthorized,
		Message:    message,
		HTTPStatus: http.StatusUnauthorized,
	}
}

func NewForbiddenError(message string) *AppError {
	return &AppError{
		Code:       ErrForbidden,
		Message:    message,
		HTTPStatus: http.StatusForbidden,
	}
}

func NewInvalidCredentialsError() *AppError {
	return &AppError{
		Code:       ErrInvalidCredentials,
		Message:    "Invalid email or password",
		HTTPStatus: http.StatusUnauthorized,
	}
}

func NewUserNotFoundError() *AppError {
	return &AppError{
		Code:       ErrUserNotFound,
		Message:    "User not found",
		HTTPStatus: http.StatusNotFound,
	}
}

func NewUserAlreadyExistsError(field string) *AppError {
	return &AppError{
		Code:       ErrUserAlreadyExists,
		Message:    fmt.Sprintf("User with this %s already exists", field),
		HTTPStatus: http.StatusConflict,
	}
}

func NewInvalidInputError(message string) *AppError {
	return &AppError{
		Code:       ErrInvalidInput,
		Message:    message,
		HTTPStatus: http.StatusBadRequest,
	}
}

func NewMatchNotFoundError() *AppError {
	return &AppError{
		Code:       ErrMatchNotFound,
		Message:    "Match not found",
		HTTPStatus: http.StatusNotFound,
	}
}

func NewPuzzleNotFoundError() *AppError {
	return &AppError{
		Code:       ErrPuzzleNotFound,
		Message:    "Puzzle not found",
		HTTPStatus: http.StatusNotFound,
	}
}

func NewAlreadyInQueueError() *AppError {
	return &AppError{
		Code:       ErrAlreadyInQueue,
		Message:    "Already in matchmaking queue",
		HTTPStatus: http.StatusConflict,
	}
}

func NewInternalServerError(internal error) *AppError {
	return &AppError{
		Code:       ErrInternalServer,
		Message:    "An internal error occurred",
		HTTPStatus: http.StatusInternalServerError,
		Internal:   internal,
	}
}

func NewDatabaseError(internal error) *AppError {
	return &AppError{
		Code:       ErrDatabaseError,
		Message:    "Database operation failed",
		HTTPStatus: http.StatusInternalServerError,
		Internal:   internal,
	}
}

func NewRateLimitError() *AppError {
	return &AppError{
		Code:       ErrRateLimitExceeded,
		Message:    "Rate limit exceeded. Please try again later",
		HTTPStatus: http.StatusTooManyRequests,
	}
}

// NewInternalError creates a generic internal server error
func NewInternalError(message string) *AppError {
	return &AppError{
		Code:       ErrInternalServer,
		Message:    message,
		HTTPStatus: http.StatusInternalServerError,
	}
}

// NewNotFoundError creates a generic not found error
func NewNotFoundError(message string) *AppError {
	return &AppError{
		Code:       "NOT_FOUND",
		Message:    message,
		HTTPStatus: http.StatusNotFound,
	}
}
