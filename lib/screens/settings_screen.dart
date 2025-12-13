// File: lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/theme.dart'; 

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warna Background Icon (Dark Mode) - Pengganti withOpacity
    // 0.2 * 255 = 51 (Hex: 0x33)
    final iconBgDarkBlue = const Color(0x331E88E5); 
    final iconBgDarkPurple = const Color(0x33BA68C8); 

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pengaturan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // KARTU 0: TEMA GELAP
          _CustomCard(
            isDark: isDark,
            child: _SettingToggleItem(
              icon: Icons.dark_mode_rounded,
              iconColor: Colors.indigo,
              // Ganti opacity dengan warna solid yang sesuai atau Hex Alpha
              iconBgColor: isDark ? iconBgDarkBlue : Colors.indigo[50]!,
              title: "Mode Gelap",
              subtitle: "Nyaman di mata saat malam",
              value: settings.isDarkMode,
              onChanged: (val) {
                context.read<SettingsProvider>().toggleTheme(val);
              },
            ),
          ),

          const SizedBox(height: 16),

          // KARTU 1: Suara Notifikasi
          _CustomCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingHeader(
                  icon: Icons.volume_up,
                  iconColor: AppTheme.primaryPurple,
                  title: "Suara Notifikasi",
                  subtitle: "Pilih audio yang menenangkan",
                ),
                const SizedBox(height: 20),
                // Grid Suara
                _SoundGrid(
                  selectedIndex: settings.selectedSoundIndex,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // KARTU 2: Toggle Getaran
          _CustomCard(
            isDark: isDark,
            child: _SettingToggleItem(
              icon: Icons.vibration,
              iconColor: Colors.purple,
              iconBgColor: isDark ? iconBgDarkPurple : Colors.purple[50]!,
              title: "Getaran",
              subtitle: "Aktifkan getaran notifikasi",
              value: settings.isVibrationEnabled,
              onChanged: (val) {
                context.read<SettingsProvider>().toggleVibration(val);
              },
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET HELPER
// ==========================================

class _SettingHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _SettingHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingToggleItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          // Menggunakan withAlpha (Int 0-255) pengganti withOpacity (Double 0.0-1.0)
          // 0.6 * 255 ~= 153
          activeTrackColor: AppTheme.primaryPurple.withAlpha(153),
          activeThumbColor: AppTheme.primaryPurple,
        ),
      ],
    );
  }
}

class _SoundGrid extends StatelessWidget {
  final int selectedIndex;
  final bool isDark;

  const _SoundGrid({
    required this.selectedIndex,
    required this.isDark,
  });

  static const List<Map<String, dynamic>> sounds = [
    {"icon": Icons.alarm, "label": "Default Alarm"},
    {"icon": Icons.water_drop, "label": "Gemericik Air"},
    {"icon": Icons.cloud, "label": "Hujan Ringan"},
    {"icon": Icons.spa, "label": "Angin Sepoi"},
    {"icon": Icons.music_note, "label": "Kicau Burung"},
    {"icon": Icons.waves, "label": "Ombak Pantai"},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = AppTheme.accentBlue;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: sounds.length,
      itemBuilder: (ctx, i) {
        final s = sounds[i];
        bool isSel = i == selectedIndex;
        
        final borderColor = isSel 
            ? selectedColor 
            : (isDark ? Colors.grey[700]! : Colors.grey[200]!);

        // Pengganti withOpacity(0.1) -> withAlpha(25)
        final bgColor = isSel 
            ? selectedColor.withAlpha(25) 
            : theme.cardColor;

        final iconLabelColor = isSel ? selectedColor : Colors.grey[600];

        return GestureDetector(
          onTap: () {
            context.read<SettingsProvider>().setSound(i);
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(15),
              color: bgColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s['icon'] as IconData, size: 30, color: iconLabelColor),
                const SizedBox(height: 8),
                Text(s['label'] as String,
                    style: TextStyle(fontSize: 12, color: iconLabelColor)),
                if (isSel)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Icon(Icons.check_circle, size: 16, color: selectedColor),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool isDark;

  const _CustomCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    
    // Shadow Colors (Hex Alpha)
    // Dark Mode: Opacity 0.2 -> 0x33
    // Light Mode: Opacity 0.05 -> 0x0D
    final shadowColor = isDark 
        ? const Color(0x33000000) 
        : const Color(0x0D000000);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}