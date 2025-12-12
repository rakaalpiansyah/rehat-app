import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // Key untuk penyimpanan
  static const String keyIsDark = 'is_dark_theme';
  static const String keyVibration = 'vibration_enabled';
  static const String keySound = 'selected_sound_index';

  // State awal
  bool _isDarkMode = false;
  bool _isVibrationEnabled = true;
  int _selectedSoundIndex = 5; // Default: Ombak Pantai

  bool get isDarkMode => _isDarkMode;
  bool get isVibrationEnabled => _isVibrationEnabled;
  int get selectedSoundIndex => _selectedSoundIndex;

  SettingsProvider() {
    _loadPreferences();
  }

  // Load data dari HP saat aplikasi dibuka
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(keyIsDark) ?? false;
    _isVibrationEnabled = prefs.getBool(keyVibration) ?? true;
    _selectedSoundIndex = prefs.getInt(keySound) ?? 5;
    notifyListeners(); // Update UI
  }

  // Ubah & Simpan Tema
  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsDark, value);
  }

  // Ubah & Simpan Getaran
  Future<void> toggleVibration(bool value) async {
    _isVibrationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVibration, value);
  }

  // Ubah & Simpan Suara
  Future<void> setSound(int index) async {
    _selectedSoundIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySound, index);
  }
}