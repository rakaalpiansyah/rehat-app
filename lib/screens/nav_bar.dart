// File: lib/screens/nav_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../core/theme.dart';
import '../services/permission_helper.dart'; // ✅ 1. Import Permission Helper
import '../providers/settings_provider.dart';

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

  @override
  void initState() {
    super.initState();

    // ✅ 2. LOGIKA OTOMATIS: Cek Izin HP (Xiaomi/Samsung/Oppo/dll)
    // Dijalankan setelah frame pertama selesai agar context siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionHelper.checkAndRequestSpecialPermissions(context);
    });
  }

  // Helper Icon dengan Gradient
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Warna Item Tidak Aktif
    final Color unselectedColor =
        isDark ? Colors.grey[400]! : Colors.grey[600]!;

    // 2. Warna Teks Item Aktif
    final Color selectedTextColor =
        isDark ? AppTheme.primaryPurple : const Color(0xFF7209B7);

    // 3. Warna Border Atas
    final Color borderColor = theme.dividerColor.withAlpha(26);

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        // Dekorasi border atas tipis
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: borderColor),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            // Hentikan preview suara jika keluar dari tab Pengaturan
            if (_index == 2 && i != 2) {
              context.read<SettingsProvider>().stopPreviewSound();
            }
            setState(() => _index = i);
          },
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,

          // Warna Adaptif
          selectedItemColor: selectedTextColor,
          unselectedItemColor: unselectedColor,

          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,

          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),

          items: [
            // ITEM 1: BERANDA
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: _gradientIcon(Icons.home_filled),
              label: "Beranda",
            ),

            // ITEM 2: JADWAL
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today_outlined),
              activeIcon: _gradientIcon(Icons.calendar_today_rounded),
              label: "Jadwal",
            ),

            // ITEM 3: PENGATURAN
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: _gradientIcon(Icons.settings_rounded),
              label: "Pengaturan",
            ),
          ],
        ),
      ),
    );
  }
}
