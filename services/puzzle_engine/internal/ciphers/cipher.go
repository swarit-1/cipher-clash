package ciphers

// Cipher represents a cipher algorithm interface
type Cipher interface {
	Encrypt(plaintext string, config map[string]interface{}) (string, error)
	Decrypt(ciphertext string, config map[string]interface{}) (string, error)
	GenerateKey(difficulty int) map[string]interface{}
	Name() string
}

// CipherType constants
const (
	TypeCaesar        = "CAESAR"
	TypeVigenere      = "VIGENERE"
	TypeRailFence     = "RAIL_FENCE"
	TypePlayfair      = "PLAYFAIR"
	TypeSubstitution  = "SUBSTITUTION"
	TypeTransposition = "TRANSPOSITION"
	TypeXOR           = "XOR"
	TypeBase64        = "BASE64"
	TypeMorse         = "MORSE"
	TypeBinary        = "BINARY"
	TypeHexadecimal   = "HEXADECIMAL"
	TypeROT13         = "ROT13"
	TypeAtbash        = "ATBASH"
	TypeBookCipher    = "BOOK_CIPHER"
	TypeRSASimple     = "RSA_SIMPLE"
	// V2.0 New Ciphers
	TypeAffine     = "AFFINE"
	TypeAutokey    = "AUTOKEY"
	TypeEnigmaLite = "ENIGMA_LITE"
)

// GetCipher returns a cipher by type
func GetCipher(cipherType string) Cipher {
	switch cipherType {
	case TypeCaesar:
		return &CaesarCipher{}
	case TypeVigenere:
		return &VigenereCipher{}
	case TypeRailFence:
		return &RailFenceCipher{}
	case TypePlayfair:
		return &PlayfairCipher{}
	case TypeSubstitution:
		return &SubstitutionCipher{}
	case TypeTransposition:
		return &TranspositionCipher{}
	case TypeXOR:
		return &XORCipher{}
	case TypeBase64:
		return &Base64Cipher{}
	case TypeMorse:
		return &MorseCipher{}
	case TypeBinary:
		return &BinaryCipher{}
	case TypeHexadecimal:
		return &HexadecimalCipher{}
	case TypeROT13:
		return &ROT13Cipher{}
	case TypeAtbash:
		return &AtbashCipher{}
	case TypeBookCipher:
		return &BookCipherImpl{}
	case TypeRSASimple:
		return &RSASimpleCipher{}
	case TypeAffine:
		return &AffineCipher{}
	case TypeAutokey:
		return &AutokeyCipher{}
	case TypeEnigmaLite:
		return &EnigmaLiteCipher{}
	default:
		return nil
	}
}

// GetAllCipherTypes returns all available cipher types
func GetAllCipherTypes() []string {
	return []string{
		TypeCaesar, TypeVigenere, TypeRailFence, TypePlayfair,
		TypeSubstitution, TypeTransposition, TypeXOR, TypeBase64,
		TypeMorse, TypeBinary, TypeHexadecimal, TypeROT13,
		TypeAtbash, TypeBookCipher, TypeRSASimple,
		TypeAffine, TypeAutokey, TypeEnigmaLite,
	}
}

// Config getters tolerant of both fresh Go values (int) and JSON round-trip
// values (float64). Cipher configs flow both ways: generated in-process and
// reloaded from the puzzles table's JSONB column.

func cfgInt(config map[string]interface{}, key string) int {
	switch v := config[key].(type) {
	case int:
		return v
	case int64:
		return int(v)
	case float64:
		return int(v)
	}
	return 0
}

func cfgInt64(config map[string]interface{}, key string) int64 {
	switch v := config[key].(type) {
	case int:
		return int64(v)
	case int64:
		return v
	case float64:
		return int64(v)
	}
	return 0
}

func cfgString(config map[string]interface{}, key string) string {
	v, _ := config[key].(string)
	return v
}
