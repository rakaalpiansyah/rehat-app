// File: lib/core/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Warna Utama (Gradasi Ungu-Biru)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2E85FF), Color(0xFF6B4EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color primaryColor = Color(0xFF6B4EFF);
  static const Color secondaryColor = Color(0xFF2E85FF);
  static const Color backgroundColor = Color(0xFFF5F7FA); // Abu-abu muda
  static const Color textDark = Color(0xFF2D3142);
  static const Color textGrey = Color(0xFF9C9EB9);
  
  // Tema Global
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.poppinsTextTheme(), // Font Poppins
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}