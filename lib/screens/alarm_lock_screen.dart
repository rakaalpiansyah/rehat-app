import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Import Service (Singleton) untuk kontrol stop
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

  // Channel untuk mematikan app & hapus history (Android Native)
  static const platform = MethodChannel('com.rehat/task_manager');

  // Data Payload
  int _notifId = 0;
  // ignore: unused_field
  String _dbId = 'none';
  String title = "Alarm";
  String body = "...";
  int snoozeCount = 0;
  // ignore: unused_field
  int _nextDuration = 0;
  Timer? _autoCloseTimer;
  bool canSnooze = true;

  @override
  void initState() {
    super.initState();
    _parsePayload();

    // 1. Matikan notifikasi pop-up di status bar (jika ada) 
    // agar user fokus ke layar penuh ini.
    // Suara & Getaran TETAP JALAN dari Service, tidak di-stop di sini.
    if (_notifId != 0) {
      NotificationService().cancelNotification(_notifId);
    }

    // 2. Setup UI (Jam & Animasi)
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _autoCloseTimer = Timer(const Duration(seconds: 20), () {
       debugPrint("⌛ LockScreen Timeout: Menutup layar otomatis.");
       _closeLockScreen();
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  // --- PARSING PAYLOAD ---
  void _parsePayload() {
    if (widget.payload == 'none' || widget.payload.isEmpty) return;
    try {
      final parts = widget.payload.split('|');
      if (parts.length >= 6) {
        setState(() {
          _notifId = int.tryParse(parts[0]) ?? 0;
          _dbId = parts[1];
          title = parts[2];
          body = parts[3];
          snoozeCount = int.tryParse(parts[4]) ?? 0;
          _nextDuration = int.tryParse(parts[5]) ?? 0;
          
          // Logic: Jika ini adalah notifikasi "Selesai", matikan snooze
          if (title.contains("Selesai")) {
            canSnooze = false;
          } else {
            canSnooze = true;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Error parsing payload di LockScreen: $e");
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

  // --- ACTION HANDLERS ---

  void _onAction(String action) async {
    // Panggil Service untuk stop suara & handle logic (update DB, schedule next, dll)
    await NotificationService().handleActionLogic(
      action,
      widget.payload,
      closeApp: false, 
    );
    
    // Tutup Layar
    _closeLockScreen();
  }

  void _closeLockScreen() async {
    _autoCloseTimer?.cancel();
    NotificationService.isLockScreenOpen = false;
    
    // Pastikan suara mati (safety net jika handleActionLogic belum selesai)
    await NotificationService().stopAlarmSound(); 

    try {
      if (Platform.isAndroid) {
        // Kill Activity agar keluar dari mode Lock Screen
        try {
          await platform.invokeMethod('finishAndRemoveTask');
        } on PlatformException {
           SystemNavigator.pop(); 
        }
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Error closing app: $e");
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Safety: Stop suara jika layar ditutup paksa/back button
    NotificationService().stopAlarmSound();
    _timer.cancel();
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Membersihkan teks judul
    final String displayTitle = title.replaceAll(RegExp(r'\(Zzz.*\)'), '');
    final bool isRehatPhase = title.toLowerCase().contains("rehat");
    final bool isFinish = title.toLowerCase().contains("selesai");

    // Tentukan Icon & Teks Tombol Utama
    IconData mainIcon;
    String mainText;

    if (isFinish) {
      mainIcon = Icons.check_circle_outline;
      mainText = "SELESAI";
    } else if (isRehatPhase) {
      mainIcon = Icons.play_arrow_rounded;
      mainText = "MULAI REHAT";
    } else {
      mainIcon = Icons.work_outline_rounded;
      mainText = "LANJUT KERJA";
    }

    return PopScope(
      canPop: false, // Cegah tombol back fisik
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
                  colors: [Color(0xFF2E1065), Colors.black, Colors.black],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. HEADER & BODY
                  Column(
                    children: [
                      const Icon(Icons.alarm, color: Colors.white54, size: 30),
                      const SizedBox(height: 10),
                      Text(
                        displayTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),

                  // 2. JAM BESAR
                  Column(
                    children: [
                      Text(
                        _timeString,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 80,
                            fontWeight: FontWeight.w200,
                            height: 1),
                      ),
                      Text(
                        _dateString,
                        style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  // 3. TOMBOL AKSI
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: canSnooze
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      children: [
                        // Tombol SNOOZE (Kiri)
                        if (canSnooze)
                          GestureDetector(
                            onTap: () => _onAction('snooze'),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: Color(0x1AFFFFFF), 
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.snooze,
                                      color: Colors.white, size: 32),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "TUNDA",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2),
                                ),
                              ],
                            ),
                          ),

                        // Tombol DISMISS / UTAMA (Kanan/Tengah)
                        GestureDetector(
                          onTap: () => _onAction('dismiss'),
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accentPink,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Color(0x66EC4899),
                                          blurRadius: 30,
                                          spreadRadius: 5)
                                    ],
                                  ),
                                  child: Icon(mainIcon,
                                      color: Colors.white, size: 40),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  mainText,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2),
                                ),
                              ],
                            ),
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