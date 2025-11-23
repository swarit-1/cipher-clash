package ciphers

import (
	"strings"
)

type RailFenceCipher struct{}

func NewRailFenceCipher() *RailFenceCipher {
	return &RailFenceCipher{}
}

func (r *RailFenceCipher) Encrypt(text string, rails int) string {
	if rails <= 1 {
		return text
	}

	fence := make([][]rune, rails)
	for i := range fence {
		fence[i] = make([]rune, 0)
	}

	rail := 0
	direction := 1

	for _, char := range text {
		fence[rail] = append(fence[rail], char)
		rail += direction

		if rail == 0 || rail == rails-1 {
			direction = -direction
		}
	}

	var result strings.Builder
	for _, row := range fence {
		for _, char := range row {
			result.WriteRune(char)
		}
	}
	return result.String()
}
