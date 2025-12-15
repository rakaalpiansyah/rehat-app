// File: lib/screens/alarm_lock_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:vibration/vibration.dart'; 

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
  static const List<int> _vibrationPattern = [0, 500, 500, 500, 500, 500];

  // Channel untuk mematikan app & hapus history (Kotlin/Java)
  static const platform = MethodChannel('com.rehat/task_manager');

  // Data Payload
  int _notifId = 0;
  String title = "Alarm";
  String body = "...";
  int snoozeCount = 0;
  
  // ✅ LOGIKA SNOOZE: Default true, nanti diubah di _parsePayload
  bool canSnooze = true; 

  @override
  void initState() {
    super.initState();
    _parsePayload();
    
    // 1. Matikan notifikasi sistem agar tidak bentrok
    if (_notifId != 0) {
      NotificationService().cancelNotification(_notifId);
    }

    // 2. Mainkan Suara & Getaran
    _playCustomAlarmSound();
    _startVibration(); 

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
      FlutterRingtonePlayer().playAlarm(
        looping: true, 
        volume: 1.0, 
        asAlarm: true, 
      );
    } else {
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
    final bool isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true; 
    
    if (isVibrationEnabled && await Vibration.hasVibrator() == true) {
        _triggerVibrate();
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
    _vibrationTimer?.cancel();
    Vibration.cancel();
  }

  // ✅ LOGIKA PARSING SNOOZE
  void _parsePayload() {
    if (widget.payload == 'none' || widget.payload.isEmpty) return;
    final parts = widget.payload.split('|');
    if (parts.length >= 4) {
      setState(() {
        _notifId = int.tryParse(parts[0]) ?? 0;
        title = parts[2];
        body = parts[3];
        snoozeCount = int.tryParse(parts[4]) ?? 0;
        canSnooze = true;
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

  // Close Screen (Tanpa Await agar tidak crash)
  void _closeLockScreen() async {
    NotificationService.isLockScreenOpen = false;
    _stopAlarmSound(); 

    try {
      if (Platform.isAndroid) {
        platform.invokeMethod('finishAndRemoveTask');
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Error closing app: $e");
      if (mounted) Navigator.of(context).pop();
    }
  }

  // Action Handler (Async agar logic selesai dulu)
  void _onAction(String action) async {
    _stopAlarmSound();
    
    await NotificationService().handleActionLogic(
      action,
      widget.payload,
      closeApp: true, 
    );
    
    _closeLockScreen();
  }

  @override
  void dispose() {
    _stopAlarmSound();
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
                  // --- BAGIAN HEADER & BODY TEXT ---
                  Column(
                    children: [
                      const Icon(Icons.alarm, color: Colors.white54, size: 30),
                      const SizedBox(height: 10),
                      Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16))),
                    ],
                  ),
                  
                  // --- BAGIAN JAM BESAR ---
                  Column(
                    children: [
                      Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w200, height: 1)),
                      Text(_dateString, style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  // --- BAGIAN TOMBOL ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      // ✅ LOGIKA POSISI:
                      // Jika Snooze Aktif -> Tombol dipisah kiri & kanan (SpaceBetween)
                      // Jika Snooze Mati -> Tombol Dismiss di tengah (Center)
                      mainAxisAlignment: canSnooze ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                      children: [
                        
                        // 1. Tombol SNOOZE (Hanya muncul jika canSnooze = true)
                        if (canSnooze)
                          GestureDetector(
                            onTap: () => _onAction('snooze'),
                            child: Column(children: [
                              Container(
                                padding: const EdgeInsets.all(20), 
                                decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle), 
                                child: const Icon(Icons.snooze, color: Colors.white, size: 32)
                              ),
                              const SizedBox(height: 10),
                              const Text("TUNDA",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)) 
                            ]),
                          ),
                          // Tidak perlu 'else SizedBox' lagi agar tombol Dismiss otomatis ke tengah
                        
                        // 2. Tombol DISMISS (Selalu Muncul)
                        GestureDetector(
                          onTap: () => _onAction('dismiss'),
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(children: [
                              Container(
                                padding: const EdgeInsets.all(30), 
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentPink, 
                                  shape: BoxShape.circle, 
                                  boxShadow: [BoxShadow(color: Color(0x66EC4899), blurRadius: 30, spreadRadius: 5)]
                                ), 
                                child: Icon(isRehat ? Icons.play_arrow_rounded : Icons.check_rounded, color: Colors.white, size: 40)
                              ),
                              const SizedBox(height: 16),
                              Text(isRehat ? "MULAI REHAT" : "LANJUT KERJA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2))
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