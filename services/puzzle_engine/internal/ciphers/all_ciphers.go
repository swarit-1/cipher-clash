package ciphers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"math/big"
	"sort"
	"strings"
)

// ============================================================================
// 1. CAESAR CIPHER
// ============================================================================

type CaesarCipher struct{}

func (c *CaesarCipher) Name() string { return TypeCaesar }

func (c *CaesarCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	shift := int(config["shift"].(float64))
	return caesarShift(plaintext, shift), nil
}

func (c *CaesarCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	shift := int(config["shift"].(float64))
	return caesarShift(ciphertext, -shift), nil
}

func (c *CaesarCipher) GenerateKey(difficulty int) map[string]interface{} {
	shift := (difficulty * 3) % 26
	if shift == 0 {
		shift = 3
	}
	return map[string]interface{}{"shift": shift}
}

func caesarShift(text string, shift int) string {
	result := ""
	for _, char := range text {
		if char >= 'A' && char <= 'Z' {
			result += string((int(char-'A')+shift+26)%26 + 'A')
		} else if char >= 'a' && char <= 'z' {
			result += string((int(char-'a')+shift+26)%26 + 'a')
		} else {
			result += string(char)
		}
	}
	return result
}

// ============================================================================
// 2. VIGENERE CIPHER
// ============================================================================

type VigenereCipher struct{}

func (v *VigenereCipher) Name() string { return TypeVigenere }

func (v *VigenereCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	return vigenereProcess(plaintext, key, true), nil
}

func (v *VigenereCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	return vigenereProcess(ciphertext, key, false), nil
}

func (v *VigenereCipher) GenerateKey(difficulty int) map[string]interface{} {
	keyLength := 3 + (difficulty / 2)
	key := ""
	for i := 0; i < keyLength; i++ {
		key += string('A' + rune(randInt(26)))
	}
	return map[string]interface{}{"key": key}
}

func vigenereProcess(text, key string, encrypt bool) string {
	result := ""
	keyIndex := 0
	key = strings.ToUpper(key)

	for _, char := range text {
		if char >= 'A' && char <= 'Z' {
			shift := int(key[keyIndex%len(key)] - 'A')
			if !encrypt {
				shift = -shift
			}
			result += string((int(char-'A')+shift+26)%26 + 'A')
			keyIndex++
		} else if char >= 'a' && char <= 'z' {
			shift := int(key[keyIndex%len(key)] - 'A')
			if !encrypt {
				shift = -shift
			}
			result += string((int(char-'a')+shift+26)%26 + 'a')
			keyIndex++
		} else {
			result += string(char)
		}
	}
	return result
}

// ============================================================================
// 3. RAIL FENCE CIPHER
// ============================================================================

type RailFenceCipher struct{}

func (r *RailFenceCipher) Name() string { return TypeRailFence }

func (r *RailFenceCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	rails := int(config["rails"].(float64))
	if rails <= 1 {
		return plaintext, nil
	}

	fence := make([][]rune, rails)
	for i := range fence {
		fence[i] = make([]rune, 0)
	}

	rail, direction := 0, 1
	for _, char := range plaintext {
		fence[rail] = append(fence[rail], char)
		rail += direction
		if rail == 0 || rail == rails-1 {
			direction = -direction
		}
	}

	result := ""
	for _, row := range fence {
		result += string(row)
	}
	return result, nil
}

func (r *RailFenceCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	rails := int(config["rails"].(float64))
	if rails <= 1 {
		return ciphertext, nil
	}

	// Calculate rail lengths
	fence := make([][]rune, rails)
	railLengths := make([]int, rails)
	rail, direction := 0, 1
	for i := 0; i < len(ciphertext); i++ {
		railLengths[rail]++
		rail += direction
		if rail == 0 || rail == rails-1 {
			direction = -direction
		}
	}

	// Fill fence with ciphertext
	idx := 0
	for i := 0; i < rails; i++ {
		fence[i] = []rune(ciphertext[idx : idx+railLengths[i]])
		idx += railLengths[i]
	}

	// Read in zigzag pattern
	result := ""
	rail, direction = 0, 1
	railIdx := make([]int, rails)
	for i := 0; i < len(ciphertext); i++ {
		result += string(fence[rail][railIdx[rail]])
		railIdx[rail]++
		rail += direction
		if rail == 0 || rail == rails-1 {
			direction = -direction
		}
	}
	return result, nil
}

func (r *RailFenceCipher) GenerateKey(difficulty int) map[string]interface{} {
	rails := 2 + (difficulty / 3)
	if rails > 7 {
		rails = 7
	}
	return map[string]interface{}{"rails": rails}
}

// ============================================================================
// 4. PLAYFAIR CIPHER
// ============================================================================

type PlayfairCipher struct{}

func (p *PlayfairCipher) Name() string { return TypePlayfair }

func (p *PlayfairCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	grid := buildPlayfairGrid(key)
	return playfairProcess(plaintext, grid, true), nil
}

func (p *PlayfairCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	grid := buildPlayfairGrid(key)
	return playfairProcess(ciphertext, grid, false), nil
}

func (p *PlayfairCipher) GenerateKey(difficulty int) map[string]interface{} {
	keyLength := 5 + difficulty
	key := ""
	for i := 0; i < keyLength; i++ {
		key += string('A' + rune(randInt(26)))
	}
	return map[string]interface{}{"key": key}
}

func buildPlayfairGrid(key string) [5][5]rune {
	var grid [5][5]rune
	used := make(map[rune]bool)
	key = strings.ToUpper(strings.ReplaceAll(key, "J", "I"))

	idx := 0
	for _, char := range key {
		if char >= 'A' && char <= 'Z' && !used[char] {
			grid[idx/5][idx%5] = char
			used[char] = true
			idx++
		}
	}

	for char := 'A'; char <= 'Z' && idx < 25; char++ {
		if char == 'J' || used[char] {
			continue
		}
		grid[idx/5][idx%5] = char
		used[char] = true
		idx++
	}
	return grid
}

func playfairProcess(text string, grid [5][5]rune, encrypt bool) string {
	text = strings.ToUpper(strings.ReplaceAll(text, "J", "I"))
	text = strings.ReplaceAll(text, " ", "")

	// Find positions
	pos := make(map[rune][2]int)
	for i := 0; i < 5; i++ {
		for j := 0; j < 5; j++ {
			pos[grid[i][j]] = [2]int{i, j}
		}
	}

	result := ""
	for i := 0; i < len(text); i += 2 {
		a := rune(text[i])
		b := rune('X')
		if i+1 < len(text) {
			b = rune(text[i+1])
		}

		posA, posB := pos[a], pos[b]

		if posA[0] == posB[0] { // Same row
			if encrypt {
				result += string(grid[posA[0]][(posA[1]+1)%5])
				result += string(grid[posB[0]][(posB[1]+1)%5])
			} else {
				result += string(grid[posA[0]][(posA[1]+4)%5])
				result += string(grid[posB[0]][(posB[1]+4)%5])
			}
		} else if posA[1] == posB[1] { // Same column
			if encrypt {
				result += string(grid[(posA[0]+1)%5][posA[1]])
				result += string(grid[(posB[0]+1)%5][posB[1]])
			} else {
				result += string(grid[(posA[0]+4)%5][posA[1]])
				result += string(grid[(posB[0]+4)%5][posB[1]])
			}
		} else { // Rectangle
			result += string(grid[posA[0]][posB[1]])
			result += string(grid[posB[0]][posA[1]])
		}
	}
	return result
}

// ============================================================================
// 5. SUBSTITUTION CIPHER
// ============================================================================

type SubstitutionCipher struct{}

func (s *SubstitutionCipher) Name() string { return TypeSubstitution }

func (s *SubstitutionCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	result := ""
	for _, char := range plaintext {
		if char >= 'A' && char <= 'Z' {
			result += string(key[char-'A'])
		} else if char >= 'a' && char <= 'z' {
			result += string(key[char-'a'] + 32)
		} else {
			result += string(char)
		}
	}
	return result, nil
}

func (s *SubstitutionCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	reverseKey := make(map[rune]rune)
	for i, char := range key {
		reverseKey[char] = rune('A' + i)
		reverseKey[char+32] = rune('a' + i)
	}

	result := ""
	for _, char := range ciphertext {
		if val, ok := reverseKey[char]; ok {
			result += string(val)
		} else {
			result += string(char)
		}
	}
	return result, nil
}

func (s *SubstitutionCipher) GenerateKey(difficulty int) map[string]interface{} {
	alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	shuffled := shuffleString(alphabet)
	return map[string]interface{}{"key": shuffled}
}

// ============================================================================
// 6. TRANSPOSITION CIPHER
// ============================================================================

type TranspositionCipher struct{}

func (t *TranspositionCipher) Name() string { return TypeTransposition }

func (t *TranspositionCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	cols := len(key)
	rows := (len(plaintext) + cols - 1) / cols
	grid := make([][]rune, rows)

	idx := 0
	for i := 0; i < rows; i++ {
		grid[i] = make([]rune, cols)
		for j := 0; j < cols; j++ {
			if idx < len(plaintext) {
				grid[i][j] = rune(plaintext[idx])
				idx++
			} else {
				grid[i][j] = 'X'
			}
		}
	}

	order := getSortedOrder(key)
	result := ""
	for _, col := range order {
		for row := 0; row < rows; row++ {
			result += string(grid[row][col])
		}
	}
	return result, nil
}

func (t *TranspositionCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	cols := len(key)
	rows := len(ciphertext) / cols

	order := getSortedOrder(key)
	grid := make([][]rune, rows)
	for i := range grid {
		grid[i] = make([]rune, cols)
	}

	idx := 0
	for _, col := range order {
		for row := 0; row < rows; row++ {
			grid[row][col] = rune(ciphertext[idx])
			idx++
		}
	}

	result := ""
	for i := 0; i < rows; i++ {
		for j := 0; j < cols; j++ {
			result += string(grid[i][j])
		}
	}
	return strings.TrimRight(result, "X"), nil
}

func (t *TranspositionCipher) GenerateKey(difficulty int) map[string]interface{} {
	length := 3 + (difficulty / 2)
	key := ""
	for i := 0; i < length; i++ {
		key += string('A' + rune(i))
	}
	return map[string]interface{}{"key": shuffleString(key)}
}

// ============================================================================
// 7. XOR CIPHER
// ============================================================================

type XORCipher struct{}

func (x *XORCipher) Name() string { return TypeXOR }

func (x *XORCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	return xorProcess(plaintext, key), nil
}

func (x *XORCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	key := config["key"].(string)
	return xorProcess(ciphertext, key), nil
}

func (x *XORCipher) GenerateKey(difficulty int) map[string]interface{} {
	keyLength := 2 + (difficulty / 2)
	key := ""
	for i := 0; i < keyLength; i++ {
		key += string(rune(randInt(94) + 33))
	}
	return map[string]interface{}{"key": key}
}

func xorProcess(text, key string) string {
	result := ""
	for i, char := range text {
		result += string(char ^ rune(key[i%len(key)]))
	}
	return hex.EncodeToString([]byte(result))
}

// ============================================================================
// 8. BASE64 CIPHER
// ============================================================================

type Base64Cipher struct{}

func (b *Base64Cipher) Name() string { return TypeBase64 }

func (b *Base64Cipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	return base64.StdEncoding.EncodeToString([]byte(plaintext)), nil
}

func (b *Base64Cipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	decoded, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return "", err
	}
	return string(decoded), nil
}

func (b *Base64Cipher) GenerateKey(difficulty int) map[string]interface{} {
	return map[string]interface{}{}
}

// ============================================================================
// 9. MORSE CODE
// ============================================================================

type MorseCipher struct{}

var morseCode = map[rune]string{
	'A': ".-", 'B': "-...", 'C': "-.-.", 'D': "-..", 'E': ".", 'F': "..-.",
	'G': "--.", 'H': "....", 'I': "..", 'J': ".---", 'K': "-.-", 'L': ".-..",
	'M': "--", 'N': "-.", 'O': "---", 'P': ".--.", 'Q': "--.-", 'R': ".-.",
	'S': "...", 'T': "-", 'U': "..-", 'V': "...-", 'W': ".--", 'X': "-..-",
	'Y': "-.--", 'Z': "--..", '0': "-----", '1': ".----", '2': "..---",
	'3': "...--", '4': "....-", '5': ".....", '6': "-....", '7': "--...",
	'8': "---..", '9': "----.", ' ': "/",
}

func (m *MorseCipher) Name() string { return TypeMorse }

func (m *MorseCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	result := []string{}
	for _, char := range strings.ToUpper(plaintext) {
		if code, ok := morseCode[char]; ok {
			result = append(result, code)
		}
	}
	return strings.Join(result, " "), nil
}

func (m *MorseCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	reverseMorse := make(map[string]rune)
	for char, code := range morseCode {
		reverseMorse[code] = char
	}

	codes := strings.Split(ciphertext, " ")
	result := ""
	for _, code := range codes {
		if char, ok := reverseMorse[code]; ok {
			result += string(char)
		}
	}
	return result, nil
}

func (m *MorseCipher) GenerateKey(difficulty int) map[string]interface{} {
	return map[string]interface{}{}
}

// ============================================================================
// 10-15. SIMPLE ENCODINGS
// ============================================================================

type BinaryCipher struct{}
func (b *BinaryCipher) Name() string { return TypeBinary }
func (b *BinaryCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	result := ""
	for _, char := range plaintext {
		result += fmt.Sprintf("%08b ", char)
	}
	return strings.TrimSpace(result), nil
}
func (b *BinaryCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	parts := strings.Split(ciphertext, " ")
	result := ""
	for _, part := range parts {
		var char rune
		fmt.Sscanf(part, "%b", &char)
		result += string(char)
	}
	return result, nil
}
func (b *BinaryCipher) GenerateKey(difficulty int) map[string]interface{} {
	return map[string]interface{}{}
}

type HexadecimalCipher struct{}
func (h *HexadecimalCipher) Name() string { return TypeHexadecimal }
func (h *HexadecimalCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	return hex.EncodeToString([]byte(plaintext)), nil
}
func (h *HexadecimalCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	decoded, err := hex.DecodeString(ciphertext)
	return string(decoded), err
}
func (h *HexadecimalCipher) GenerateKey(difficulty int) map[string]interface{} {
	return map[string]interface{}{}
}

type ROT13Cipher struct{}
func (r *ROT13Cipher) Name() string { return TypeROT13 }
func (r *ROT13Cipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	return caesarShift(plaintext, 13), nil
}
func (r *ROT13Cipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	return caesarShift(ciphertext, 13), nil
}
func (r *ROT13Cipher) GenerateKey(difficulty int) map[string]interface{} {
	return map[string]interface{}{}
}

type AtbashCipher struct{}
func (a *AtbashCipher) Name() string { return TypeAtbash }
func (a *AtbashCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	result := ""
	for _, char := range plaintext {
		if char >= 'A' && char <= 'Z' {
			result += string('Z' - (char - 'A'))
		} else if char >= 'a' && char <= 'z' {
			result += string('z' - (char - 'a'))
		} else {
			result += string(char)
		}
	}
	return result, nil
}
func (a *AtbashCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	return a.Encrypt(ciphertext, config)
}
func (a *AtbashCipher) GenerateKey(difficulty int) map[string]interface{} {
	return map[string]interface{}{}
}

type BookCipherImpl struct{}
func (b *BookCipherImpl) Name() string { return TypeBookCipher }
func (b *BookCipherImpl) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	book := config["book"].(string)
	result := ""
	for _, char := range strings.ToUpper(plaintext) {
		idx := strings.Index(strings.ToUpper(book), string(char))
		if idx >= 0 {
			result += fmt.Sprintf("%d ", idx)
		}
	}
	return strings.TrimSpace(result), nil
}
func (b *BookCipherImpl) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	book := config["book"].(string)
	parts := strings.Split(ciphertext, " ")
	result := ""
	for _, part := range parts {
		var idx int
		fmt.Sscanf(part, "%d", &idx)
		if idx < len(book) {
			result += string(book[idx])
		}
	}
	return result, nil
}
func (b *BookCipherImpl) GenerateKey(difficulty int) map[string]interface{} {
	books := []string{
		"THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
		"CRYPTOGRAPHY IS THE PRACTICE OF SECURE COMMUNICATION",
		"HELLO WORLD THIS IS A TEST MESSAGE FOR ENCRYPTION",
	}
	return map[string]interface{}{"book": books[randInt(len(books))]}
}

type RSASimpleCipher struct{}
func (r *RSASimpleCipher) Name() string { return TypeRSASimple }
func (r *RSASimpleCipher) Encrypt(plaintext string, config map[string]interface{}) (string, error) {
	e := int64(config["e"].(float64))
	n := int64(config["n"].(float64))
	result := ""
	for _, char := range plaintext {
		encrypted := modPow(int64(char), e, n)
		result += fmt.Sprintf("%d ", encrypted)
	}
	return strings.TrimSpace(result), nil
}
func (r *RSASimpleCipher) Decrypt(ciphertext string, config map[string]interface{}) (string, error) {
	d := int64(config["d"].(float64))
	n := int64(config["n"].(float64))
	parts := strings.Split(ciphertext, " ")
	result := ""
	for _, part := range parts {
		var encrypted int64
		fmt.Sscanf(part, "%d", &encrypted)
		decrypted := modPow(encrypted, d, n)
		result += string(rune(decrypted))
	}
	return result, nil
}
func (r *RSASimpleCipher) GenerateKey(difficulty int) map[string]interface{} {
	// Simple RSA with small primes for demonstration
	p, q := int64(61), int64(53)
	n := p * q
	phi := (p - 1) * (q - 1)
	e := int64(17)
	d := modInverse(e, phi)
	return map[string]interface{}{"e": e, "d": d, "n": n}
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

func randInt(max int) int {
	n, _ := rand.Int(rand.Reader, big.NewInt(int64(max)))
	return int(n.Int64())
}

func shuffleString(s string) string {
	runes := []rune(s)
	for i := range runes {
		j := randInt(len(runes))
		runes[i], runes[j] = runes[j], runes[i]
	}
	return string(runes)
}

func getSortedOrder(key string) []int {
	type pair struct {
		char rune
		idx  int
	}
	pairs := make([]pair, len(key))
	for i, char := range key {
		pairs[i] = pair{char, i}
	}
	sort.Slice(pairs, func(i, j int) bool {
		return pairs[i].char < pairs[j].char
	})
	order := make([]int, len(key))
	for i, p := range pairs {
		order[i] = p.idx
	}
	return order
}

func modPow(base, exp, mod int64) int64 {
	result := int64(1)
	base = base % mod
	for exp > 0 {
		if exp%2 == 1 {
			result = (result * base) % mod
		}
		exp = exp >> 1
		base = (base * base) % mod
	}
	return result
}

func modInverse(a, m int64) int64 {
	for x := int64(1); x < m; x++ {
		if (a*x)%m == 1 {
			return x
		}
	}
	return 1
}
