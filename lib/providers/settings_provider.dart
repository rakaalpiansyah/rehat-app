import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart'; // ✅ Pastikan Import NotificationService

class SettingsProvider extends ChangeNotifier {
  // Key untuk penyimpanan
  static const String keyIsDark = 'is_dark_theme';
  static const String keyVibration = 'vibration_enabled';
  static const String keySound = 'selected_sound_index';

  // State awal
  bool _isDarkMode = false;
  bool _isVibrationEnabled = true;
  int _selectedSoundIndex = 5; 

  bool get isDarkMode => _isDarkMode;
  bool get isVibrationEnabled => _isVibrationEnabled;
  int get selectedSoundIndex => _selectedSoundIndex;

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(keyIsDark) ?? false;
    _isVibrationEnabled = prefs.getBool(keyVibration) ?? true;
    _selectedSoundIndex = prefs.getInt(keySound) ?? 5;
    notifyListeners(); 
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsDark, value);
  }

  // ✅ PERBAIKAN: Update Getaran & Reschedule Alarm
  Future<void> toggleVibration(bool value) async {
    _isVibrationEnabled = value;
    notifyListeners(); // Update UI Switch langsung biar responsif
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVibration, value);

    // 🔥 PENTING: Jadwalkan ulang semua alarm agar settingan getar baru diterapkan
    // ke alarm yang akan datang.
    debugPrint("🔄 Rescheduling alarms due to Vibration change...");
    await NotificationService().rescheduleAllNotificationsBackground();
  }

  // ✅ PERBAIKAN: Update Suara & Reschedule Alarm
  Future<void> setSound(int index) async {
    _selectedSoundIndex = index;
    notifyListeners(); // Update UI Grid langsung
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySound, index);

    // 🔥 PENTING: Jadwalkan ulang agar ID Channel suara berubah
    debugPrint("🔄 Rescheduling alarms due to Sound change...");
    await NotificationService().rescheduleAllNotificationsBackground();
  }
}