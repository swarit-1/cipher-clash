package ciphers

import (
	"encoding/json"
	"strings"
	"testing"
)

const samplePlaintext = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"

// normalize mirrors the game's solution comparison: uppercase, strip
// non-alphanumerics.
func normalize(s string) string {
	var b strings.Builder
	for _, c := range strings.ToUpper(s) {
		if (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') {
			b.WriteRune(c)
		}
	}
	return b.String()
}

// roundTripMatches compares a decryption against the original plaintext.
// Playfair canonicalizes J->I and pads with X by design, so it is compared
// under that equivalence.
func roundTripMatches(cipherType, decrypted, plaintext string) bool {
	d, p := normalize(decrypted), normalize(plaintext)
	if d == p {
		return true
	}
	if cipherType == TypePlayfair {
		d = strings.TrimRight(strings.ReplaceAll(d, "J", "I"), "X")
		p = strings.TrimRight(strings.ReplaceAll(p, "J", "I"), "X")
		return d == p
	}
	return false
}

// TestAllCiphersRoundTrip proves every registered cipher can encrypt and
// decrypt at every difficulty, with config used both fresh (Go ints) and
// after a JSON round-trip (float64s) — the two paths production exercises.
func TestAllCiphersRoundTrip(t *testing.T) {
	types := GetAllCipherTypes()
	if len(types) < 15 {
		t.Fatalf("expected at least 15 cipher types, got %d", len(types))
	}

	for _, cipherType := range types {
		cipher := GetCipher(cipherType)
		if cipher == nil {
			t.Fatalf("GetCipher(%s) returned nil", cipherType)
		}

		for difficulty := 1; difficulty <= 10; difficulty++ {
			config := cipher.GenerateKey(difficulty)

			// Path 1: fresh config (in-process generation).
			encrypted, err := cipher.Encrypt(samplePlaintext, config)
			if err != nil {
				t.Fatalf("%s d%d encrypt: %v", cipherType, difficulty, err)
			}
			if encrypted == "" {
				t.Fatalf("%s d%d produced empty ciphertext", cipherType, difficulty)
			}

			decrypted, err := cipher.Decrypt(encrypted, config)
			if err != nil {
				t.Fatalf("%s d%d decrypt: %v", cipherType, difficulty, err)
			}
			if !roundTripMatches(cipherType, decrypted, samplePlaintext) {
				t.Fatalf("%s d%d round trip mismatch:\n  plain: %q\n  got:   %q",
					cipherType, difficulty, samplePlaintext, decrypted)
			}

			// Path 2: config after JSON round trip (numbers become float64),
			// as when a puzzle is reloaded from the database.
			raw, _ := json.Marshal(config)
			var jsonConfig map[string]interface{}
			json.Unmarshal(raw, &jsonConfig)

			encrypted2, err := cipher.Encrypt(samplePlaintext, jsonConfig)
			if err != nil {
				t.Fatalf("%s d%d encrypt (json config): %v", cipherType, difficulty, err)
			}
			decrypted2, err := cipher.Decrypt(encrypted2, jsonConfig)
			if err != nil {
				t.Fatalf("%s d%d decrypt (json config): %v", cipherType, difficulty, err)
			}
			if !roundTripMatches(cipherType, decrypted2, samplePlaintext) {
				t.Fatalf("%s d%d json-config round trip mismatch: %q", cipherType, difficulty, decrypted2)
			}
		}
	}
}

// TestResumeCitedCiphersExist pins the specific algorithms cited externally.
func TestResumeCitedCiphersExist(t *testing.T) {
	for _, required := range []string{TypeRSASimple, TypeVigenere, TypePlayfair, TypeXOR} {
		if GetCipher(required) == nil {
			t.Fatalf("required cipher %s is not registered", required)
		}
	}
}
