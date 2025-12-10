// File: lib/core/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // === WARNA BARU (Sesuai Desain Schedule) ===
  static const Color primaryPurple = Color(0xFF8B5CF6); // Ungu Utama
  static const Color accentBlue = Color(0xFF3B82F6);    // Biru Slider
  static const Color accentPink = Color(0xFFEC4899);    // Pink Slider
  
  static const Color backgroundLight = Color(0xFFF5F7FB); // Background abu kebiruan
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF1F2937);      // Hitam lembut
  static const Color textGrey = Color(0xFF9CA3AF);      // Abu-abu teks

  // === BACKWARD COMPATIBILITY (Agar file lama tidak error) ===
  static const Color primaryColor = primaryPurple; 
  static const Color secondaryColor = accentBlue;

  // === GRADIENT ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === TEMA GLOBAL ===
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        primary: primaryPurple,
        secondary: accentBlue,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 6,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
        trackShape: RoundedRectSliderTrackShape(),
      ),
    );
  }
}