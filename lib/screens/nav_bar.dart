// File: lib/screens/nav_bar.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../core/theme.dart'; // Import AppTheme

class MainNavBar extends StatefulWidget {
  const MainNavBar({super.key});

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _index = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const SettingsScreen(),
  ];

  // Helper untuk membuat Icon dengan warna Gradient (Sama persis Header Home)
  Widget _gradientIcon(IconData icon) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return AppTheme.headerGradient.createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Warna Item Tidak Aktif (Abu Terang di Dark Mode, Abu Gelap di Light Mode)
    final Color unselectedColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    // 2. Warna Teks Item Aktif (Ungu Muda di Dark Mode, Ungu Tua di Light Mode)
    // Ini kuncinya agar terbaca jelas di background gelap
    final Color selectedTextColor = isDark 
        ? AppTheme.primaryPurple // Lebih terang (0xFF8B5CF6)
        : const Color(0xFF7209B7); // Lebih gelap (dari gradient)

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        // Dekorasi border atas tipis
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1))),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),

          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          
          // Gunakan warna teks adaptif yang sudah kita buat
          selectedItemColor: selectedTextColor, 
          
          // Gunakan warna unselected adaptif
          unselectedItemColor: unselectedColor,

          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,

          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),

          items: [
            // ITEM 1: BERANDA
            BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined), 
                activeIcon: _gradientIcon(Icons.home_filled), // Icon tetap Gradient
                label: "Beranda"),

            // ITEM 2: JADWAL
            BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_today_outlined),
                activeIcon: _gradientIcon(Icons.calendar_today_rounded),
                label: "Jadwal"),

            // ITEM 3: PENGATURAN
            BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: _gradientIcon(Icons.settings_rounded),
                label: "Pengaturan"),
          ],
        ),
      ),
    );
  }
}