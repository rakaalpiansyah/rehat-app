// File: lib/screens/schedule_screen.dart
import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import 'create_schedule_screen.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';

// =========================================================
// 1. KELAS THEME LOKAL (UI LAMA)
// =========================================================
class ScheduleTheme {
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentPink = Color(0xFFEC4899);
  
  static const Color backgroundLight = Color(0xFFF5F7FB);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF9CA3AF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// =========================================================
// 2. KELAS UTAMA SCREEN
// =========================================================
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with WidgetsBindingObserver {
  List<ScheduleModel> allSchedules = [];
  bool _isLoading = true; 
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSchedules();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("📱 Aplikasi kembali aktif, memuat ulang jadwal...");
      _refreshSchedules(); 
    }
  }

  // --- LOAD DATA ---
  Future<void> _refreshSchedules() async {
    setState(() => _isLoading = true);
    try {
      allSchedules = await DatabaseHelper.instance.readAllSchedules();
    } catch (e) {
      debugPrint("❌ ERROR LOAD DB: $e");
      allSchedules = [];
    }
    setState(() => _isLoading = false);
    
    // 1. Panggil Service untuk Update Sistem Background (Jaga-jaga)
    // await NotificationService().rescheduleAllNotificationsBackground();
    
    // 2. Tampilkan Log Simulasi di Console (Hanya Visual Debug)
    await _printScheduleLogSimulation();
  }

  // --- LOGIKA WAKTU ---
  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

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

  // ==========================================
  // 3. LOGIKA PRINT LOG (VISUAL DEBUG DI UI)
  // ==========================================
  Future<void> _printScheduleLogSimulation() async {
    final String timeCreated = DateTime.now().toString().substring(0, 19);

    debugPrint("\n📊 [UI LOG] SIMULASI JADWAL AKTIF (FIXED WINDOW)");
    debugPrint("📅 Waktu Cek: $timeCreated");
    debugPrint("===================================================");
    
    if (allSchedules.isEmpty) {
      debugPrint("⚠️ DATABASE KOSONG");
      return;
    }

    final now = DateTime.now(); 
    int globalIdCounter = 0;

    for (var item in allSchedules) {
      if (!item.isActive || item.activeDays.isEmpty) continue;
      
      debugPrint("\n📋 JADWAL: ${item.title.toUpperCase()} (Delay: ${item.delayMinutes} mnt)");
      debugPrint("   ⏰ Window Asli: ${item.startTime} s/d ${item.endTime}");

      try {
        int originalStartMin = _timeToMinutes(_parseTime(item.startTime));
        int originalEndMin = _timeToMinutes(_parseTime(item.endTime));
        
        int fixedEndMin = originalEndMin;
        if (fixedEndMin <= originalStartMin) fixedEndMin += 1440; 

        for (String dayName in item.activeDays) {
          int dayOfWeek = _getDayInt(dayName); 
          
          // Logic Hari Ini vs Besok (Sama seperti Service)
          bool isToday = (dayOfWeek == now.weekday);
          int effectiveStartMin = isToday ? originalStartMin + item.delayMinutes : originalStartMin;

          if (effectiveStartMin >= fixedEndMin) {
             debugPrint("   🛑 [SKIP] Delay terlalu lama pada hari $dayName");
             continue; 
          }

          int currentMin = effectiveStartMin;

          // 1. OPENING
          TimeOfDay startObj = _minutesToTime(effectiveStartMin);
          debugPrint("   🎉 [Start] ${_calcNextLogDate(now, dayOfWeek, startObj)} ($dayName)");

          while (currentMin < fixedEndMin) {
            // REHAT
            int rehatStart = currentMin + item.intervalDuration;
            if (rehatStart >= fixedEndMin) break;

            TimeOfDay rehatTime = _minutesToTime(rehatStart);
            String logRehat = _calcNextLogDate(now, dayOfWeek, rehatTime);
            debugPrint("   ☕ [Rehat] $logRehat ($dayName)");
            
            currentMin = rehatStart;

            // FOKUS
            int fokusStart = currentMin + item.breakDuration;
            if (fokusStart >= fixedEndMin) break;

            TimeOfDay fokusTime = _minutesToTime(fokusStart);
            String logFokus = _calcNextLogDate(now, dayOfWeek, fokusTime);
            debugPrint("   🚀 [Fokus] $logFokus ($dayName)");

            currentMin = fokusStart;
          }

          // CLOSING
          TimeOfDay endObj = _minutesToTime(fixedEndMin);
          debugPrint("   🏁 [End]   ${_calcNextLogDate(now, dayOfWeek, endObj)} ($dayName)");
        }
      } catch (e) {
        debugPrint("❌ ERROR Log: $e");
      }
    }
    debugPrint("===================================================");
  }
  
  String _calcNextLogDate(DateTime now, int targetDay, TimeOfDay targetTime) {
    int daysToAdd = (targetDay - now.weekday + 7) % 7;
    DateTime tentativeDate = now.add(Duration(days: daysToAdd));
    
    DateTime result = DateTime(
      tentativeDate.year, tentativeDate.month, tentativeDate.day, 
      targetTime.hour, targetTime.minute
    );

    if (result.isBefore(now)) result = result.add(const Duration(days: 7));
    return result.toString().substring(0, 16);
  }

  // --- NAVIGASI ---
  void _navigateToAdd() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateScheduleScreen()));
    if (result != null) {
      await DatabaseHelper.instance.create(result);
      // Panggil Service untuk jadwalkan ulang background
      await NotificationService().rescheduleAllNotificationsBackground();
      _refreshSchedules();
    }
  }

  void _navigateToEdit(ScheduleModel item) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateScheduleScreen(scheduleToEdit: item)));
    if (result != null) {
      await DatabaseHelper.instance.update(result);
      await NotificationService().rescheduleAllNotificationsBackground();
      _refreshSchedules();
    }
  }

  void _deleteSchedule(String id) async {
    await DatabaseHelper.instance.delete(id);
    await NotificationService().rescheduleAllNotificationsBackground();
    _refreshSchedules();
  }

  void _toggleStatus(String id, bool value) async {
    final index = allSchedules.indexWhere((item) => item.id == id);
    if (index != -1) {
      var schedule = allSchedules[index];
      schedule.isActive = value;
      await DatabaseHelper.instance.update(schedule);
      await NotificationService().rescheduleAllNotificationsBackground();
      await _refreshSchedules(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? "Jadwal Aktif" : "Jadwal Nonaktif"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<ScheduleModel> get filteredSchedules {
    if (_selectedTab == 1) return allSchedules.where((s) => s.isActive).toList();
    if (_selectedTab == 2) return allSchedules.where((s) => !s.isActive).toList();
    return allSchedules;
  }

  // ==========================================
  // UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final double screenHeight = MediaQuery.of(context).size.height;
    final double headerHeight = screenHeight * 0.32; 

    return Scaffold(
      backgroundColor: ScheduleTheme.backgroundLight,
      body: Stack(
        children: [
          Container(
            height: headerHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: ScheduleTheme.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x306B4EFF), blurRadius: 20, offset: Offset(0, 10))],
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Jadwal Rehat", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("Kelola rutinitas produktif Anda", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                      const SizedBox(height: 20),
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
                          physics: const BouncingScrollPhysics(),
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
      
      floatingActionButton: FloatingActionButton(
        heroTag: "addSchedule_${DateTime.now().millisecondsSinceEpoch}",
        onPressed: _navigateToAdd,
        backgroundColor: ScheduleTheme.primaryPurple,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildStatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _StatItem(count: allSchedules.length.toString(), label: "Total", color: ScheduleTheme.primaryPurple)),
          Container(width: 1, height: 30, color: Colors.grey[200]),
          Expanded(child: _StatItem(count: allSchedules.where((s) => s.isActive).length.toString(), label: "Aktif", color: ScheduleTheme.accentBlue)),
          Container(width: 1, height: 30, color: Colors.grey[200]),
          Expanded(child: _StatItem(count: allSchedules.where((s) => !s.isActive).length.toString(), label: "Nonaktif", color: ScheduleTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TabButton(text: "Semua", isActive: _selectedTab == 0, onTap: () => setState(() => _selectedTab = 0)), 
          _TabButton(text: "Aktif", isActive: _selectedTab == 1, onTap: () => setState(() => _selectedTab = 1)), 
          _TabButton(text: "Nonaktif", isActive: _selectedTab == 2, onTap: () => setState(() => _selectedTab = 2))
        ]
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel item) {

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isActive ? ScheduleTheme.primaryPurple.withOpacity(0.2) : Colors.transparent, 
          width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, // Tambah info delay di judul (opsional)
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ScheduleTheme.textDark)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: ScheduleTheme.textGrey), 
                      const SizedBox(width: 4), 
                      Text("${item.startTime} - ${item.endTime}", style: const TextStyle(color: ScheduleTheme.textGrey, fontSize: 13))
                    ]),
                  ],
                ),
              ),
              Switch.adaptive(value: item.isActive, activeColor: ScheduleTheme.primaryPurple, onChanged: (val) => _toggleStatus(item.id, val)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: item.activeDays.map((day) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                decoration: BoxDecoration(color: item.isActive ? ScheduleTheme.primaryPurple.withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(8)), 
                child: Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: item.isActive ? ScheduleTheme.primaryPurple : ScheduleTheme.textGrey))
              )).toList(),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.grey[100])),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _DetailStat("${item.totalDuration}m", "Total"), 
            _DetailStat("${item.intervalDuration}m", "Interval"), 
            _DetailStat("${item.breakDuration}m", "Rehat")
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _navigateToEdit(item), icon: const Icon(Icons.edit_rounded, size: 16), label: const Text("Edit"), style: OutlinedButton.styleFrom(foregroundColor: ScheduleTheme.primaryPurple, side: BorderSide(color: ScheduleTheme.primaryPurple.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _deleteSchedule(item.id), icon: const Icon(Icons.delete_rounded, size: 16), label: const Text("Hapus"), style: OutlinedButton.styleFrom(foregroundColor: Colors.red[400], side: BorderSide(color: Colors.red.withOpacity(0.2)), backgroundColor: Colors.red.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
            ]
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() => const Center(child: Text("Tidak ada jadwal ditemukan", style: TextStyle(color: Colors.grey)));
}

class _StatItem extends StatelessWidget { 
  final String count, label; 
  final Color color; 
  const _StatItem({required this.count, required this.label, required this.color}); 
  @override 
  Widget build(BuildContext context) => Column(children: [FittedBox(child: Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, color: ScheduleTheme.textGrey))]); 
}

class _DetailStat extends StatelessWidget { 
  final String val, label; 
  const _DetailStat(this.val, this.label); 
  @override 
  Widget build(BuildContext context) => Column(children: [Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ScheduleTheme.textDark)), Text(label, style: const TextStyle(fontSize: 11, color: ScheduleTheme.textGrey))]); 
}

class _TabButton extends StatelessWidget {
  final String text; final bool isActive; final VoidCallback onTap;
  const _TabButton({required this.text, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(30), boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : []), child: Center(child: Text(text, style: TextStyle(color: isActive ? ScheduleTheme.primaryPurple : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13))))));
}