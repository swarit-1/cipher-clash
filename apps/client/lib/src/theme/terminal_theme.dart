import 'package:flutter/material.dart';

class TerminalTheme {
  // Cyberpunk Palette
  static const Color background = Color(0xFF050B14); // Dark Navy/Black
  static const Color surface = Color(0xFF0A1428); // Slightly lighter navy
  static const Color primary = Color(0xFF00FF41); // Neon Green
  static const Color secondary = Color(0xFF00F3FF); // Cyan
  static const Color error = Color(0xFFFF0055); // Neon Red
  static const Color warning = Color(0xFFFFD700); // Gold

  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFA0A0A0);

  // Glow Effects
  static List<BoxShadow> get glowPrimary => [
        BoxShadow(
          color: primary.withValues(alpha: 0.6),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get glowError => [
        BoxShadow(
          color: error.withValues(alpha: 0.6),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: background,
        primaryColor: primary,
        fontFamily: 'Courier', // Ensure a monospace font is used
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: textPrimary, fontFamily: 'Courier'),
          bodyLarge: TextStyle(color: textPrimary, fontFamily: 'Courier'),
          titleLarge: TextStyle(
              color: primary,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: primary),
            borderRadius: BorderRadius.circular(4),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: primary, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Courier'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 5,
            shadowColor: primary,
          ),
        ),
      );
}
