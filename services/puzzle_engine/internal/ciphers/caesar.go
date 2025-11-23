package ciphers

import (
	"strings"
	"unicode"
)

type CaesarCipher struct{}

func NewCaesarCipher() *CaesarCipher {
	return &CaesarCipher{}
}

func (c *CaesarCipher) Encrypt(plaintext string, shift int) string {
	plaintext = strings.ToUpper(plaintext)
	var result strings.Builder

	for _, char := range plaintext {
		if unicode.IsLetter(char) {
			encryptedChar := 'A' + (char-'A'+rune(shift))%26
			result.WriteRune(encryptedChar)
		} else {
			result.WriteRune(char)
		}
	}
	return result.String()
}

func (c *CaesarCipher) Decrypt(ciphertext string, shift int) string {
	ciphertext = strings.ToUpper(ciphertext)
	var result strings.Builder

	for _, char := range ciphertext {
		if unicode.IsLetter(char) {
			decryptedChar := 'A' + (char-'A'-rune(shift)+26)%26
			result.WriteRune(decryptedChar)
		} else {
			result.WriteRune(char)
		}
	}
	return result.String()
}
