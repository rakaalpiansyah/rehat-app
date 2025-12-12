// File: lib/screens/schedule_screen.dart
import 'package:flutter/material.dart';
import '../core/theme.dart'; // Import AppTheme
import '../models/schedule_model.dart';
import 'create_schedule_screen.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';

// =========================================================
// CLASS UTAMA SCREEN
// =========================================================
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with WidgetsBindingObserver {
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
    
    // Debug log simulasi
    await _printScheduleLogSimulation();
  }

  // --- LOGIKA WAKTU (Helper) ---
  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _minutesToTime(int totalMinutes) {
    int normalizedMinutes = totalMinutes % 1440;
    return TimeOfDay(
        hour: normalizedMinutes ~/ 60, minute: normalizedMinutes % 60);
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
  // LOGIKA PRINT LOG (VISUAL DEBUG DI UI)
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

    for (var item in allSchedules) {
      if (!item.isActive || item.activeDays.isEmpty) continue;

      debugPrint(
          "\n📋 JADWAL: ${item.title.toUpperCase()} (Delay: ${item.delayMinutes} mnt)");
      debugPrint("   ⏰ Window Asli: ${item.startTime} s/d ${item.endTime}");

      try {
        int originalStartMin = _timeToMinutes(_parseTime(item.startTime));
        int originalEndMin = _timeToMinutes(_parseTime(item.endTime));

        int fixedEndMin = originalEndMin;
        if (fixedEndMin <= originalStartMin) fixedEndMin += 1440;

        for (String dayName in item.activeDays) {
          int dayOfWeek = _getDayInt(dayName);
          bool isToday = (dayOfWeek == now.weekday);
          int effectiveStartMin =
              isToday ? originalStartMin + item.delayMinutes : originalStartMin;

          if (effectiveStartMin >= fixedEndMin) {
            debugPrint("   🛑 [SKIP] Delay terlalu lama pada hari $dayName");
            continue;
          }

          int currentMin = effectiveStartMin;

          // 1. OPENING
          TimeOfDay startObj = _minutesToTime(effectiveStartMin);
          debugPrint(
              "   🎉 [Start] ${_calcNextLogDate(now, dayOfWeek, startObj)} ($dayName)");

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
          debugPrint(
              "   🏁 [End]   ${_calcNextLogDate(now, dayOfWeek, endObj)} ($dayName)");
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

    DateTime result = DateTime(tentativeDate.year, tentativeDate.month,
        tentativeDate.day, targetTime.hour, targetTime.minute);

    if (result.isBefore(now)) result = result.add(const Duration(days: 7));
    return result.toString().substring(0, 16);
  }

  // --- NAVIGASI ---
  void _navigateToAdd() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CreateScheduleScreen()));
    if (result != null) {
      await DatabaseHelper.instance.create(result);
      await NotificationService().rescheduleAllNotificationsBackground();
      _refreshSchedules();
    }
  }

  void _navigateToEdit(ScheduleModel item) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreateScheduleScreen(scheduleToEdit: item)));
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

  // --- OPTIMISTIC UPDATE (Tanpa Lag & Tanpa SnackBar) ---
  void _toggleStatus(String id, bool value) async {
    final index = allSchedules.indexWhere((item) => item.id == id);
    if (index != -1) {
      // 1. Update Tampilan Langsung (Instan)
      setState(() {
        allSchedules[index].isActive = value;
      });

      // 2. Simpan ke DB & Reschedule Notifikasi di Background
      try {
        await DatabaseHelper.instance.update(allSchedules[index]);
        await NotificationService().rescheduleAllNotificationsBackground();
        debugPrint("✅ Status jadwal ${allSchedules[index].title} berhasil disimpan: $value");
      } catch (e) {
        // Jika gagal, kembalikan tampilan
        setState(() {
          allSchedules[index].isActive = !value;
        });
        debugPrint("❌ Gagal menyimpan status: $e");
      }
    }
  }

  List<ScheduleModel> get filteredSchedules {
    if (_selectedTab == 1)
      return allSchedules.where((s) => s.isActive).toList();
    if (_selectedTab == 2)
      return allSchedules.where((s) => !s.isActive).toList();
    return allSchedules;
  }

  // ==========================================
  // UI BUILD (AUTO-RESIZE HEADER)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Menggunakan Column agar layout mengalir dan header fleksibel
      body: Column(
        children: [
          // === 1. HEADER (Container pembungkus) ===
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                      theme.brightness == Brightness.dark ? 0.3 : 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Tinggi header menyesuaikan konten
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Jadwal Rehat",
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Kelola rutinitas produktif Anda",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatCard(theme),
                    const SizedBox(height: 16),
                    _buildTabs(),
                  ],
                ),
              ),
            ),
          ),

          // === 2. LIST JADWAL ===
          Expanded(
            child: filteredSchedules.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    itemCount: filteredSchedules.length,
                    itemBuilder: (context, index) =>
                        _buildScheduleCard(filteredSchedules[index], theme),
                  ),
          ),
        ],
      ),

      // === 3. TOMBOL FAB ===
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.headerGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7209B7).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _navigateToAdd,
            borderRadius: BorderRadius.circular(28),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER STATISTIK HEADER ---
  Widget _buildStatCard(ThemeData theme) {
    final Color labelColor = theme.brightness == Brightness.dark 
        ? Colors.grey[400]! 
        : AppTheme.textGrey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface, 
          borderRadius: BorderRadius.circular(20)),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
                child: _StatItem(
                    count: allSchedules.length.toString(),
                    label: "Total",
                    color: AppTheme.primaryPurple,
                    labelColor: labelColor)), 
            VerticalDivider(width: 20, color: Colors.grey[200]!.withOpacity(0.5)),
            Expanded(
                child: _StatItem(
                    count: allSchedules.where((s) => s.isActive).length.toString(),
                    label: "Aktif",
                    color: AppTheme.accentBlue,
                    labelColor: labelColor)), 
            VerticalDivider(width: 20, color: Colors.grey[200]!.withOpacity(0.5)),
            Expanded(
                child: _StatItem(
                    count: allSchedules.where((s) => !s.isActive).length.toString(),
                    label: "Nonaktif",
                    color: AppTheme.textGrey,
                    labelColor: labelColor)), 
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER TABS ---
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _TabButton(
            text: "Semua",
            isActive: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0)),
        _TabButton(
            text: "Aktif",
            isActive: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1)),
        _TabButton(
            text: "Nonaktif",
            isActive: _selectedTab == 2,
            onTap: () => setState(() => _selectedTab = 2))
      ]),
    );
  }

  // --- WIDGET HELPER SCHEDULE CARD (HIGH CONTRAST & JELAS) ---
  Widget _buildScheduleCard(ScheduleModel item, ThemeData theme) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360; 
    final bool isDark = theme.brightness == Brightness.dark;

    // WARNA HIGH CONTRAST AGAR JELAS
    final Color primaryColor = item.isActive 
        ? AppTheme.primaryPurple 
        : (isDark ? Colors.grey[600]! : Colors.grey[500]!);

    final Color titleColor = item.isActive
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.grey[500]! : Colors.grey[600]!);

    final Color subtitleColor = isDark 
        ? Colors.grey[300]! 
        : Colors.grey[800]!;

    final Color chipTextColor = item.isActive
        ? AppTheme.primaryPurple
        : subtitleColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: primaryColor.withOpacity(item.isActive ? 0.5 : 0.2),
            width: 1),
        boxShadow: item.isActive ? [
          BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BARIS 1: Judul, Status Icon, Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                        item.isActive 
                            ? Icons.check_circle_rounded 
                            : Icons.pause_circle_filled_rounded, 
                        size: 20, 
                        color: primaryColor),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 15 : 16,
                              color: titleColor)), 
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                    value: item.isActive,
                    activeColor: AppTheme.primaryPurple,
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    onChanged: (val) => _toggleStatus(item.id, val)),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // BARIS 2: Waktu & Hari
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Row(children: [
                  Icon(Icons.access_time_rounded, size: 14, color: subtitleColor), 
                  const SizedBox(width: 6),
                  Text("${item.startTime} - ${item.endTime}",
                      style: TextStyle(
                          color: subtitleColor, 
                          fontSize: 13, 
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.activeDays
                      .map((day) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: item.isActive
                                  ? AppTheme.primaryPurple.withOpacity(0.1)
                                  : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(day,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: chipTextColor)))) 
                      .toList(),
                ),
              ),
            ],
          ),
          
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300])),
          
          // BARIS 3: Statistik Detail
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, 
              children: [
                Expanded(child: _DetailStat(
                  "${item.intervalDuration} mnt",
                  "Fokus", 
                  item.isActive ? (isDark ? Colors.white : Colors.black87) : Colors.grey, 
                  subtitleColor,)), 
                VerticalDivider(width: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                Expanded(child: _DetailStat(
                  "${item.breakDuration} mnt",
                  "Rehat", 
                  item.isActive ? (isDark ? Colors.white : Colors.black87) : Colors.grey, 
                  subtitleColor,)),
              ]),
          ),

          const SizedBox(height: 14),
          
          // BARIS 4: Tombol Aksi
          Row(children: [
            Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                      onPressed: () => _navigateToEdit(item),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text("Edit", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryPurple,
                          side: BorderSide(
                              color: AppTheme.primaryPurple.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                      )),
                )),
            const SizedBox(width: 12),
            Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                      onPressed: () => _deleteSchedule(item.id),
                      icon: Icon(Icons.delete_rounded, size: 16, color: Colors.red[400]),
                      label: Text("Hapus", style: TextStyle(color: Colors.red[400], fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                          backgroundColor: Colors.red.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                      )),
                )),
          ])
        ],
      ),
    );
  }

  Widget _buildEmptyState() => const Center(
      child: Text("Tidak ada jadwal ditemukan",
          style: TextStyle(color: Colors.grey)));
}

// ==========================================
// WIDGET KECIL
// ==========================================

class _DetailStat extends StatelessWidget {
  final String val, label;
  final Color textColor;
  final Color labelColor; 

  const _DetailStat(this.val, this.label, this.textColor, this.labelColor); 

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(val,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: textColor)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w500,
                  color: labelColor))) 
      ]);
}

class _StatItem extends StatelessWidget {
  final String count, label;
  final Color color;
  final Color labelColor; 

  const _StatItem(
      {required this.count, 
      required this.label, 
      required this.color, 
      required this.labelColor}); 

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(count,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color))),
        const SizedBox(height: 4),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: labelColor))) 
      ]);
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;
  const _TabButton(
      {required this.text, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final Color inactiveColor = Theme.of(context).brightness == Brightness.dark 
        ? Colors.grey[400]! 
        : Colors.grey;

    return Expanded(
      child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: isActive 
                    ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white) 
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]
                      : []),
              child: Center(
                  child: Text(text,
                      style: TextStyle(
                          color: isActive
                              ? AppTheme.primaryPurple
                              : inactiveColor, 
                          fontWeight: FontWeight.bold,
                          fontSize: 13))))));
  }
}