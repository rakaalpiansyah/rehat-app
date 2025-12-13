// File: lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // ✅ Wajib Import
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  // Key Penyimpanan
  static const String _keyIsDark = 'is_dark_theme';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keySound = 'selected_sound_index';

  // State
  bool _isDarkMode = false;
  bool _isVibrationEnabled = true;
  int _selectedSoundIndex = 5;

  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get isVibrationEnabled => _isVibrationEnabled;
  int get selectedSoundIndex => _selectedSoundIndex;

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_keyIsDark) ?? false;
    _isVibrationEnabled = prefs.getBool(_keyVibration) ?? true;
    _selectedSoundIndex = prefs.getInt(_keySound) ?? 5;
    notifyListeners();
  }

  // --- TEMA ---
  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDark, value);
  }

  // --- GETARAN ---
  Future<void> toggleVibration(bool value) async {
    _isVibrationEnabled = value;
    notifyListeners();
    
    // Simpan & Reschedule agar Channel ID berubah (vibOn/vibOff)
    await _saveAndReschedule((prefs) {
      prefs.setBool(_keyVibration, value);
    });
  }

  // --- SUARA ---
  Future<void> setSound(int index) async {
    _selectedSoundIndex = index;
    notifyListeners();

    // 1. Mainkan Preview Suara (Agar user tau bunyinya)
    _previewSound(index);

    // 2. Simpan & Reschedule agar Channel ID berubah (soundIndex)
    await _saveAndReschedule((prefs) {
      prefs.setInt(_keySound, index);
    });
  }

  // Helper: Memainkan Preview Suara dari Assets
  void _previewSound(int index) async {
    try {
      if (index == 0) {
        // Default Sound
        FlutterRingtonePlayer().playAlarm(looping: false, volume: 1.0, asAlarm: true);
      } else {
        // Custom Asset Sound
        await FlutterRingtonePlayer().play(
          fromAsset: "assets/sounds/sound$index.mp3",
          volume: 1.0,
          asAlarm: true, // Gunakan jalur alarm agar volume konsisten
        );
      }
    } catch (e) {
      debugPrint("❌ Gagal memutar preview suara: $e");
    }
  }

  // Helper: Simpan ke Prefs lalu Reschedule Notification
  Future<void> _saveAndReschedule(Function(SharedPreferences) saveAction) async {
    final prefs = await SharedPreferences.getInstance();
    await saveAction(prefs);

    debugPrint("🔄 Rescheduling alarms due to settings change...");
    await NotificationService().rescheduleAllNotificationsBackground();
  }
}