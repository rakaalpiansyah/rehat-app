// File: lib/screens/nav_bar.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../core/theme.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({super.key});

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _index = 0;
  
  // Pastikan class screen ini sudah ada atau buat placeholder sementara
  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(), // Pastikan file ini ada
    const SettingsScreen(), // Pastikan file ini ada
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        // Dekorasi border atas tipis agar terlihat rapi (Clean UI)
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.textGrey.withOpacity(0.1))),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          
          // Styling Warna dari Theme.dart
          backgroundColor: Colors.white,
          elevation: 0, // Hilangkan shadow bawaan agar flat
          selectedItemColor: AppTheme.primaryPurple, // Ungu (0xFF8B5CF6)
          unselectedItemColor: AppTheme.textGrey,    // Abu-abu (0xFF9CA3AF)
          
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          
          // Styling Font agar konsisten dengan Poppins
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), 
              label: "Beranda"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded), // Icon kalender yang lebih modern
              label: "Jadwal"
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), 
              label: "Pengaturan"
            ),
          ],
        ),
      ),
    );
  }
}