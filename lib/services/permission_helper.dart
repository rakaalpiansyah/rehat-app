// File: lib/utils/permission_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionHelper {
  static const String _keyHasShownAutoStart = 'has_shown_autostart_v2'; // Ganti v2 biar muncul lagi

  static Future<void> checkAndRequestSpecialPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final bool hasShown = prefs.getBool(_keyHasShownAutoStart) ?? false;

    if (hasShown) return;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final String manufacturer = androidInfo.manufacturer.toLowerCase();

    // ✅ Tambahkan 'samsung' ke daftar deteksi
    if (manufacturer.contains('xiaomi') ||
        manufacturer.contains('oppo') ||
        manufacturer.contains('vivo') ||
        manufacturer.contains('huawei') ||
        manufacturer.contains('asus') ||
        manufacturer.contains('samsung')) { // <-- Samsung ditambahkan
      
      if (!context.mounted) return;
      _showDialogGuide(context, manufacturer, prefs);
    }
  }

  static void _showDialogGuide(
      BuildContext context, String brand, SharedPreferences prefs) {
    
    // Instruksi berbeda untuk Samsung
    String instructionText = "";
    if (brand.contains('samsung')) {
      instructionText = 
          "Khusus Samsung, mohon aktifkan:\n\n"
          "1. 'Appear on top' (Muncul di atas)\n"
          "2. 'Alarms & reminders' (Alarm & pengingat)";
    } else {
      instructionText = 
          "Agar Alarm berjalan lancar, mohon aktifkan:\n\n"
          "1. Autostart / Mulai Otomatis\n"
          "2. Show on Lock Screen (Tampil di Layar Kunci)";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Izin Tambahan (${brand.toUpperCase()})"),
        content: Text(instructionText),
        actions: [
          TextButton(
            onPressed: () {
              prefs.setBool(_keyHasShownAutoStart, true);
              Navigator.pop(ctx);
            },
            child: const Text("Nanti Saja"),
          ),
          ElevatedButton(
            onPressed: () {
              prefs.setBool(_keyHasShownAutoStart, true);
              Navigator.pop(ctx);
              _openAutoStartSettings(brand);
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }

  static Future<void> _openAutoStartSettings(String brand) async {
    try {
      if (brand.contains('xiaomi')) {
        await const AndroidIntent(
          action: 'action_component',
          package: 'com.miui.securitycenter',
          componentName: 'com.miui.permcenter.autostart.AutoStartManagementActivity',
        ).launch();
      } else if (brand.contains('oppo')) {
        await const AndroidIntent(
          action: 'action_component',
          package: 'com.coloros.safecenter',
          componentName: 'com.coloros.safecenter.permission.startup.StartupAppListActivity',
        ).launch();
      } else if (brand.contains('vivo')) {
        await const AndroidIntent(
          action: 'action_component',
          package: 'com.vivo.permissionmanager',
          componentName: 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
        ).launch();
      } else if (brand.contains('samsung')) {
        // ✅ KHUSUS SAMSUNG
        // Samsung lebih baik diarahkan langsung ke App Detail Settings
        // User harus cari menu "Appear on top" di situ.
        await openAppSettings(); 
      } else {
        await openAppSettings();
      }
    } catch (e) {
      debugPrint("Gagal membuka intent khusus: $e");
      await openAppSettings();
    }
  }
}