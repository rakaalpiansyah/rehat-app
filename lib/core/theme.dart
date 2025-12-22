// File: lib/core/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ... (Kode warna lama tetap ada) ...
  static const Color primaryPurple = Color(0xFF8B5CF6); 
  static const Color accentBlue = Color(0xFF3B82F6);    
  static const Color accentPink = Color(0xFFEC4899);    
  
  static const Color backgroundLight = Color(0xFFF5F7FB); 
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF1F2937);      
  static const Color textGrey = Color(0xFF9CA3AF);      

  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);

  // === TAMBAHAN BARU UNTUK HOME SCREEN (Agar Sesuai Desain) ===
  
  // 1. Header Gradient
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
  );

  // 2. Warna Kartu Spesifik (Home)
  // Card 1 (Total Sesi)
  static const Color sessionColorPrimary = Color(0xFF7F56D9);
  static const Color sessionColorLight   = Color(0xFFF4EBFF);

  // Card 2 (Interval)
  static const Color intervalColorPrimary = Color(0xFF2E90FA);
  static const Color intervalColorLight   = Color(0xFFEFF8FF);

  // Card 3 (Istirahat)
  static const Color breakColorPrimary    = Color(0xFFF63D68);
  static const Color breakColorLight      = Color(0xFFFFF0F3);

  // ... (Sisa kode theme lama: lightTheme, darkTheme, dll tetap sama) ...
  
  // === BACKWARD COMPATIBILITY ===
  static const Color primaryColor = primaryPurple; 
  static const Color secondaryColor = accentBlue;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ... (ThemeData getters) ...
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
      // ...
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.dark,
        primary: primaryPurple,
        secondary: accentBlue,
        surface: cardDark,
      ),
      // ...
    );
  }
}