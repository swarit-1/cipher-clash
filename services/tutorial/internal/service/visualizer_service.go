package service

import (
	"context"
	"fmt"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal"
)

type VisualizerService interface {
	GetCipherVisualization(ctx context.Context, cipherType string, input string, key string) (*internal.CipherVisualization, error)
	GetAvailableVisualizers(ctx context.Context) ([]string, error)
}

type visualizerService struct {
	log *logger.Logger
}

func NewVisualizerService(log *logger.Logger) VisualizerService {
	return &visualizerService{
		log: log,
	}
}

func (s *visualizerService) GetAvailableVisualizers(ctx context.Context) ([]string, error) {
	return []string{
		"CAESAR",
		"VIGENERE",
		"RAIL_FENCE",
		"PLAYFAIR",
		"SUBSTITUTION",
		"TRANSPOSITION",
		"XOR",
		"BASE64",
		"MORSE",
		"BINARY",
		"HEXADECIMAL",
		"ROT13",
		"ATBASH",
	}, nil
}

func (s *visualizerService) GetCipherVisualization(ctx context.Context, cipherType string, input string, key string) (*internal.CipherVisualization, error) {
	cipherType = strings.ToUpper(cipherType)

	switch cipherType {
	case "CAESAR":
		return s.visualizeCaesar(input, key), nil
	case "VIGENERE":
		return s.visualizeVigenere(input, key), nil
	case "RAIL_FENCE":
		return s.visualizeRailFence(input, key), nil
	case "ROT13":
		return s.visualizeROT13(input), nil
	case "ATBASH":
		return s.visualizeAtbash(input), nil
	case "BASE64":
		return s.visualizeBase64(input), nil
	default:
		return nil, fmt.Errorf("visualizer not implemented for cipher type: %s", cipherType)
	}
}

func (s *visualizerService) visualizeCaesar(input string, key string) *internal.CipherVisualization {
	shift := 3 // Default shift
	if key != "" {
		// Parse key as shift amount
		fmt.Sscanf(key, "%d", &shift)
	}

	output := caesarCipher(input, shift)

	steps := []internal.VisualizationStep{
		{
			StepNumber:  1,
			Title:       "Original Text",
			Description: "The plaintext message we want to encrypt",
			Input:       input,
			Output:      input,
			Explanation: "This is the original message before encryption",
		},
		{
			StepNumber:  2,
			Title:       fmt.Sprintf("Apply Shift (Shift = %d)", shift),
			Description: "Each letter is shifted by the key amount",
			Input:       input,
			Output:      output,
			Explanation: fmt.Sprintf("Each letter is moved %d positions forward in the alphabet", shift),
		},
		{
			StepNumber:  3,
			Title:       "Encrypted Result",
			Description: "The final encrypted ciphertext",
			Input:       output,
			Output:      output,
			Explanation: "This is the encrypted message that can be transmitted securely",
		},
	}

	return &internal.CipherVisualization{
		CipherType:  "CAESAR",
		Steps:       steps,
		Interactive: true,
		Example: internal.CipherExample{
			PlainText:  input,
			CipherText: output,
			Key:        fmt.Sprintf("%d", shift),
			Difficulty: 1,
		},
		Metadata: map[string]interface{}{
			"shift":     shift,
			"algorithm": "Caesar Cipher",
		},
	}
}

func (s *visualizerService) visualizeVigenere(input string, key string) *internal.CipherVisualization {
	if key == "" {
		key = "KEY"
	}

	output := vigenereCipher(input, key)

	steps := []internal.VisualizationStep{
		{
			StepNumber:  1,
			Title:       "Original Text",
			Description: "The plaintext message",
			Input:       input,
			Output:      input,
			Explanation: "This is the original message",
		},
		{
			StepNumber:  2,
			Title:       "Repeat Key",
			Description: fmt.Sprintf("Key '%s' is repeated to match text length", key),
			Input:       input,
			Output:      repeatKey(key, len(input)),
			Explanation: "The key is repeated to cover all characters in the plaintext",
		},
		{
			StepNumber:  3,
			Title:       "Apply Vigenere Cipher",
			Description: "Each letter is shifted by the corresponding key letter",
			Input:       input,
			Output:      output,
			Explanation: "Each plaintext letter is shifted by the value of the corresponding key letter",
		},
	}

	return &internal.CipherVisualization{
		CipherType:  "VIGENERE",
		Steps:       steps,
		Interactive: true,
		Example: internal.CipherExample{
			PlainText:  input,
			CipherText: output,
			Key:        key,
			Difficulty: 3,
		},
		Metadata: map[string]interface{}{
			"key":       key,
			"algorithm": "Vigenere Cipher",
		},
	}
}

func (s *visualizerService) visualizeRailFence(input string, key string) *internal.CipherVisualization {
	rails := 3 // Default rails
	if key != "" {
		fmt.Sscanf(key, "%d", &rails)
	}

	output := railFenceCipher(input, rails)

	steps := []internal.VisualizationStep{
		{
			StepNumber:  1,
			Title:       "Original Text",
			Description: "The plaintext message",
			Input:       input,
			Output:      input,
			Explanation: "This is the original message",
		},
		{
			StepNumber:  2,
			Title:       fmt.Sprintf("Create Rail Fence Pattern (%d rails)", rails),
			Description: "Text is written in a zigzag pattern",
			Input:       input,
			Output:      visualizeRailPattern(input, rails),
			Explanation: fmt.Sprintf("The text is arranged in a zigzag pattern across %d rails", rails),
		},
		{
			StepNumber:  3,
			Title:       "Read Rows",
			Description: "Read each row left to right",
			Input:       visualizeRailPattern(input, rails),
			Output:      output,
			Explanation: "The ciphertext is formed by reading each rail from left to right",
		},
	}

	return &internal.CipherVisualization{
		CipherType:  "RAIL_FENCE",
		Steps:       steps,
		Interactive: true,
		Example: internal.CipherExample{
			PlainText:  input,
			CipherText: output,
			Key:        fmt.Sprintf("%d", rails),
			Difficulty: 4,
		},
		Metadata: map[string]interface{}{
			"rails":     rails,
			"algorithm": "Rail Fence Cipher",
		},
	}
}

func (s *visualizerService) visualizeROT13(input string) *internal.CipherVisualization {
	output := caesarCipher(input, 13)

	steps := []internal.VisualizationStep{
		{
			StepNumber:  1,
			Title:       "Original Text",
			Description: "The plaintext message",
			Input:       input,
			Output:      input,
			Explanation: "This is the original message",
		},
		{
			StepNumber:  2,
			Title:       "Apply ROT13 (Shift 13)",
			Description: "Each letter is shifted by 13 positions",
			Input:       input,
			Output:      output,
			Explanation: "ROT13 is a special case of Caesar cipher with a shift of 13",
		},
	}

	return &internal.CipherVisualization{
		CipherType:  "ROT13",
		Steps:       steps,
		Interactive: true,
		Example: internal.CipherExample{
			PlainText:  input,
			CipherText: output,
			Key:        "13",
			Difficulty: 1,
		},
		Metadata: map[string]interface{}{
			"algorithm": "ROT13 (Caesar with shift 13)",
		},
	}
}

func (s *visualizerService) visualizeAtbash(input string) *internal.CipherVisualization {
	output := atbashCipher(input)

	steps := []internal.VisualizationStep{
		{
			StepNumber:  1,
			Title:       "Original Text",
			Description: "The plaintext message",
			Input:       input,
			Output:      input,
			Explanation: "This is the original message",
		},
		{
			StepNumber:  2,
			Title:       "Apply Atbash",
			Description: "Each letter is replaced with its reverse (A↔Z, B↔Y, etc.)",
			Input:       input,
			Output:      output,
			Explanation: "Atbash reverses the alphabet: A becomes Z, B becomes Y, and so on",
		},
	}

	return &internal.CipherVisualization{
		CipherType:  "ATBASH",
		Steps:       steps,
		Interactive: true,
		Example: internal.CipherExample{
			PlainText:  input,
			CipherText: output,
			Key:        "",
			Difficulty: 2,
		},
		Metadata: map[string]interface{}{
			"algorithm": "Atbash Cipher",
		},
	}
}

func (s *visualizerService) visualizeBase64(input string) *internal.CipherVisualization {
	// Simple base64-like visualization (simplified for tutorial)
	output := strings.ToUpper(input) // Simplified

	steps := []internal.VisualizationStep{
		{
			StepNumber:  1,
			Title:       "Original Text",
			Description: "The plaintext message",
			Input:       input,
			Output:      input,
			Explanation: "This is the original message",
		},
		{
			StepNumber:  2,
			Title:       "Convert to Binary",
			Description: "Text is converted to binary representation",
			Input:       input,
			Output:      "Binary representation",
			Explanation: "Each character is converted to its 8-bit binary value",
		},
		{
			StepNumber:  3,
			Title:       "Group into 6-bit Chunks",
			Description: "Binary is grouped into 6-bit chunks",
			Input:       "Binary representation",
			Output:      "6-bit groups",
			Explanation: "The binary data is divided into groups of 6 bits",
		},
		{
			StepNumber:  4,
			Title:       "Map to Base64 Characters",
			Description: "Each 6-bit group maps to a Base64 character",
			Input:       "6-bit groups",
			Output:      output,
			Explanation: "Each 6-bit value corresponds to a character in the Base64 alphabet",
		},
	}

	return &internal.CipherVisualization{
		CipherType:  "BASE64",
		Steps:       steps,
		Interactive: true,
		Example: internal.CipherExample{
			PlainText:  input,
			CipherText: output,
			Key:        "",
			Difficulty: 3,
		},
		Metadata: map[string]interface{}{
			"algorithm": "Base64 Encoding",
		},
	}
}

// Helper functions for actual cipher implementations

func caesarCipher(text string, shift int) string {
	result := strings.Builder{}
	for _, ch := range text {
		if ch >= 'A' && ch <= 'Z' {
			result.WriteRune('A' + (ch-'A'+rune(shift))%26)
		} else if ch >= 'a' && ch <= 'z' {
			result.WriteRune('a' + (ch-'a'+rune(shift))%26)
		} else {
			result.WriteRune(ch)
		}
	}
	return result.String()
}

func vigenereCipher(text string, key string) string {
	result := strings.Builder{}
	keyIndex := 0
	key = strings.ToUpper(key)

	for _, ch := range text {
		if ch >= 'A' && ch <= 'Z' {
			shift := int(key[keyIndex%len(key)] - 'A')
			result.WriteRune('A' + (ch-'A'+rune(shift))%26)
			keyIndex++
		} else if ch >= 'a' && ch <= 'z' {
			shift := int(key[keyIndex%len(key)] - 'A')
			result.WriteRune('a' + (ch-'a'+rune(shift))%26)
			keyIndex++
		} else {
			result.WriteRune(ch)
		}
	}
	return result.String()
}

func repeatKey(key string, length int) string {
	result := strings.Builder{}
	for i := 0; i < length; i++ {
		result.WriteByte(key[i%len(key)])
	}
	return result.String()
}

func railFenceCipher(text string, rails int) string {
	if rails <= 1 {
		return text
	}

	// Create rails
	fence := make([]strings.Builder, rails)
	rail := 0
	direction := 1

	for _, ch := range text {
		fence[rail].WriteRune(ch)
		rail += direction
		if rail == 0 || rail == rails-1 {
			direction = -direction
		}
	}

	// Combine rails
	result := strings.Builder{}
	for i := 0; i < rails; i++ {
		result.WriteString(fence[i].String())
	}

	return result.String()
}

func visualizeRailPattern(text string, rails int) string {
	// Simple visualization
	return fmt.Sprintf("[Rail Fence Pattern with %d rails]", rails)
}

func atbashCipher(text string) string {
	result := strings.Builder{}
	for _, ch := range text {
		if ch >= 'A' && ch <= 'Z' {
			result.WriteRune('Z' - (ch - 'A'))
		} else if ch >= 'a' && ch <= 'z' {
			result.WriteRune('z' - (ch - 'a'))
		} else {
			result.WriteRune(ch)
		}
	}
	return result.String()
}
