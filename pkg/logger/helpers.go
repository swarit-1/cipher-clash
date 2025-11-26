package logger

// Helper functions to convert variadic key-value pairs to map
// This allows calling logger like: log.Error("message", "key1", val1, "key2", val2)
// instead of: log.Error("message", map[string]interface{}{"key1": val1, "key2": val2})

func toMap(keyvals ...interface{}) map[string]interface{} {
	m := make(map[string]interface{})
	for i := 0; i < len(keyvals)-1; i += 2 {
		if key, ok := keyvals[i].(string); ok {
			m[key] = keyvals[i+1]
		}
	}
	return m
}

// LogError logs an error with variadic key-value pairs
func (l *Logger) LogError(message string, keyvals ...interface{}) {
	if len(keyvals) > 0 {
		l.Error(message, toMap(keyvals...))
	} else {
		l.Error(message)
	}
}

// LogInfo logs info with variadic key-value pairs
func (l *Logger) LogInfo(message string, keyvals ...interface{}) {
	if len(keyvals) > 0 {
		l.Info(message, toMap(keyvals...))
	} else {
		l.Info(message)
	}
}

// LogWarn logs warning with variadic key-value pairs
func (l *Logger) LogWarn(message string, keyvals ...interface{}) {
	if len(keyvals) > 0 {
		l.Warn(message, toMap(keyvals...))
	} else {
		l.Warn(message)
	}
}

// LogDebug logs debug with variadic key-value pairs
func (l *Logger) LogDebug(message string, keyvals ...interface{}) {
	if len(keyvals) > 0 {
		l.Debug(message, toMap(keyvals...))
	} else {
		l.Debug(message)
	}
}
