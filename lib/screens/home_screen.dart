// File: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // Pastikan package intl sudah ada
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

  // Helper untuk mendapatkan sapaan waktu
  String get greeting {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi,';
    if (hour < 17) return 'Selamat Siang,';
    return 'Selamat Malam,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Background lebih bersih
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernHeader(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Konfigurasi Sesi",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Kartu 1: Total Fokus
                  _ModernSliderCard(
                    icon: Icons.timelapse_rounded,
                    title: "Total Sesi Fokus",
                    subtitle: "Durasi kerja keseluruhan",
                    value: totalFocus,
                    min: 30,
                    max: 300,
                    unit: "menit",
                    color: const Color(0xFF6B4EFF), // Ungu
                    onChanged: (v) => setState(() => totalFocus = v),
                  ),
                  const SizedBox(height: 16),

                  // Kartu 2: Interval
                  _ModernSliderCard(
                    icon: Icons.timer_rounded,
                    title: "Interval Fokus",
                    subtitle: "Waktu hingga pengingat",
                    value: intervalFocus,
                    min: 1,
                    max: 120,
                    unit: "menit",
                    color: const Color(0xFF2E85FF), // Biru
                    onChanged: (v) => setState(() => intervalFocus = v),
                  ),
                  const SizedBox(height: 16),

                  // Kartu 3: Durasi Istirahat
                  _ModernSliderCard(
                    icon: Icons.coffee_rounded,
                    title: "Durasi Istirahat",
                    subtitle: "Waktu rehat terpandu",
                    value: breakDuration,
                    min: 1,
                    max: 30,
                    unit: "menit",
                    color: const Color(0xFFFF4757), // Merah/Pink Modern
                    onChanged: (v) => setState(() => breakDuration = v),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Tombol Mulai yang Modern
                  _buildStartButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET: Header Modern dengan Glass Effect Style
  Widget _buildModernHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x406B4EFF),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Siap Produktif?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              // Avatar / Profile Icon dengan Border Putih
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF6B4EFF)),
                ),
              )
            ],
          ),
          const SizedBox(height: 25),
          // Quick Stats Row (Dekorasi)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Target harian Anda 80% tercapai!",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.7), size: 12),
              ],
            ),
          )
        ],
      ),
    );
  }

  // WIDGET: Tombol Mulai Besar
  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppTheme.primaryGradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x606B4EFF),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
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
          child: const Center(
            child: Text(
              "Mulai Sesi Fokus",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// WIDGET KHUSUS: Kartu Slider Modern
class _ModernSliderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color color;
  final Function(double) onChanged;

  const _ModernSliderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Kartu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              // Display Nilai Besar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${value.toInt()} $unit",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Custom Slider Theme
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.1),
              trackHeight: 8.0, // Track lebih tebal
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0, elevation: 4),
              overlayColor: color.withOpacity(0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
              // Membuat track menjadi rounded di ujung
              trackShape: const RoundedRectSliderTrackShape(), 
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