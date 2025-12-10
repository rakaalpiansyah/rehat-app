// File: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // 1. HEADER (Tetap Tinggi 260)
          _buildHeaderSection(),

          // 2. CONTENT SECTION (Dibuat Fleksibel)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // BAGIAN YANG BISA DI-SCROLL
                  // Kita bungkus konten kartu dengan Expanded + SingleChildScrollView
                  // Agar jika layar pendek, user bisa scroll ke bawah.
                  Expanded(
                    child: SingleChildScrollView(
                      // BouncingScrollPhysics memberi efek pantul (bagus di iOS/Android modern)
                      physics: const BouncingScrollPhysics(), 
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

                          const SizedBox(height: 14),

                          // Kartu 1
                          _ConfigCard(
                            icon: Icons.timelapse_rounded,
                            title: "Total Sesi",
                            subtitle: "Durasi kerja total",
                            value: totalFocus,
                            min: 30,
                            max: 180,
                            unit: "m",
                            primaryColor: const Color(0xFF7F56D9),
                            lightColor: const Color(0xFFF4EBFF),
                            onChanged: (v) => setState(() => totalFocus = v),
                          ),

                          const SizedBox(height: 14),

                          // Kartu 2
                          _ConfigCard(
                            icon: Icons.timer_outlined,
                            title: "Interval Fokus",
                            subtitle: "Waktu fokus",
                            value: intervalFocus,
                            min: 1,
                            max: 60,
                            unit: "m",
                            primaryColor: const Color(0xFF2E90FA),
                            lightColor: const Color(0xFFEFF8FF),
                            onChanged: (v) => setState(() => intervalFocus = v),
                          ),

                          const SizedBox(height: 14),

                          // Kartu 3
                          _ConfigCard(
                            icon: Icons.coffee_outlined,
                            title: "Istirahat",
                            subtitle: "Waktu rehat",
                            value: breakDuration,
                            min: 1,
                            max: 15,
                            unit: "m",
                            primaryColor: const Color(0xFFF63D68),
                            lightColor: const Color(0xFFFFF0F3),
                            onChanged: (v) => setState(() => breakDuration = v),
                          ),
                          
                          // Tambahan padding di bawah agar kartu terakhir tidak kepotong
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // 3. TOMBOL MULAI (Tetap di Bawah)
                  // Saya hapus Spacer() dan letakkan tombol di luar ScrollView
                  // agar tombol selalu terlihat di bawah layar.
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4361EE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFF4361EE).withOpacity(0.4),
                      ),
                      child: const Text(
                        "Mulai Sekarang",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24), // Jarak aman bawah
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === HEADER (TIDAK BERUBAH) ===
  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      height: 260, 
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0), 
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), 
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x406B4EFF),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Selamat Malam,",
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    SizedBox(height: 4),
                    Text("Siap Produktif?",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF4361EE)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.show_chart_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Target harian 80% tercapai!",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
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

// === KARTU KONFIGURASI (UKURAN BESAR/NORMAL) ===
class _ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color primaryColor;
  final Color lightColor;
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
    required this.lightColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding diperbesar ke 20 agar kartu terlihat 'gemuk' & lega
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Radius lebih smooth
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
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
              // Icon Box Besar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryColor, size: 28), // Icon diperbesar
              ),
              const SizedBox(width: 16),
              
              // Teks Judul & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, // Font judul diperbesar
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500])), // Font subtitle diperbesar
                  ],
                ),
              ),

              // Badge Nilai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${value.toInt()} $unit",
                  style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14), // Font nilai diperbesar
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12), // Jarak ke slider lebih lega
          
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: lightColor,
              trackHeight: 6.0, // Track slider lebih tebal
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10.0, elevation: 3), // Tombol geser lebih besar
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
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