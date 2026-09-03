import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (Next-Gen Material 3 Emergency Palette)
  static const Color primaryRed = Color(0xFFE11D48); // Vibrant Emergency Rose-Crimson
  static const Color primaryDarkRed = Color(0xFFBE123C);
  static const Color primaryContainerRed = Color(0xFFFFF1F2);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF9F1239);

  static const Color secondaryBlue = Color(0xFF2563EB); // Cyber Emergency Blue
  static const Color secondaryDarkBlue = Color(0xFF1D4ED8);
  static const Color secondaryContainerBlue = Color(0xFFEFF6FF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF1E40AF);

  static const Color tertiaryAmber = Color(0xFFF59E0B); // High-Vis Amber Warning
  static const Color tertiaryDarkAmber = Color(0xFFD97706);
  static const Color tertiaryContainerAmber = Color(0xFFFFFBEB);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF92400E);

  static const Color emeraldGreen = Color(0xFF10B981); // Life-Safety Green
  static const Color emeraldContainer = Color(0xFFECFDF5);
  static const Color onEmerald = Color(0xFFFFFFFF);

  // Modern Neutral Surface Shades
  static const Color surfaceLight = Color(0xFFF8FAFC); // Crisp slate tint
  static const Color surfaceLow = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE2E8F0);
  static const Color surfaceHighest = Color(0xFFCBD5E1);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFF94A3B8);

  static const Color onSurface = Color(0xFF0F172A); // Deep Slate-Black
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color outlineColor = Color(0xFFCBD5E1);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEE2E2);

  // High-Grade Linear Gradients
  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFFBE123C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberBlueGradient = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlassGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Colored Ambient Glow Shadows
  static List<BoxShadow> glowShadow(Color color, {double blur = 24, double spread = 0, Offset offset = const Offset(0, 8)}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: blur,
        spreadRadius: spread,
        offset: offset,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: blur / 2,
        spreadRadius: spread,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryRed,
        onPrimary: onPrimary,
        primaryContainer: primaryContainerRed,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryBlue,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainerBlue,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiaryAmber,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainerAmber,
        onTertiaryContainer: onTertiaryContainer,
        error: errorRed,
        onError: Colors.white,
        errorContainer: errorContainer,
        onErrorContainer: Color(0xFF991B1B),
        surface: surfaceLight,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outlineColor,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: primaryRed,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: primaryRed,
          letterSpacing: 0.8,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: onPrimary,
          minimumSize: const Size(double.infinity, 54),
          elevation: 4,
          shadowColor: primaryRed.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: outlineColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryRed, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariant, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
    );
  }
}
