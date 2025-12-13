// File: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'active_focus_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State Values
  double totalFocus = 150;
  double intervalFocus = 50;
  double breakDuration = 9;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. HEADER
          const _HeaderSection(),

          // 2. CONTENT SECTION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Konfigurasi Sesi",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Kartu 1: Total Sesi
                          _ConfigCard(
                            icon: Icons.timelapse_rounded,
                            title: "Total Sesi",
                            subtitle: "Durasi kerja total",
                            value: totalFocus,
                            min: 30,
                            max: 180,
                            unit: "m",
                            primaryColor: AppTheme.sessionColorPrimary,
                            // Logika warna background dinamis tanpa withOpacity
                            bgColor: isDark
                                ? AppTheme.sessionColorPrimary.withAlpha(38) // ~15%
                                : AppTheme.sessionColorLight,
                            onChanged: (v) => setState(() => totalFocus = v),
                          ),

                          const SizedBox(height: 14),

                          // Kartu 2: Interval Fokus
                          _ConfigCard(
                            icon: Icons.timer_outlined,
                            title: "Interval Fokus",
                            subtitle: "Waktu fokus",
                            value: intervalFocus,
                            min: 1,
                            max: 60,
                            unit: "m",
                            primaryColor: AppTheme.intervalColorPrimary,
                            bgColor: isDark
                                ? AppTheme.intervalColorPrimary.withAlpha(38)
                                : AppTheme.intervalColorLight,
                            onChanged: (v) => setState(() => intervalFocus = v),
                          ),

                          const SizedBox(height: 14),

                          // Kartu 3: Istirahat
                          _ConfigCard(
                            icon: Icons.coffee_outlined,
                            title: "Istirahat",
                            subtitle: "Waktu rehat",
                            value: breakDuration,
                            min: 1,
                            max: 15,
                            unit: "m",
                            primaryColor: AppTheme.breakColorPrimary,
                            bgColor: isDark
                                ? AppTheme.breakColorPrimary.withAlpha(38)
                                : AppTheme.breakColorLight,
                            onChanged: (v) => setState(() => breakDuration = v),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // 3. TOMBOL MULAI
                  const SizedBox(height: 10),
                  _GradientButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveFocusScreen(
                            totalMinutes: totalFocus.toInt(),
                            intervalMinutes: intervalFocus.toInt(),
                            breakMinutes: breakDuration.toInt(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Mulai Sekarang",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === WIDGET: HEADER SECTION ===
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return "Selamat Pagi,";
    if (hour < 15) return "Selamat Siang,";
    if (hour < 19) return "Selamat Sore,";
    return "Selamat Malam,";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            // Mengganti withOpacity dengan Hex Alpha manual
            // Dark: 0.3 -> 0x4D, Light: 0.25 -> 0x40
            color: isDark ? const Color(0x4D000000) : const Color(0x40000000),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Siap Produktif?",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === WIDGET: GRADIENT BUTTON ===
class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppTheme.headerGradient,
        boxShadow: const [
          BoxShadow(
            // Color(0xFF7209B7).withOpacity(0.4) diganti Hex
            // 0.4 * 255 ~= 66 (Hex) -> 0x667209B7
            color: Color(0x667209B7),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// === WIDGET: CONFIG CARD ===
class _ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color primaryColor;
  final Color bgColor;
  final Function(double) onChanged;

  const _ConfigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.primaryColor,
    required this.bgColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            // Dark: 0.3 -> 0x4D, Light: 0.06 -> 0x0F
            color: isDark ? const Color(0x4D000000) : const Color(0x0F000000),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 16),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Nilai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${value.toInt()} $unit",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: bgColor,
              trackHeight: 6.0,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10.0,
                elevation: 3,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
              // Mengganti withOpacity(0.2) dengan withAlpha(51)
              overlayColor: primaryColor.withAlpha(51),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}