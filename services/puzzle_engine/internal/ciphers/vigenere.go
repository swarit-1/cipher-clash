package ciphers

import (
	"strings"
	"unicode"
)

type VigenereCipher struct{}

func NewVigenereCipher() *VigenereCipher {
	return &VigenereCipher{}
}

func (v *VigenereCipher) Encrypt(plaintext, key string) string {
	plaintext = strings.ToUpper(plaintext)
	key = strings.ToUpper(key)
	var result strings.Builder
	keyIndex := 0

	for _, char := range plaintext {
		if unicode.IsLetter(char) {
			shift := int(key[keyIndex%len(key)] - 'A')
			encryptedChar := 'A' + (char-'A'+rune(shift))%26
			result.WriteRune(encryptedChar)
			keyIndex++
		} else {
			result.WriteRune(char)
		}
	}
	return result.String()
}

func (v *VigenereCipher) Decrypt(ciphertext, key string) string {
	ciphertext = strings.ToUpper(ciphertext)
	key = strings.ToUpper(key)
	var result strings.Builder
	keyIndex := 0

	for _, char := range ciphertext {
		if unicode.IsLetter(char) {
			shift := int(key[keyIndex%len(key)] - 'A')
			decryptedChar := 'A' + (char-'A'-rune(shift)+26)%26
			result.WriteRune(decryptedChar)
			keyIndex++
		} else {
			result.WriteRune(char)
		}
	}
	return result.String()
}
