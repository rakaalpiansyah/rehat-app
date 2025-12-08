import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // HAPUS INI
import '../core/theme.dart';
import '../models/schedule_model.dart';
import 'create_schedule_screen.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart'; // TAMBAHKAN INI
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<ScheduleModel> allSchedules = [];
  bool _isLoading = true; 
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    _refreshSchedules(); // Ganti nama biar lebih jelas
  }

  // --- 1. LOAD DATA DARI SQLITE ---
  
  Future<void> _refreshSchedules() async {
    setState(() => _isLoading = true);
    
    // Ambil data dari SQLite via DatabaseHelper
    try {
      allSchedules = await DatabaseHelper.instance.readAllSchedules();
      debugPrint("📂 LOAD SQLITE: ${allSchedules.length} jadwal ditemukan.");
    } catch (e) {
      debugPrint("❌ ERROR LOAD DB: $e");
      allSchedules = [];
    }

    setState(() => _isLoading = false);
    
    // Sinkronisasi Alarm dengan Data Database
    await _rescheduleAllSystem();
  }

  // --- 2. LOGIKA MATEMATIKA WAKTU (Tidak Berubah) ---

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  TimeOfDay _minutesToTime(int totalMinutes) {
    int normalizedMinutes = totalMinutes % 1440;
    return TimeOfDay(hour: normalizedMinutes ~/ 60, minute: normalizedMinutes % 60);
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  int _getDayInt(String dayName) {
    switch (dayName) {
      case 'Sen': return DateTime.monday;
      case 'Sel': return DateTime.tuesday;
      case 'Rab': return DateTime.wednesday;
      case 'Kam': return DateTime.thursday;
      case 'Jum': return DateTime.friday;
      case 'Sab': return DateTime.saturday;
      case 'Min': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  // --- 3. LOGIKA NOTIFIKASI PINTAR (Tidak Berubah) ---
  
// Di dalam schedule_screen.dart

  Future<void> _rescheduleAllSystem() async {
    debugPrint("🔄 === MULAI RESCHEDULE SISTEM ===");
    
    // 1. Cek apakah ada data
    if (allSchedules.isEmpty) {
      debugPrint("⚠️ TIDAK ADA JADWAL DI DATABASE.");
      return;
    }

    // 2. Cancel notifikasi lama
    await NotificationService().cancelAllNotifications();
    debugPrint("🗑️ Notifikasi lama dihapus.");

    int globalIdCounter = 0;
    int successCount = 0;

    // 3. Loop setiap jadwal
    for (var item in allSchedules) {
      debugPrint("------------------------------------------------");
      debugPrint("📋 Memproses Jadwal: ${item.title} (ID: ${item.id})");
      debugPrint("   Status Aktif: ${item.isActive}");
      debugPrint("   Hari: ${item.activeDays}");

      // Cek Status Aktif
      if (!item.isActive) {
        debugPrint("   ⏭️ SKIP: Jadwal tidak aktif.");
        continue;
      }

      // Cek Hari Kosong
      if (item.activeDays.isEmpty) {
        debugPrint("   ⚠️ SKIP: Hari belum dipilih (List Kosong).");
        continue;
      }

      try {
        int startMin = _timeToMinutes(_parseTime(item.startTime));
        int endMin = _timeToMinutes(_parseTime(item.endTime));
        if (endMin <= startMin) endMin += 1440;

        for (String dayName in item.activeDays) {
          int dayOfWeek = _getDayInt(dayName);
          int currentMin = startMin;
          int cycleCount = 0;

          debugPrint("   📅 Hari: $dayName (Int: $dayOfWeek) | Range: $startMin - $endMin");

          while (currentMin < endMin && cycleCount < 20) {
            // A. FASE FOKUS SELESAI -> JADWALKAN REHAT
            currentMin += item.intervalDuration;
            if (currentMin >= endMin) break;

            TimeOfDay breakTime = _minutesToTime(currentMin);
            
            // LOG PENTING:
            debugPrint("      🔔 Set Alarm REHAT jam: ${breakTime.format(context)} (ID: $globalIdCounter)");

            await NotificationService().scheduleWeeklyNotification(
              id: globalIdCounter++,
              title: "Saatnya Rehat! ☕",
              body: "Fokus ${item.intervalDuration}m selesai. Istirahat dulu!",
              time: breakTime,
              dayOfWeek: dayOfWeek,
            );
            successCount++;

            // B. FASE REHAT SELESAI -> JADWALKAN KERJA
            currentMin += item.breakDuration;
            if (currentMin >= endMin) break;

            TimeOfDay workTime = _minutesToTime(currentMin);
            
            // LOG PENTING:
            debugPrint("      🚀 Set Alarm KERJA jam: ${workTime.format(context)} (ID: $globalIdCounter)");

            await NotificationService().scheduleWeeklyNotification(
              id: globalIdCounter++,
              title: "Lanjut Fokus 🚀",
              body: "Istirahat selesai. Gas lagi!",
              time: workTime,
              dayOfWeek: dayOfWeek,
            );
            successCount++;

            cycleCount++;
          }
        }
      } catch (e) {
        debugPrint("❌ ERROR pada jadwal ini: $e");
      }
    }
    
    debugPrint("✅ SELESAI. Total $successCount alarm berhasil dijadwalkan.");
    debugPrint("================================================");
  }
  // --- 4. NAVIGASI CRUD (UPDATED KE SQLITE) ---

  void _navigateToAdd() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateScheduleScreen()));
    
    if (result != null && result is ScheduleModel) {
      // 1. Simpan ke SQLite
      await DatabaseHelper.instance.create(result);
      
      // 2. Refresh List & Alarm
      await _refreshSchedules(); 
      
      if (!mounted) return;
      _showSnack("Jadwal ditambahkan & alarm diatur");
    }
  }

  void _navigateToEdit(ScheduleModel item) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateScheduleScreen(scheduleToEdit: item)));
    
    if (result != null && result is ScheduleModel) {
      // 1. Update ke SQLite
      await DatabaseHelper.instance.update(result);
      
      // 2. Refresh List & Alarm
      await _refreshSchedules();

      if (!mounted) return;
      _showSnack("Jadwal diperbarui");
    }
  }

  void _deleteSchedule(String id) async {
    final int baseId = id.hashCode.abs();
    // Cancel notifikasi range aman (logic lama)
    for (int i = 0; i < 100; i++) {
      NotificationService().cancelNotification(baseId + i);
    }

    // Hapus dari Database
    await DatabaseHelper.instance.delete(id);
    
    // Refresh UI
    await _refreshSchedules();
    _showSnack("Jadwal dihapus");
  }

  void _toggleStatus(String id, bool value) async {
    final index = allSchedules.indexWhere((item) => item.id == id);
    
    if (index != -1) {
      final schedule = allSchedules[index];
      schedule.isActive = value; // Update object di memori sementara
      
      // Update di Database
      await DatabaseHelper.instance.update(schedule);

      String namaJadwal = schedule.title;
      debugPrint("👉 SWITCH: $namaJadwal jadi $value");

      if (value == true) {
        await NotificationService().showNotification(
          "Pengingat Aktif", 
          "Jadwal '$namaJadwal' berhasil diaktifkan!"
        );
      }

      // Refresh sistem alarm
      await _refreshSchedules();
      
      if (!mounted) return;
      _showSnack(value ? "Pengingat diaktifkan" : "Pengingat dimatikan");
    }
  }   
  
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }


  // --- 5. UI BUILD (Tidak Berubah) ---

  List<ScheduleModel> get filteredSchedules {
    if (_selectedTab == 1) return allSchedules.where((s) => s.isActive).toList();
    if (_selectedTab == 2) return allSchedules.where((s) => !s.isActive).toList();
    return allSchedules;
  }

  int get totalCount => allSchedules.length;
  int get activeCount => allSchedules.where((s) => s.isActive).length;
  int get inactiveCount => allSchedules.where((s) => !s.isActive).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          Container(
            height: 280, width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Jadwal Rehat", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text("Kelola jadwal istirahat otomatis Anda", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 24),
                      _buildStatCard(),
                      const SizedBox(height: 16),
                      _buildTabs(),
                    ],
                  ),
                ),
                
                Expanded(
                  child: filteredSchedules.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          itemCount: filteredSchedules.length,
                          itemBuilder: (context, index) => _buildScheduleCard(filteredSchedules[index]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
      
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "addSchedule",
            onPressed: _navigateToAdd,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildStatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(count: totalCount.toString(), label: "Total", color: Colors.black87),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _StatItem(count: activeCount.toString(), label: "Aktif", color: Colors.green),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _StatItem(count: inactiveCount.toString(), label: "Nonaktif", color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.3))),
      child: Row(children: [_TabButton(text: "Semua", isActive: _selectedTab == 0, onTap: () => setState(() => _selectedTab = 0)), _TabButton(text: "Aktif", isActive: _selectedTab == 1, onTap: () => setState(() => _selectedTab = 1)), _TabButton(text: "Nonaktif", isActive: _selectedTab == 2, onTap: () => setState(() => _selectedTab = 2))]),
    );
  }

  Widget _buildScheduleCard(ScheduleModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: item.isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3142))),
                  const SizedBox(height: 6),
                  Row(children: [const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey), const SizedBox(width: 4), Text("${item.startTime} - ${item.endTime}", style: const TextStyle(color: Colors.grey, fontSize: 13))]),
                ],
              ),
              Switch.adaptive(value: item.isActive, activeColor: AppTheme.primaryColor, onChanged: (val) => _toggleStatus(item.id, val)),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: item.activeDays.map((day) => Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: item.isActive ? const Color(0xFF6B4EFF).withOpacity(0.08) : Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: item.isActive ? AppTheme.primaryColor : Colors.grey)))).toList()),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.grey[100])),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_DetailStat("${item.totalDuration}m", "Total"), _DetailStat("${item.intervalDuration}m", "Interval"), _DetailStat("${item.breakDuration}m", "Rehat")]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _navigateToEdit(item), icon: const Icon(Icons.edit_rounded, size: 16), label: const Text("Edit"), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: () => _deleteSchedule(item.id), icon: const Icon(Icons.delete_rounded, size: 16), label: const Text("Hapus"), style: OutlinedButton.styleFrom(foregroundColor: Colors.red[400], side: BorderSide(color: Colors.red[100]!), backgroundColor: Colors.red[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
          ])
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(children: [const SizedBox(height: 40), Icon(Icons.calendar_today_rounded, size: 60, color: Colors.grey[300]), const SizedBox(height: 16), Text("Tidak ada jadwal ditemukan", style: TextStyle(color: Colors.grey[400]))]));
  }
}

class _StatItem extends StatelessWidget { final String count, label; final Color color; const _StatItem({required this.count, required this.label, required this.color}); @override Widget build(BuildContext context) => Column(children: [Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]); }
class _DetailStat extends StatelessWidget { final String val, label; const _DetailStat(this.val, this.label); @override Widget build(BuildContext context) => Column(children: [Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142))), Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500]))]); }
class _TabButton extends StatelessWidget { final String text; final bool isActive; final VoidCallback onTap; const _TabButton({required this.text, required this.isActive, required this.onTap}); @override Widget build(BuildContext context) { return Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(text, style: TextStyle(color: isActive ? AppTheme.primaryColor : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)))))); } }