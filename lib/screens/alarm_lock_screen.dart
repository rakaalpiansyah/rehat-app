// File: lib/screens/alarm_lock_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // ✅ WAJIB ADA
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Untuk baca settingan user
import 'package:vibration/vibration.dart'; // ✅ WAJIB UNTUK GETARAN

import '../services/notification_service.dart';
import '../core/theme.dart';

class AlarmLockScreen extends StatefulWidget {
  final String payload;
  const AlarmLockScreen({super.key, required this.payload});

  @override
  State<AlarmLockScreen> createState() => _AlarmLockScreenState();
}

class _AlarmLockScreenState extends State<AlarmLockScreen>
    with SingleTickerProviderStateMixin {
  late String _timeString;
  late String _dateString;
  late Timer _timer;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Variabel untuk Getaran
  Timer? _vibrationTimer;
  // Pola getar: [diam, getar, diam, getar...]
  static const List<int> _vibrationPattern = [0, 500, 500, 500, 500, 500];

  // Channel untuk mematikan app & hapus history (Kotlin/Java)
  static const platform = MethodChannel('com.rehat/task_manager');

  // Data Payload
  int _notifId = 0;
  String title = "Alarm";
  String body = "...";
  int snoozeCount = 0;
  bool canSnooze = true;

  @override
  void initState() {
    super.initState();
    _parsePayload();
    
    // 1. Matikan notifikasi sistem agar tidak bentrok
    if (_notifId != 0) {
      NotificationService().cancelNotification(_notifId);
    }

    // 2. Mainkan Suara & Getaran sesuai settingan user
    _playCustomAlarmSound();
    _startVibration(); // ✅ Mulai getaran

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  // --- LOGIC SUARA ---
  Future<void> _playCustomAlarmSound() async {
    final prefs = await SharedPreferences.getInstance();
    final int soundIndex = prefs.getInt('selected_sound_index') ?? 5; 

    debugPrint("🔊 Alarm Lock Screen: Playing sound index $soundIndex");

    if (soundIndex == 0) {
      // Default Alarm
      FlutterRingtonePlayer().playAlarm(
        looping: true, 
        volume: 1.0, 
        asAlarm: true, 
      );
    } else {
      // Custom Asset Sound
      try {
        await FlutterRingtonePlayer().play(
          fromAsset: "assets/sounds/sound$soundIndex.mp3", 
          looping: true,
          volume: 1.0,
          asAlarm: true, 
        );
      } catch (e) {
        debugPrint("⚠️ Gagal memutar asset, fallback: $e");
        FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true);
      }
    }
  }

  // --- LOGIC GETARAN ---
  Future<void> _startVibration() async {
    final prefs = await SharedPreferences.getInstance();
    // Baca settingan VIBRATION dari SharedPreferences
    final bool isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true; 
    
    // Cek apakah HP punya vibrator & fitur aktif
    if (isVibrationEnabled && await Vibration.hasVibrator() == true) {
        
        // Panggil getaran pertama kali
        _triggerVibrate();

        // Loop getaran manual setiap 3 detik (karena repeat Android kadang tidak konsisten)
        _vibrationTimer = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
            _triggerVibrate();
        });
    }
  }

  Future<void> _triggerVibrate() async {
      if (await Vibration.hasCustomVibrationsSupport() == true) {
           Vibration.vibrate(pattern: _vibrationPattern); 
      } else {
           Vibration.vibrate(duration: 1000); 
      }
  }

  void _stopAlarmSound() {
    FlutterRingtonePlayer().stop();
    // Matikan Getaran juga
    _vibrationTimer?.cancel();
    Vibration.cancel();
  }

  // ... (Sisa kode Parsing & UI) ...

  void _parsePayload() {
    if (widget.payload == 'none' || widget.payload.isEmpty) return;
    final parts = widget.payload.split('|');
    if (parts.length >= 4) {
      setState(() {
        _notifId = int.tryParse(parts[0]) ?? 0;
        title = parts[2];
        body = parts[3];
        snoozeCount = int.tryParse(parts[4]) ?? 0;
        if (snoozeCount >= 3) {
          canSnooze = false;
          body = "Sudah ditunda 3x.\nAyo hadapi sekarang! 💪";
        }
      });
    }
  }

  void _updateTime() {
    if (mounted) {
      final now = DateTime.now();
      setState(() {
        _timeString = DateFormat('HH:mm').format(now);
        try {
          _dateString = DateFormat('EEEE, d MMMM', 'id_ID').format(now);
        } catch (e) {
          _dateString = DateFormat('EEEE, d MMMM').format(now);
        }
      });
    }
  }

  // Modifikasi Close untuk Finish Task
  void _closeLockScreen() async {
    NotificationService.isLockScreenOpen = false;
    _stopAlarmSound(); 

    try {
      if (Platform.isAndroid) {
        // Panggil Native Java/Kotlin untuk kill app & hapus history
        await platform.invokeMethod('finishAndRemoveTask');
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Fallback
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    }
  }

  void _onAction(String action) {
    _stopAlarmSound();
    NotificationService().handleActionLogic(
      action,
      widget.payload,
      closeApp: true,
    );
    _closeLockScreen();
  }

  @override
  void dispose() {
    _stopAlarmSound(); // Pastikan suara & getar mati saat dispose
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRehat = title.toLowerCase().contains("rehat");
    final String displayTitle = title.replaceAll(RegExp(r'\(Zzz.*\)'), '');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2E1065), Colors.black, Colors.black],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.alarm, color: Colors.white54, size: 30),
                      const SizedBox(height: 10),
                      Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16))),
                    ],
                  ),
                  Column(
                    children: [
                      Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w200, height: 1)),
                      Text(_dateString, style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canSnooze)
                          GestureDetector(
                            onTap: () => _onAction('snooze'),
                            child: Column(children: [
                              Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle), child: const Icon(Icons.snooze, color: Colors.white, size: 32)),
                              const SizedBox(height: 10),
                              Text("Tunda (${3 - snoozeCount})", style: const TextStyle(color: Colors.white54))
                            ]),
                          )
                        else
                          const SizedBox(width: 80),
                        GestureDetector(
                          onTap: () => _onAction('dismiss'),
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(children: [
                              Container(padding: const EdgeInsets.all(30), decoration: const BoxDecoration(color: AppTheme.accentPink, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x66EC4899), blurRadius: 30, spreadRadius: 5)]), child: Icon(isRehat ? Icons.play_arrow_rounded : Icons.check_rounded, color: Colors.white, size: 40)),
                              const SizedBox(height: 16),
                              Text(isRehat ? "LANJUT KERJA" : "MULAI REHAT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}