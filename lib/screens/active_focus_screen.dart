import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/active_focus_notification_service.dart';

class ActiveFocusScreen extends StatefulWidget {
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

class _ActiveFocusScreenState extends State<ActiveFocusScreen> with WidgetsBindingObserver {
  Timer? _timer;
  late int _remainingTotalSeconds;    
  late int _remainingIntervalSeconds; 
  late int _remainingBreakSeconds;    
  late int _totalSecondsInitial;      

  bool _isPaused = false;
  bool _isBreakTime = false; 

  // Instance Service (Versi Sederhana)
  final ActiveFocusNotificationService _focusNotificationService = ActiveFocusNotificationService();
  
  // ❌ StreamSubscription Dihapus karena tidak ada tombol untuk didengar

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _totalSecondsInitial = widget.totalMinutes * 60;
    _remainingTotalSeconds = _totalSecondsInitial;
    _remainingIntervalSeconds = widget.intervalMinutes * 60;
    _remainingBreakSeconds = widget.breakMinutes * 60;

    // ❌ _initNotificationListener() Dihapus

    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // ❌ _notificationSubscription?.cancel() Dihapus
    super.dispose();
  }

  // ❌ _handleSnooze dan _handleDismiss Dihapus total

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      if (!mounted) return;

      setState(() {
        if (_isBreakTime) {
          if (_remainingBreakSeconds > 0) {
            _remainingBreakSeconds--;
          } else {
            _endBreak(); 
          }
        } else {
          if (_remainingTotalSeconds > 0) {
            _remainingTotalSeconds--;
            _remainingIntervalSeconds--;
          } else {
            _finishSession(); 
          }
          if (_remainingIntervalSeconds <= 0 && _remainingTotalSeconds > 0) {
            _startBreak();
          }
        }
      });
    });
  }
  
  void _startBreak() {
    setState(() {
      _isBreakTime = true;
      _remainingBreakSeconds = widget.breakMinutes * 60; 
    });
    // Panggil notifikasi tanpa parameter nextDuration
    _focusNotificationService.showInstantFocusNotification(
      "Saatnya Rehat! ☕", 
      "Fokus ${widget.intervalMinutes} menit selesai. Istirahat dulu!",
    );
  }

  void _endBreak() {
    setState(() {
      _isBreakTime = false;
      _remainingIntervalSeconds = widget.intervalMinutes * 60; 
    });
    _focusNotificationService.showInstantFocusNotification(
      "Istirahat Selesai 🚀", 
      "Energi terisi? Mari lanjut fokus!",
    );
  }

  void _finishSession() {
    _timer?.cancel();
    _focusNotificationService.showInstantFocusNotification(
      "Sesi Selesai! 🎉", 
      "Target ${widget.totalMinutes} menit tercapai. Kerja bagus!",
    ); 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Sesi Selesai"),
        content: const Text("Selamat! Anda telah menyelesaikan target fokus hari ini."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: const Text("Mantap"),
          )
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
  
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = _isBreakTime ? Colors.green : const Color(0xFF8B5CF6);
    final Color secondaryColor = _isBreakTime ? Colors.green.shade50 : const Color(0xFFF3F0FF);
    final String statusText = _isBreakTime ? "Mode Istirahat" : "Mode Fokus";
    double percent = 0.0;
    if (_totalSecondsInitial > 0) {
      percent = 1.0 - (_remainingTotalSeconds / _totalSecondsInitial);
    }
    percent = percent.clamp(0.0, 1.0);

    return Scaffold(
       backgroundColor: Colors.white,
       appBar: AppBar(
         leading: BackButton(color: Colors.black, onPressed: () { _showExitConfirmation(); }),
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
                  Icon(_isBreakTime ? Icons.coffee_rounded : Icons.bolt_rounded, color: primaryColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _isBreakTime 
                        ? _formatTime(_remainingBreakSeconds)
                        : _formatTime(_remainingTotalSeconds),
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  Text(
                    _isBreakTime ? "Waktu Rehat" : "Total Tersisa",
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
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
            // Kartu Info Detail
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0,10))]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12), 
                    decoration: BoxDecoration(
                      color: secondaryColor, 
                      borderRadius: BorderRadius.circular(12)
                    ), 
                    child: Icon(
                      _isBreakTime ? Icons.timer_outlined : Icons.hourglass_bottom_rounded, 
                      color: primaryColor
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(
                          _isBreakTime ? "Lanjut Fokus Dalam" : "Rehat Berikutnya", 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                        ), 
                        Text(
                          _isBreakTime 
                            ? "${_formatTime(_remainingBreakSeconds)} lagi"
                            : "${_formatTime(_remainingIntervalSeconds)} lagi", 
                          style: const TextStyle(fontSize: 12, color: Colors.grey)
                        )
                      ]
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
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ), 
                  child: Text(_isPaused ? "Lanjutkan" : "Jeda", style: const TextStyle(fontWeight: FontWeight.bold))
                )),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(
                  onPressed: _showExitConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE4E6), 
                    foregroundColor: Colors.red, 
                    elevation: 0, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ), 
                  child: const Text("Hentikan", style: TextStyle(fontWeight: FontWeight.bold))
                )),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Hentikan Sesi?"),
        content: const Text("Progres sesi ini akan hilang."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _timer?.cancel();
            Navigator.pop(context);
          }, child: const Text("Ya, Hentikan", style: TextStyle(color: Colors.red))),
        ],
      )
    );
  }
}