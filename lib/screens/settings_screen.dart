import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../providers/settings_provider.dart'; // Import Provider yang kita buat

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ambil data setting dari provider
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // KARTU 0: TEMA GELAP (Fitur Baru)
          _CustomCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.dark_mode_rounded, color: Colors.indigo),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Mode Gelap",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Nyaman di mata saat malam",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: settings.isDarkMode,
                  onChanged: (val) {
                    context.read<SettingsProvider>().toggleTheme(val);
                  },
                  activeThumbColor: const Color(0xFF6B4EFF),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // KARTU 1: Suara Notifikasi (Updated)
          _CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.volume_up, color: Color(0xFF6B4EFF)),
                  SizedBox(width: 10),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Suara Notifikasi",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Pilih audio yang menenangkan",
                            style: TextStyle(fontSize: 12, color: Colors.grey))
                      ])
                ]),
                const SizedBox(height: 20),
                // Pass current selection to Grid
                _SoundGrid(selectedIndex: settings.selectedSoundIndex),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // KARTU 2: Toggle Getaran (Updated)
          _CustomCard(
            child: Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.vibration, color: Colors.purple)),
                const SizedBox(width: 15),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text("Getaran",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Aktifkan getaran notifikasi",
                          style: TextStyle(fontSize: 12, color: Colors.grey))
                    ])),
                Switch(
                    value: settings.isVibrationEnabled,
                    onChanged: (val) {
                      context.read<SettingsProvider>().toggleVibration(val);
                    },
                    activeThumbColor: const Color(0xFF6B4EFF)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Widget Grid Suara (Updated)
class _SoundGrid extends StatelessWidget {
  final int selectedIndex;
  const _SoundGrid({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final sounds = [
      {"icon": Icons.alarm, "label": "Default Alarm"},
      {"icon": Icons.water_drop, "label": "Gemericik Air"},
      {"icon": Icons.cloud, "label": "Hujan Ringan"},
      {"icon": Icons.spa, "label": "Angin Sepoi"},
      {"icon": Icons.music_note, "label": "Kicau Burung"},
      {"icon": Icons.waves, "label": "Ombak Pantai"},
    ];

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
        bool isSel = i == selectedIndex; // Logic seleksi
        return GestureDetector(
          onTap: () {
            // Simpan index suara yang dipilih
            context.read<SettingsProvider>().setSound(i);
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: isSel ? const Color(0xFF2E85FF) : Colors.grey.shade200,
                  width: 2),
              borderRadius: BorderRadius.circular(15),
              color: isSel
                  ? const Color(0xFF2E85FF).withOpacity(0.05)
                  : Theme.of(context).cardColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s['icon'] as IconData,
                    size: 30,
                    color: isSel ? const Color(0xFF2E85FF) : Colors.grey),
                const SizedBox(height: 8),
                Text(s['label'] as String,
                    style: TextStyle(
                        fontSize: 12,
                        color: isSel ? const Color(0xFF2E85FF) : Colors.grey)),
                if (isSel)
                  const Icon(Icons.check_circle,
                      size: 16, color: Color(0xFF2E85FF))
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

  const _CustomCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    // Sesuaikan warna kartu dengan tema (Dark/Light)
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
