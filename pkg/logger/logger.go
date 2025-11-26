package logger

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"
)

// Level represents log severity
type Level string

const (
	DEBUG Level = "DEBUG"
	INFO  Level = "INFO"
	WARN  Level = "WARN"
	ERROR Level = "ERROR"
	FATAL Level = "FATAL"
)

// Logger provides structured logging
type Logger struct {
	serviceName string
	level       Level
}

// LogEntry represents a structured log entry
type LogEntry struct {
	Timestamp   time.Time              `json:"timestamp"`
	Level       Level                  `json:"level"`
	Service     string                 `json:"service"`
	Message     string                 `json:"message"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
	CorrelationID string               `json:"correlation_id,omitempty"`
}

// New creates a new logger instance
func New(serviceName string) *Logger {
	return &Logger{
		serviceName: serviceName,
		level:       INFO,
	}
}

// SetLevel sets the minimum log level
func (l *Logger) SetLevel(level Level) {
	l.level = level
}

// Debug logs a debug message
func (l *Logger) Debug(message string, metadata ...map[string]interface{}) {
	if l.shouldLog(DEBUG) {
		l.log(DEBUG, message, metadata...)
	}
}

// Info logs an info message
func (l *Logger) Info(message string, metadata ...map[string]interface{}) {
	if l.shouldLog(INFO) {
		l.log(INFO, message, metadata...)
	}
}

// Warn logs a warning message
func (l *Logger) Warn(message string, metadata ...map[string]interface{}) {
	if l.shouldLog(WARN) {
		l.log(WARN, message, metadata...)
	}
}

// Error logs an error message
func (l *Logger) Error(message string, metadata ...map[string]interface{}) {
	if l.shouldLog(ERROR) {
		l.log(ERROR, message, metadata...)
	}
}

// Fatal logs a fatal message and exits
func (l *Logger) Fatal(message string, metadata ...map[string]interface{}) {
	l.log(FATAL, message, metadata...)
	os.Exit(1)
}

// WithCorrelationID returns a logger with correlation ID
func (l *Logger) WithCorrelationID(correlationID string) *Logger {
	return &Logger{
		serviceName: l.serviceName,
		level:       l.level,
	}
}

// log outputs the log entry
func (l *Logger) log(level Level, message string, metadata ...map[string]interface{}) {
	entry := LogEntry{
		Timestamp: time.Now().UTC(),
		Level:     level,
		Service:   l.serviceName,
		Message:   message,
	}

	if len(metadata) > 0 && metadata[0] != nil {
		entry.Metadata = metadata[0]
	}

	jsonBytes, err := json.Marshal(entry)
	if err != nil {
		log.Printf("Error marshaling log entry: %v", err)
		return
	}

	fmt.Println(string(jsonBytes))
}

// shouldLog checks if the message should be logged based on level
func (l *Logger) shouldLog(level Level) bool {
	levels := map[Level]int{
		DEBUG: 0,
		INFO:  1,
		WARN:  2,
		ERROR: 3,
		FATAL: 4,
	}
	return levels[level] >= levels[l.level]
}

// NewLogger creates a new logger instance (alias for New)
func NewLogger(serviceName string) *Logger {
	return New(serviceName)
}
