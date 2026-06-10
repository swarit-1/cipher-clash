import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

/// "How this cipher works" content for every cipher in the game.
/// Shown in the codex screen, the tutorial, and in-match via the info
/// button on the puzzle card.
class CipherExplainer {
  const CipherExplainer({
    required this.type,
    required this.name,
    required this.icon,
    required this.summary,
    required this.how,
    required this.example,
    required this.tip,
  });

  final String type;
  final String name;
  final String icon;
  final String summary;
  final String how;
  final String example;
  final String tip;
}

const cipherExplainers = <CipherExplainer>[
  CipherExplainer(
    type: 'CAESAR',
    name: 'Caesar Cipher',
    icon: '🏛️',
    summary: 'Every letter is shifted a fixed number of places.',
    how: 'Choose a shift K. Each letter moves K places down the alphabet, '
        'wrapping from Z back to A. Decryption shifts back by K.',
    example: 'Shift 3:  ATTACK → DWWDFN',
    tip: 'Try shifting the first word by 1, 2, 3… — one shift will suddenly '
        'read as English. Frequency helps: the most common letter is often E.',
  ),
  CipherExplainer(
    type: 'ROT13',
    name: 'ROT13',
    icon: '🔄',
    summary: 'A Caesar cipher locked at shift 13.',
    how: 'Each letter moves exactly 13 places. Because 13 is half the '
        'alphabet, encrypting twice returns the original text.',
    example: 'HELLO → URYYB → HELLO',
    tip: 'If a Caesar guess of 13 works, it is ROT13. A↔N, B↔O, C↔P…',
  ),
  CipherExplainer(
    type: 'ATBASH',
    name: 'Atbash',
    icon: '🪞',
    summary: 'The alphabet mirrored: A↔Z, B↔Y, C↔X.',
    how: 'Replace each letter with its mirror across the alphabet midpoint. '
        'The transformation is its own inverse.',
    example: 'WIZARD → DRAZIW',
    tip: 'Spot it fast: common words become recognizable mirrored shapes — '
        '"GSV" is "THE".',
  ),
  CipherExplainer(
    type: 'VIGENERE',
    name: 'Vigenère Cipher',
    icon: '🗝️',
    summary: 'A keyword sets a different Caesar shift for every position.',
    how: 'Repeat the keyword above the plaintext. Each keyword letter '
        '(A=0, B=1, …) is the shift for that position. This defeats simple '
        'frequency analysis.',
    example: 'Key KEY:  HELLO → RIJVS',
    tip: 'In matches the key is short. Look for repeated ciphertext chunks — '
        'their spacing hints at the key length.',
  ),
  CipherExplainer(
    type: 'AUTOKEY',
    name: 'Autokey Cipher',
    icon: '🔗',
    summary: 'Vigenère where the message itself extends the key.',
    how: 'The keystream is a short primer followed by the plaintext itself, '
        'so the key never repeats.',
    example: 'Primer QUEEN, then the message continues the key.',
    tip: 'Crack the first letters with the primer, and each recovered letter '
        'unlocks the next one. It cascades.',
  ),
  CipherExplainer(
    type: 'RAIL_FENCE',
    name: 'Rail Fence',
    icon: '🚂',
    summary: 'Letters zigzag across rails, then read row by row.',
    how: 'Write the message diagonally down and up across N rails; the '
        'ciphertext is the rails concatenated. Nothing is substituted — '
        'only positions change.',
    example: '3 rails: WE ARE DISCOVERED → WECRD EAEIVRE RDSOE',
    tip: 'The letter frequencies look like normal English — that screams '
        'transposition. Try 2 then 3 rails.',
  ),
  CipherExplainer(
    type: 'TRANSPOSITION',
    name: 'Columnar Transposition',
    icon: '🧱',
    summary: 'The message is written in a grid and read out by columns.',
    how: 'Write the text in rows of width K, then read down each column. '
        'Decryption rebuilds the grid.',
    example: 'Width 4: THE QUICK… read in vertical stripes.',
    tip: 'Guess the column count from the message length\'s divisors.',
  ),
  CipherExplainer(
    type: 'SUBSTITUTION',
    name: 'Substitution Cipher',
    icon: '🎭',
    summary: 'Every letter maps to one fixed substitute letter.',
    how: 'A shuffled alphabet replaces the standard one. There are 26! keys, '
        'but letter frequencies and short words betray the mapping.',
    example: 'If E→X, every E in the message becomes X.',
    tip: 'Start with single-letter words (A, I) and the most frequent symbol '
        '(usually E or T).',
  ),
  CipherExplainer(
    type: 'PLAYFAIR',
    name: 'Playfair Cipher',
    icon: '🔲',
    summary: 'Letter pairs are encrypted on a 5×5 keyword grid.',
    how: 'A keyword fills a 5×5 grid (I and J share a cell). Each plaintext '
        'pair maps by grid rules: same row → letters to the right; same '
        'column → letters below; otherwise the rectangle corners swap.',
    example: 'Key PLAYFAIR: HI DE → BM OD',
    tip: 'Decryptions show I where you expect J, and X pads doubled letters '
        '— both are correct.',
  ),
  CipherExplainer(
    type: 'AFFINE',
    name: 'Affine Cipher',
    icon: '📐',
    summary: 'Each letter runs through the formula a·x + b (mod 26).',
    how: 'Letters become numbers (A=0…Z=25), are transformed by the linear '
        'function, and convert back. "a" must share no factors with 26.',
    example: 'a=5, b=8:  A→I, B→N, C→S…',
    tip: 'Only 12 valid values of "a" exist. Pin two letters (frequency '
        'analysis) and solve the two equations.',
  ),
  CipherExplainer(
    type: 'XOR',
    name: 'XOR Cipher',
    icon: '💾',
    summary: 'Bytes are XOR-ed with a repeating key; shown as hex.',
    how: 'Each plaintext byte is XOR-ed with a key byte. Applying the same '
        'key again restores the original — XOR is its own inverse. The '
        'result is hex-encoded for display.',
    example: '"A" (0x41) XOR 0x2A = 0x6B',
    tip: 'XOR of a space (0x20) with a letter flips its case — spaces leak '
        'the key.',
  ),
  CipherExplainer(
    type: 'BASE64',
    name: 'Base64',
    icon: '📦',
    summary: 'Binary data re-expressed in 64 printable characters.',
    how: 'Every 3 bytes become 4 characters from A–Z, a–z, 0–9, +, /. '
        'It is an encoding, not encryption — no key at all.',
    example: 'HELLO → SEVMTE8=',
    tip: 'The = padding and the character set are the giveaway.',
  ),
  CipherExplainer(
    type: 'MORSE',
    name: 'Morse Code',
    icon: '📡',
    summary: 'Letters as dots and dashes.',
    how: 'Each letter maps to a unique dot/dash pattern; letters separated '
        'by spaces, words by slashes.',
    example: 'SOS → ... --- ...',
    tip: 'E (.) and T (-) are the shortest — anchor on single symbols.',
  ),
  CipherExplainer(
    type: 'BINARY',
    name: 'Binary',
    icon: '0️⃣',
    summary: 'Each character as its 8-bit ASCII code.',
    how: 'Characters convert to their ASCII number written in base 2.',
    example: 'A → 01000001',
    tip: 'Uppercase letters start with 010, lowercase with 011.',
  ),
  CipherExplainer(
    type: 'HEXADECIMAL',
    name: 'Hexadecimal',
    icon: '🔢',
    summary: 'Each character as its ASCII code in base 16.',
    how: 'Two hex digits per character. 41–5A is A–Z, 61–7A is a–z.',
    example: 'HI → 4849',
    tip: '20 is a space — split on it and decode word by word.',
  ),
  CipherExplainer(
    type: 'BOOK_CIPHER',
    name: 'Book Cipher',
    icon: '📖',
    summary: 'Letters become positions in a shared text.',
    how: 'Both parties share a text (the "book"). Each plaintext letter is '
        'replaced by an index where that letter occurs in the book.',
    example: 'Book "THE QUICK…": T→0, H→1, E→2…',
    tip: 'Indexes repeat for repeated letters — map the small numbers first.',
  ),
  CipherExplainer(
    type: 'RSA_SIMPLE',
    name: 'RSA (simplified)',
    icon: '🔐',
    summary: 'Public-key crypto with small primes: c = mᵉ mod n.',
    how: 'Each character m is raised to the public exponent e modulo n '
        '(n = p·q). Decryption uses the private exponent d. Real RSA uses '
        'enormous primes; this teaching version uses small ones.',
    example: 'e=17, n=3233:  m=65 → c=2790',
    tip: 'With small n you can factor it, recover d, and decrypt like the '
        'server does.',
  ),
  CipherExplainer(
    type: 'ENIGMA_LITE',
    name: 'Enigma (lite)',
    icon: '⚙️',
    summary: 'A rotor machine whose mapping changes every keypress.',
    how: 'Three rotors substitute each letter, a reflector bounces it back, '
        'and the rotors step after every letter — so the same letter '
        'encrypts differently each time.',
    example: 'AAA → KQV (each A took a different path)',
    tip: 'Enigma never maps a letter to itself — use that to align guesses.',
  ),
];

CipherExplainer? explainerFor(String type) {
  for (final e in cipherExplainers) {
    if (e.type == type.toUpperCase()) return e;
  }
  return null;
}

/// Bottom sheet used in matches and practice: how the current cipher works.
void showCipherExplainer(BuildContext context, String cipherType) {
  final explainer = explainerFor(cipherType);
  if (explainer == null) return;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.darkNavy,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      child: _ExplainerBody(explainer: explainer, compact: true),
    ),
  );
}

class _ExplainerBody extends StatelessWidget {
  const _ExplainerBody({required this.explainer, this.compact = false});

  final CipherExplainer explainer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(explainer.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: AppTheme.spacing1),
              Expanded(
                child: Text(
                  explainer.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing1),
          Text(
            explainer.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.cyberBlue,
                ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          _section(context, 'HOW IT WORKS', explainer.how),
          const SizedBox(height: AppTheme.spacing2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border:
                  Border.all(color: AppTheme.cyberBlue.withValues(alpha: 0.3)),
            ),
            child: Text(
              explainer.example,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.electricGreen,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          _section(context, 'CODEBREAKER TIP', explainer.tip),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
        ),
        const SizedBox(height: 4),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// The Cipher Codex: a browsable reference of every cipher in the game.
class CodexScreen extends StatelessWidget {
  const CodexScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cipher Codex')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacing2),
                itemCount: cipherExplainers.length,
                itemBuilder: (context, index) {
                  final e = cipherExplainers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
                    child: GlowCard(
                      glowVariant: GlowCardVariant.none,
                      onTap: () => showCipherExplainer(context, e.type),
                      child: Row(
                        children: [
                          Text(e.icon, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: AppTheme.spacing2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  e.summary,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppTheme.textTertiary),
                        ],
                      ),
                    ).animate().fadeIn(delay: (25 * (index % 18)).ms),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
