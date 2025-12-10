import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // KARTU 1: Suara Notifikasi
          const _CustomCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.volume_up, color: Color(0xFF6B4EFF)),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text("Suara Notifikasi", style: TextStyle(fontWeight: FontWeight.bold)), 
                      Text("Pilih audio yang menenangkan", style: TextStyle(fontSize: 12, color: Colors.grey))
                    ]
                  )
                ]),
                SizedBox(height: 20),
                _SoundGrid(),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // KARTU 2: Toggle Getaran
          _CustomCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10), 
                  decoration: BoxDecoration(
                    color: Colors.purple[50], 
                    borderRadius: BorderRadius.circular(10)
                  ), 
                  child: const Icon(Icons.vibration, color: Colors.purple)
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text("Getaran", style: TextStyle(fontWeight: FontWeight.bold)), 
                      Text("Aktifkan getaran notifikasi", style: TextStyle(fontSize: 12, color: Colors.grey))
                    ]
                  )
                ),
                Switch(
                  value: true, 
                  onChanged: (val){}, 
                  activeThumbColor: const Color(0xFF6B4EFF)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET LOKAL (Hanya untuk halaman ini)
// ==========================================

class _SoundGrid extends StatelessWidget {
  const _SoundGrid();

  @override
  Widget build(BuildContext context) {
    // Data dummy suara
    final sounds = [
      {"icon": Icons.water_drop, "label": "Gemericik Air", "selected": false},
      {"icon": Icons.cloud, "label": "Hujan Ringan", "selected": false},
      {"icon": Icons.forest, "label": "Suara Hutan", "selected": false},
      {"icon": Icons.spa, "label": "Angin Sepoi", "selected": false},
      {"icon": Icons.music_note, "label": "Kicau Burung", "selected": false},
      {"icon": Icons.waves, "label": "Ombak Pantai", "selected": true},
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
        bool isSel = s['selected'] as bool;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: isSel ? const Color(0xFF2E85FF) : Colors.grey.shade200, width: 2),
            borderRadius: BorderRadius.circular(15),
            color: isSel ? const Color(0xFF2E85FF).withOpacity(0.05) : Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s['icon'] as IconData, size: 30, color: isSel ? const Color(0xFF2E85FF) : Colors.grey),
              const SizedBox(height: 8),
              Text(s['label'] as String, style: TextStyle(fontSize: 12, color: isSel ? const Color(0xFF2E85FF) : Colors.grey)),
              if(isSel) const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E85FF))
            ],
          ),
        );
      },
    );
  }
}

// Class CustomCard dipindahkan ke sini dan diberi nama _CustomCard (Private)
class _CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const _CustomCard({
    // ignore: unused_element
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
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
      ),
    );
  }
}