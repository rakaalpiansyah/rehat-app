// File: lib/screens/alarm_lock_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../core/theme.dart'; // Ganti dari 'schedule_screen.dart' ke 'core/theme.dart'
import 'package:flutter/services.dart';

class AlarmLockScreen extends StatefulWidget {
  final String payload; // "Id|Title|Body|SnoozeCount|NextDuration"

  const AlarmLockScreen({super.key, required this.payload});

  @override
  State<AlarmLockScreen> createState() => _AlarmLockScreenState();
}

class _AlarmLockScreenState extends State<AlarmLockScreen> with SingleTickerProviderStateMixin {
  late String _timeString, _dateString;
  late Timer _timer;
  static const platform = MethodChannel('com.example.rehat_app/app_control');
  String title = "Alarm";
  String body = "...";
  int snoozeCount = 0;
  bool canSnooze = true;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _parsePayload();
    
    // Timer Update Jam
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());

    // Animasi Tombol Stop
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _parsePayload() {
    // Cek agar tidak error jika payload kosong/"none"
    if (widget.payload == 'none' || widget.payload.isEmpty) return;

    final parts = widget.payload.split('|');
    if (parts.length >= 4) {
      setState(() {
        title = parts[1];
        body = parts[2];
        snoozeCount = int.tryParse(parts[3]) ?? 0;
        
        // Logika tampilan jika sudah limit snooze
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
        _dateString = DateFormat('EEEE, d MMMM').format(now);
      });
    }
  }

  // --- ACTIONS ---

  // ✅ LOGIKA NAVIGASI BERSIH
  void _closeLockScreen() async {
    NotificationService.isLockScreenOpen = false; 

    try {
      // Panggil kode native Java
      await platform.invokeMethod('moveTaskToBack'); 
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print("Gagal memindahkan task ke belakang: ${e.message}");
      // Fallback: tutup secara normal jika native gagal
      if (mounted) {
        Navigator.of(context).pop(); 
      }
    }
  }

  void _onSnooze() {
    NotificationService().triggerActionManual('snooze', widget.payload);
    _closeLockScreen(); // ✅ Panggil fungsi tutup yang baru
  }

  void _onDismiss() {
    NotificationService().triggerActionManual('dismiss', widget.payload);
    _closeLockScreen(); // ✅ Panggil fungsi tutup yang baru
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PopScope: Mencegah tombol BACK fisik menutup alarm
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, 
                  end: Alignment.bottomCenter, 
                  colors: [Color(0xFF2E1065), Colors.black, Colors.black]
                )
              )
            ),
            
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. INFO HEADER
                  Column(
                    children: [
                      const Icon(Icons.alarm, color: Colors.white54, size: 30),
                      const SizedBox(height: 10),
                      Text(
                        title.replaceAll(RegExp(r'\(Zzz.*\)'), ''), // Hapus text (Zzz..)
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
                    ],
                  ),
                  
                  // 2. JAM BESAR
                  Column(
                    children: [
                      Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w200, height: 1)),
                      Text(_dateString, 
                        // Ganti ScheduleTheme.primaryPurple
                        style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 18, fontWeight: FontWeight.bold)), 
                    ],
                  ),
                  
                  // 3. TOMBOL AKSI
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // KIRI: TOMBOL SNOOZE
                        if (canSnooze)
                          GestureDetector(
                            onTap: _onSnooze,
                            child: Column(children: [
                               Container(
                                 padding: const EdgeInsets.all(20), 
                                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), 
                                 child: const Icon(Icons.snooze, color: Colors.white, size: 32)
                               ),
                               const SizedBox(height: 10),
                               Text("Tunda (${3 - snoozeCount})", style: const TextStyle(color: Colors.white54))
                            ]),
                          )
                        else 
                          const SizedBox(width: 80), 
              
                        // KANAN: TOMBOL SELESAI
                        GestureDetector(
                          onTap: _onDismiss,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(children: [
                               Container(
                                 padding: const EdgeInsets.all(30), 
                                 decoration: const BoxDecoration(
                                    // Ganti ScheduleTheme.accentPink
                                    color: AppTheme.accentPink, 
                                    shape: BoxShape.circle, 
                                    boxShadow: [BoxShadow(color: Color(0x66EC4899), blurRadius: 30, spreadRadius: 5)]
                                 ), 
                                 child: const Icon(Icons.check_rounded, color: Colors.white, size: 40)
                               ),
                               const SizedBox(height: 16),
                               Text(title.contains("Rehat") ? "SIAP KERJA" : "MULAI REHAT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2))
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