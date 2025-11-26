import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cipher Clash V2.0 - Cyberpunk Design System
class AppTheme {
  // ========================================
  // CYBERPUNK COLOR PALETTE
  // ========================================

  /// Primary: Cyber Blue - Main brand color
  static const Color cyberBlue = Color(0xFF00D9FF);

  /// Secondary: Neon Purple - Accents and highlights
  static const Color neonPurple = Color(0xFFB24BF3);

  /// Accent: Electric Green - Success states and energy
  static const Color electricGreen = Color(0xFF00FF85);

  /// Background: Deep Dark - Main background
  static const Color deepDark = Color(0xFF0A0E1A);

  /// Surface: Dark Navy - Cards and elevated surfaces
  static const Color darkNavy = Color(0xFF131829);

  /// Surface Variant: Slightly lighter for nested cards
  static const Color surfaceVariant = Color(0xFF1A1F35);

  /// Error: Neon Red - Errors and danger
  static const Color neonRed = Color(0xFFFF0055);

  /// Warning: Electric Yellow - Warnings
  static const Color electricYellow = Color(0xFFFFD700);

  /// Info: Cyan - Information
  static const Color infoCyan = Color(0xFF00F3FF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4B9C9);
  static const Color textTertiary = Color(0xFF7B8394);
  static const Color textDisabled = Color(0xFF4A4F5F);

  // Rank Tier Colors
  static const Color unrankedGray = Color(0xFF6B7280);
  static const Color bronzeBrown = Color(0xFFCD7F32);
  static const Color silverGray = Color(0xFFC0C0C0);
  static const Color goldYellow = Color(0xFFFFD700);
  static const Color platinumCyan = Color(0xFF00D9FF);
  static const Color diamondPurple = Color(0xFFB24BF3);

  // ========================================
  // SPACING SYSTEM (8px grid)
  // ========================================
  static const double spacing1 = 8.0; // 8px
  static const double spacing2 = 16.0; // 16px
  static const double spacing3 = 24.0; // 24px
  static const double spacing4 = 32.0; // 32px
  static const double spacing5 = 40.0; // 40px
  static const double spacing6 = 48.0; // 48px
  static const double spacing8 = 64.0; // 64px
  static const double spacing10 = 80.0; // 80px

  // ========================================
  // BORDER RADIUS
  // ========================================
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusFull = 9999.0;

  // ========================================
  // GLOW EFFECTS
  // ========================================
  static List<BoxShadow> glowCyberBlue({double intensity = 1.0}) => [
        BoxShadow(
          color: cyberBlue.withValues(alpha: 0.4 * intensity),
          blurRadius: 12 * intensity,
          spreadRadius: 2 * intensity,
        ),
        BoxShadow(
          color: cyberBlue.withValues(alpha: 0.2 * intensity),
          blurRadius: 24 * intensity,
          spreadRadius: 4 * intensity,
        ),
      ];

  static List<BoxShadow> glowNeonPurple({double intensity = 1.0}) => [
        BoxShadow(
          color: neonPurple.withValues(alpha: 0.4 * intensity),
          blurRadius: 12 * intensity,
          spreadRadius: 2 * intensity,
        ),
        BoxShadow(
          color: neonPurple.withValues(alpha: 0.2 * intensity),
          blurRadius: 24 * intensity,
          spreadRadius: 4 * intensity,
        ),
      ];

  static List<BoxShadow> glowElectricGreen({double intensity = 1.0}) => [
        BoxShadow(
          color: electricGreen.withValues(alpha: 0.4 * intensity),
          blurRadius: 12 * intensity,
          spreadRadius: 2 * intensity,
        ),
        BoxShadow(
          color: electricGreen.withValues(alpha: 0.2 * intensity),
          blurRadius: 24 * intensity,
          spreadRadius: 4 * intensity,
        ),
      ];

  static List<BoxShadow> glowNeonRed({double intensity = 1.0}) => [
        BoxShadow(
          color: neonRed.withValues(alpha: 0.4 * intensity),
          blurRadius: 10 * intensity,
          spreadRadius: 2 * intensity,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  // ========================================
  // GRADIENTS
  // ========================================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyberBlue, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [neonPurple, electricGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [deepDark, darkNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ========================================
  // TYPOGRAPHY
  // ========================================

  /// Headings: Space Grotesk (Bold, Futuristic)
  static TextTheme get headingTextTheme => TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 57,
          fontWeight: FontWeight.w700,
          height: 1.12,
          letterSpacing: -0.25,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 45,
          fontWeight: FontWeight.w700,
          height: 1.16,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.spaceGrotesk(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          height: 1.22,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.29,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.33,
          color: textPrimary,
        ),
      );

  /// Body: Inter (Clean, Readable)
  static TextTheme get bodyTextTheme => TextTheme(
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.15,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.43,
          letterSpacing: 0.25,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.33,
          letterSpacing: 0.4,
          color: textTertiary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.43,
          letterSpacing: 0.1,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0.5,
          color: textSecondary,
        ),
      );

  /// Code/Mono: JetBrains Mono (Terminal feel)
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: cyberBlue,
      );

  static TextStyle get monoStyleLarge => GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: cyberBlue,
      );

  // ========================================
  // INDIVIDUAL TEXT STYLES (Convenience Getters)
  // ========================================
  static TextStyle get headingLarge => headingTextTheme.headlineLarge!;
  static TextStyle get headingMedium => headingTextTheme.headlineMedium!;
  static TextStyle get headingSmall => headingTextTheme.headlineSmall!;

  static TextStyle get bodyLarge => bodyTextTheme.bodyLarge!;
  static TextStyle get bodyMedium => bodyTextTheme.bodyMedium!;
  static TextStyle get bodySmall => bodyTextTheme.bodySmall!;

  // ========================================
  // THEME DATA
  // ========================================
  static ThemeData get darkTheme {
    final headings = headingTextTheme;
    final body = bodyTextTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepDark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: cyberBlue,
        secondary: neonPurple,
        tertiary: electricGreen,
        error: neonRed,
        surface: darkNavy,
        surfaceContainerHighest: surfaceVariant,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onTertiary: Colors.black,
        onError: Colors.white,
        onSurface: textPrimary,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: headings.displayLarge,
        displayMedium: headings.displayMedium,
        displaySmall: headings.displaySmall,
        headlineLarge: headings.headlineLarge,
        headlineMedium: headings.headlineMedium,
        headlineSmall: headings.headlineSmall,
        bodyLarge: body.bodyLarge,
        bodyMedium: body.bodyMedium,
        bodySmall: body.bodySmall,
        labelLarge: body.labelLarge,
        labelMedium: body.labelMedium,
        labelSmall: body.labelSmall,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: deepDark.withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: headings.headlineSmall,
        iconTheme: const IconThemeData(color: cyberBlue),
      ),

      // Card
      cardTheme: CardThemeData(
        color: darkNavy,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: cyberBlue.withValues(alpha: 0.1), width: 1),
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyberBlue,
          foregroundColor: Colors.black,
          disabledBackgroundColor: textDisabled,
          disabledForegroundColor: textTertiary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing3,
            vertical: spacing2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cyberBlue,
          disabledForegroundColor: textDisabled,
          side: const BorderSide(color: cyberBlue, width: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing3,
            vertical: spacing2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyberBlue,
          disabledForegroundColor: textDisabled,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing2,
            vertical: spacing1,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.all(spacing2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: cyberBlue.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: cyberBlue.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: cyberBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: neonRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: neonRed, width: 2),
        ),
        labelStyle: body.bodyMedium,
        hintStyle: body.bodyMedium?.copyWith(color: textTertiary),
        errorStyle: body.bodySmall?.copyWith(color: neonRed),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: neonPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: cyberBlue,
        linearTrackColor: surfaceVariant,
        circularTrackColor: surfaceVariant,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: cyberBlue.withValues(alpha: 0.1),
        thickness: 1,
        space: spacing2,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: cyberBlue.withValues(alpha: 0.2),
        disabledColor: textDisabled.withValues(alpha: 0.1),
        labelStyle: body.labelMedium!,
        secondaryLabelStyle: body.labelSmall!,
        padding: const EdgeInsets.symmetric(horizontal: spacing1, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: BorderSide(color: cyberBlue.withValues(alpha: 0.3)),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: darkNavy,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: cyberBlue.withValues(alpha: 0.2)),
        ),
        titleTextStyle: headings.headlineSmall,
        contentTextStyle: body.bodyMedium,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkNavy,
        contentTextStyle: body.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    );
  }

  // ========================================
  // HELPER METHODS
  // ========================================

  /// Get rank tier color
  static Color getRankColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'BRONZE':
        return bronzeBrown;
      case 'SILVER':
        return silverGray;
      case 'GOLD':
        return goldYellow;
      case 'PLATINUM':
        return platinumCyan;
      case 'DIAMOND':
        return diamondPurple;
      default:
        return unrankedGray;
    }
  }

  /// Get difficulty color
  static Color getDifficultyColor(int difficulty) {
    if (difficulty <= 3) return electricGreen;
    if (difficulty <= 6) return electricYellow;
    if (difficulty <= 8) return cyberBlue;
    return neonPurple;
  }
}
