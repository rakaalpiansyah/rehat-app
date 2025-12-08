import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/notification_service.dart'; // Pastikan path benar
// import '../core/theme.dart'; 

class ActiveFocusScreen extends StatefulWidget {
  // Data ini didapat dari Slider di Home Screen
  final int totalMinutes;
  final int intervalMinutes;
  final int breakMinutes;

  const ActiveFocusScreen({
    super.key,
    required this.totalMinutes,
    required this.intervalMinutes,
    required this.breakMinutes,
  });

  @override
  State<ActiveFocusScreen> createState() => _ActiveFocusScreenState();
}

class _ActiveFocusScreenState extends State<ActiveFocusScreen> {
  Timer? _timer;

  // Variabel Hitung Mundur
  late int _remainingTotalSeconds;    
  late int _remainingIntervalSeconds; 
  late int _remainingBreakSeconds;    
  late int _totalSecondsInitial;      

  bool _isPaused = false;
  bool _isBreakTime = false; 

  @override
  void initState() {
    super.initState();
    // Konversi Menit ke Detik
    _totalSecondsInitial = widget.totalMinutes * 60;
    _remainingTotalSeconds = _totalSecondsInitial;
    
    _remainingIntervalSeconds = widget.intervalMinutes * 60;
    _remainingBreakSeconds = widget.breakMinutes * 60;

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_isBreakTime) {
          // --- LOGIKA SAAT ISTIRAHAT ---
          if (_remainingBreakSeconds > 0) {
            _remainingBreakSeconds--;
          } else {
            _endBreak(); // Balik Kerja
          }
        } else {
          // --- LOGIKA SAAT FOKUS ---
          if (_remainingTotalSeconds > 0) {
            _remainingTotalSeconds--;
            _remainingIntervalSeconds--;
          } else {
            _finishSession(); // Selesai Total
          }

          // Cek apakah interval habis?
          if (_remainingIntervalSeconds <= 0 && _remainingTotalSeconds > 0) {
            _startBreak();
          }
        }
      });
    });
  }

  // 1. Masuk Mode Istirahat
  void _startBreak() {
    setState(() {
      _isBreakTime = true;
      _remainingBreakSeconds = widget.breakMinutes * 60; // Reset waktu rehat
    });

    // Panggil Notifikasi INSTANT (Metode 1 di Service)
    NotificationService().showNotification(
      "Saatnya Rehat! ☕", 
      "Anda sudah fokus selama ${widget.intervalMinutes} menit. Istirahat sejenak."
    );
  }

  // 2. Selesai Istirahat
  void _endBreak() {
    setState(() {
      _isBreakTime = false;
      _remainingIntervalSeconds = widget.intervalMinutes * 60; // Reset waktu fokus
    });

    NotificationService().showNotification(
      "Istirahat Selesai 🚀", 
      "Energi sudah terisi? Mari lanjut fokus!"
    );
  }

  // 3. Sesi Habis Total
  void _finishSession() {
    _timer?.cancel();
    NotificationService().showNotification(
      "Sesi Selesai! 🎉", 
      "Target ${widget.totalMinutes} menit tercapai. Kerja bagus!"
    );
    Navigator.pop(context); 
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = _isBreakTime ? Colors.green : const Color(0xFF6B4EFF);
    final Color secondaryColor = _isBreakTime ? Colors.green.shade50 : const Color(0xFFE0E0E0);
    final String statusText = _isBreakTime ? "Mode Istirahat Aktif" : "Mode Fokus Aktif";

    double percent = 1.0 - (_remainingTotalSeconds / _totalSecondsInitial);
    percent = percent.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: BackButton(color: Colors.black, onPressed: () {
          _timer?.cancel();
          Navigator.pop(context);
        }),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Sesi Aktif", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(statusText, style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),
            CircularPercentIndicator(
              radius: 120.0,
              lineWidth: 15.0,
              percent: percent,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isBreakTime ? Icons.spa : Icons.access_time, color: primaryColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _isBreakTime 
                        ? _formatTime(_remainingBreakSeconds) 
                        : _formatTime(_remainingTotalSeconds),
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  Text(
                    _isBreakTime ? "Sisa Waktu Rehat" : "Sisa Waktu Total",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              progressColor: primaryColor,
              backgroundColor: secondaryColor,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animateFromLastPercent: true,
            ),
            const Spacer(),
            
            // Kartu Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,5))]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10), 
                    decoration: BoxDecoration(
                      color: _isBreakTime ? Colors.green[50] : Colors.pink[50], 
                      borderRadius: BorderRadius.circular(12)
                    ), 
                    child: Icon(
                      _isBreakTime ? Icons.check_circle : Icons.timer_outlined, 
                      color: _isBreakTime ? Colors.green : Colors.pinkAccent
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(
                          _isBreakTime ? "Kembali Fokus Dalam" : "Istirahat Berikutnya", 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ), 
                        Text(
                          _isBreakTime ? "Istirahatlah sejenak" : "Pengingat akan muncul", 
                          style: const TextStyle(fontSize: 12, color: Colors.grey)
                        )
                      ]
                    )
                  ),
                  Text(
                    _isBreakTime 
                        ? _formatTime(_remainingBreakSeconds) 
                        : _formatTime(_remainingIntervalSeconds),
                    style: TextStyle(
                      color: _isBreakTime ? Colors.green : Colors.pinkAccent, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 18
                    )
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Tombol Kontrol
            Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: () => setState(() => _isPaused = !_isPaused), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: Colors.black, 
                    elevation: 0, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.grey))
                  ), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    child: Text(_isPaused ? "Lanjutkan" : "Jeda")
                  )
                )),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  }, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, 
                    foregroundColor: Colors.white, 
                    elevation: 0, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ), 
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16), 
                    child: Text("Hentikan")
                  )
                )),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}