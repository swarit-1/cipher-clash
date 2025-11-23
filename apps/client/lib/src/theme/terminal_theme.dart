import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TerminalTheme {
  static const Color background = Color(0xFF0A192F);
  static const Color primary = Color(0xFF64FFDA);
  static const Color secondary = Color(0xFF8892B0);
  static const Color error = Color(0xFFFF5555);

  static ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: Color(0xFF112240),
        error: error,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.firaCode(
          color: primary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.firaCode(
          color: secondary,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.firaCode(
          color: secondary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          textStyle: GoogleFonts.firaCode(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
