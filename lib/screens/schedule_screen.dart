// File: lib/screens/schedule_screen.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/schedule_model.dart';
import 'create_schedule_screen.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';

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
      _refreshSchedules();
    }
  }

  // --- DATA LOADING ---

  Future<void> _refreshSchedules() async {
    setState(() => _isLoading = true);
    try {
      allSchedules = await DatabaseHelper.instance.readAllSchedules();
    } catch (e) {
      debugPrint("❌ ERROR LOAD DB: $e");
      allSchedules = [];
    }
    setState(() => _isLoading = false);
  }

  List<ScheduleModel> get filteredSchedules {
    if (_selectedTab == 1) return allSchedules.where((s) => s.isActive).toList();
    if (_selectedTab == 2) return allSchedules.where((s) => !s.isActive).toList();
    return allSchedules;
  }

  // --- ACTIONS ---

  void _navigateToAdd() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CreateScheduleScreen()));
    if (result != null) {
      await DatabaseHelper.instance.create(result);
      await NotificationService().rescheduleAllNotificationsBackground();
      _refreshSchedules();
    }
  }

  void _navigateToEdit(ScheduleModel item) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreateScheduleScreen(scheduleToEdit: item)));
    if (result != null) {
      await DatabaseHelper.instance.update(result);
      await NotificationService().rescheduleAllNotificationsBackground();
      _refreshSchedules();
    }
  }

void _confirmDelete(ScheduleModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus Jadwal?"),
          content: Text("Anda yakin ingin menghapus jadwal '${item.title}'? Semua alarm terkait akan dibatalkan."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
              ),
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                _executeDelete(item.id); // Lanjutkan eksekusi penghapusan
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _executeDelete(String id) async {
    await DatabaseHelper.instance.delete(id);
    await NotificationService().cancelAllNotifications();
    await NotificationService().rescheduleAllNotificationsBackground();
    _refreshSchedules();
  }
  
  void _toggleStatus(String id, bool value) async {
    final index = allSchedules.indexWhere((item) => item.id == id);
    if (index != -1) {
      setState(() {
        allSchedules[index].isActive = value;
      });

      try {
        await DatabaseHelper.instance.update(allSchedules[index]);
        await NotificationService().rescheduleAllNotificationsBackground();
      } catch (e) {
        setState(() {
          allSchedules[index].isActive = !value;
        });
        debugPrint("❌ Gagal menyimpan status: $e");
      }
    }
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. HEADER
          _HeaderSection(
            theme: theme,
            isDark: isDark,
            allSchedules: allSchedules,
            selectedTab: _selectedTab,
            onTabChanged: (index) => setState(() => _selectedTab = index),
          ),

          // 2. LIST JADWAL
          Expanded(
            child: filteredSchedules.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    itemCount: filteredSchedules.length,
                    itemBuilder: (context, index) {
                      final item = filteredSchedules[index];
                      return _ScheduleCard(
                        item: item,
                        theme: theme,
                        isDark: isDark,
                        onToggle: (val) => _toggleStatus(item.id, val),
                        onEdit: () => _navigateToEdit(item),
                        onDelete: () => _confirmDelete(item),
                      );
                    },
                  ),
          ),
        ],
      ),

      // 3. FAB
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.headerGradient,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x667209B7), 
              blurRadius: 10,
              offset: Offset(0, 5),
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
}

// === SUB-WIDGETS (Extracted for performance & readability) ===

class _HeaderSection extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<ScheduleModel> allSchedules;
  final int selectedTab;
  final Function(int) onTabChanged;

  const _HeaderSection({
    required this.theme,
    required this.isDark,
    required this.allSchedules,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x4D000000) : const Color(0x2E000000),
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
            mainAxisSize: MainAxisSize.min,
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
                  color: const Color(0xE6FFFFFF), // 90% white
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              
              // STATS CARD
              _StatsCard(theme: theme, allSchedules: allSchedules, isDark: isDark),
              
              const SizedBox(height: 16),
              
              // TABS
              _TabBar(
                selectedTab: selectedTab,
                onTabChanged: onTabChanged,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<ScheduleModel> allSchedules;

  const _StatsCard({required this.theme, required this.isDark, required this.allSchedules});

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? Colors.grey[400]! : AppTheme.textGrey;
    final dividerColor = isDark ? const Color(0x80EEEEEE) : const Color(0x80E0E0E0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _StatItem(
                count: allSchedules.length.toString(),
                label: "Total",
                color: AppTheme.primaryPurple,
                labelColor: labelColor,
              ),
            ),
            VerticalDivider(width: 20, color: dividerColor),
            Expanded(
              child: _StatItem(
                count: allSchedules.where((s) => s.isActive).length.toString(),
                label: "Aktif",
                color: AppTheme.accentBlue,
                labelColor: labelColor,
              ),
            ),
            VerticalDivider(width: 20, color: dividerColor),
            Expanded(
              child: _StatItem(
                count: allSchedules.where((s) => !s.isActive).length.toString(),
                label: "Nonaktif",
                color: AppTheme.textGrey,
                labelColor: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final Color labelColor;

  const _StatItem({
    required this.count,
    required this.label,
    required this.color,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int selectedTab;
  final Function(int) onTabChanged;
  final bool isDark;

  const _TabBar({
    required this.selectedTab,
    required this.onTabChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x26FFFFFF) : const Color(0x269E9E9E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _TabButton(
            text: "Semua",
            isActive: selectedTab == 0,
            onTap: () => onTabChanged(0),
            isDark: isDark,
          ),
          _TabButton(
            text: "Aktif",
            isActive: selectedTab == 1,
            onTap: () => onTabChanged(1),
            isDark: isDark,
          ),
          _TabButton(
            text: "Nonaktif",
            isActive: selectedTab == 2,
            onTap: () => onTabChanged(2),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _TabButton({
    required this.text,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? Colors.grey[400]! : Colors.grey;
    final activeBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isActive ? AppTheme.primaryPurple : inactiveColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ScheduleModel item;
  final ThemeData theme;
  final bool isDark;
  final Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.item,
    required this.theme,
    required this.isDark,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = item.isActive
        ? AppTheme.primaryPurple
        : (isDark ? Colors.grey[600]! : Colors.grey[500]!);
    
    final titleColor = item.isActive
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.grey[500]! : Colors.grey[600]!);
    
    final subtitleColor = isDark ? Colors.grey[300]! : Colors.grey[800]!;
    final chipTextColor = item.isActive ? AppTheme.primaryPurple : subtitleColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withAlpha(item.isActive ? 128 : 51), // 0.5 vs 0.2
          width: 1,
        ),
        boxShadow: item.isActive
            ? [
                BoxShadow(
                  color: AppTheme.primaryPurple.withAlpha(20), // 0.08
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW
          Row(
            children: [
              Icon(
                item.isActive
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_filled_rounded,
                size: 20,
                color: primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: titleColor,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: item.isActive,
                  activeTrackColor: AppTheme.primaryPurple,
                  inactiveThumbColor: Colors.grey[400],
                  inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  onChanged: onToggle,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),

          // TIME ROW
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: subtitleColor),
                const SizedBox(width: 6),
                Text(
                  "${item.startTime} - ${item.endTime}",
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // DAYS CHIPS
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.activeDays.map((day) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.isActive
                        ? AppTheme.primaryPurple.withAlpha(26) // 0.1
                        : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: chipTextColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
          ),

          // DETAILS
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DetailStat(
                  val: "${item.intervalDuration} mnt",
                  label: "Fokus",
                  textColor: item.isActive ? titleColor : Colors.grey,
                  labelColor: subtitleColor,
                ),
                VerticalDivider(
                  width: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                _DetailStat(
                  val: "${item.breakDuration} mnt",
                  label: "Rehat",
                  textColor: item.isActive ? titleColor : Colors.grey,
                  labelColor: subtitleColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ACTIONS BUTTONS
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.edit_rounded,
                  label: "Edit",
                  color: AppTheme.primaryPurple,
                  bgColor: Colors.transparent, // Outline style handled inside
                  onTap: onEdit,
                  isDestructive: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.delete_rounded,
                  label: "Hapus",
                  color: Colors.red[400]!,
                  bgColor: Colors.red.withAlpha(13), // 0.05
                  onTap: onDelete,
                  isDestructive: true,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String val;
  final String label;
  final Color textColor;
  final Color labelColor;

  const _DetailStat({
    required this.val,
    required this.label,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: isDestructive ? bgColor : null,
          side: BorderSide(color: color.withAlpha(isDestructive ? 77 : 128)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Tidak ada jadwal ditemukan",
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}