// File: lib/screens/active_focus_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/active_focus_notification_service.dart';
import '../core/theme.dart';

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

class _ActiveFocusScreenState extends State<ActiveFocusScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  late int _remainingTotalSeconds;
  late int _remainingIntervalSeconds;
  late int _remainingBreakSeconds;
  late int _totalSecondsInitial;

  bool _isPaused = false;
  bool _isBreakTime = false;

  final ActiveFocusNotificationService _focusNotificationService =
      ActiveFocusNotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _totalSecondsInitial = widget.totalMinutes * 60;
    _remainingTotalSeconds = _totalSecondsInitial;
    _remainingIntervalSeconds = widget.intervalMinutes * 60;
    _remainingBreakSeconds = widget.breakMinutes * 60;

    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || !mounted) return;

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

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Sesi Selesai"),
        content: const Text(
            "Selamat! Anda telah menyelesaikan target fokus hari ini."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup Dialog
              Navigator.pop(context); // Kembali ke Home
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hentikan Sesi?"),
        content: const Text("Progres sesi ini akan hilang."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _timer?.cancel();
              Navigator.pop(context);
            },
            child: const Text("Ya, Hentikan",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryColor =
        _isBreakTime ? Colors.green : AppTheme.primaryPurple;
    final String statusText = _isBreakTime ? "Mode Istirahat" : "Mode Fokus";
    final Color textColor = isDark ? Colors.white : Colors.black;

    double percent = 0.0;
    if (_totalSecondsInitial > 0) {
      percent = 1.0 - (_remainingTotalSeconds / _totalSecondsInitial);
    }
    percent = percent.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(
          color: textColor,
          onPressed: _showExitConfirmation,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sesi Aktif",
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),

            // --- 1. CIRCULAR TIMER ---
            _FocusTimerIndicator(
              percent: percent,
              isBreakTime: _isBreakTime,
              primaryColor: primaryColor,
              timeString: _isBreakTime
                  ? _formatTime(_remainingBreakSeconds)
                  : _formatTime(_remainingTotalSeconds),
              isDark: isDark,
            ),

            const Spacer(),

            // --- 2. INFO CARD ---
            _InfoCard(
              isBreakTime: _isBreakTime,
              isDark: isDark,
              primaryColor: primaryColor,
              timeRemaining: _isBreakTime
                  ? _formatTime(_remainingBreakSeconds)
                  : _formatTime(_remainingIntervalSeconds),
            ),

            const SizedBox(height: 40),

            // --- 3. CONTROLS ---
            _ControlButtons(
              isPaused: _isPaused,
              isDark: isDark,
              textColor: textColor,
              onPauseToggle: () => setState(() => _isPaused = !_isPaused),
              onStop: _showExitConfirmation,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// === WIDGET 1: TIMER CIRCLE ===
class _FocusTimerIndicator extends StatelessWidget {
  final double percent;
  final bool isBreakTime;
  final Color primaryColor;
  final String timeString;
  final bool isDark;

  const _FocusTimerIndicator({
    required this.percent,
    required this.isBreakTime,
    required this.primaryColor,
    required this.timeString,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Logic warna background circle
    final Color bgColor = isBreakTime
        ? (isDark ? const Color(0x334CAF50) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0x337209B7) : const Color(0xFFF3F0FF));

    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;

    return CircularPercentIndicator(
      radius: 120.0,
      lineWidth: 15.0,
      percent: percent,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isBreakTime ? Icons.coffee_rounded : Icons.bolt_rounded,
            color: primaryColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          Text(
            isBreakTime ? "Waktu Rehat" : "Total Tersisa",
            style: TextStyle(color: subTextColor, fontSize: 14),
          ),
        ],
      ),
      progressColor: primaryColor,
      backgroundColor: bgColor,
      circularStrokeCap: CircularStrokeCap.round,
      animation: true,
      animateFromLastPercent: true,
    );
  }
}

// === WIDGET 2: INFO CARD ===
class _InfoCard extends StatelessWidget {
  final bool isBreakTime;
  final bool isDark;
  final Color primaryColor;
  final String timeRemaining;

  const _InfoCard({
    required this.isBreakTime,
    required this.isDark,
    required this.primaryColor,
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;

    // Background icon kecil
    final Color iconBgColor = isBreakTime
        ? (isDark ? const Color(0x334CAF50) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0x337209B7) : const Color(0xFFF3F0FF));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x4D000000) : const Color(0x0D000000),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isBreakTime ? Icons.timer_outlined : Icons.hourglass_bottom_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBreakTime ? "Lanjut Fokus Dalam" : "Rehat Berikutnya",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  "$timeRemaining lagi",
                  style: TextStyle(fontSize: 12, color: subTextColor),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === WIDGET 3: CONTROL BUTTONS ===
class _ControlButtons extends StatelessWidget {
  final bool isPaused;
  final bool isDark;
  final Color textColor;
  final VoidCallback onPauseToggle;
  final VoidCallback onStop;

  const _ControlButtons({
    required this.isPaused,
    required this.isDark,
    required this.textColor,
    required this.onPauseToggle,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tombol Pause / Resume
        Expanded(
          child: ElevatedButton(
            onPressed: onPauseToggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: textColor,
              elevation: 0,
              side: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              isPaused ? "Lanjutkan" : "Jeda",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Tombol Stop
        Expanded(
          child: ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
              // Merah muda adaptif
              backgroundColor: isDark
                  ? const Color(0x26F44336) // Red with opacity
                  : const Color(0xFFFFE4E6),
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              "Hentikan",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}