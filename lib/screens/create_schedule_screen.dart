// File: lib/screens/create_schedule_screen.dart
import 'package:flutter/material.dart';
import '../models/schedule_model.dart';

class CreateScheduleScreen extends StatefulWidget {
  final ScheduleModel? scheduleToEdit;

  const CreateScheduleScreen({super.key, this.scheduleToEdit});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  // Controllers
  final TextEditingController _titleController = TextEditingController();

  // State Values
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  List<String> _selectedDays = [];
  
  // Konfigurasi (Total Sesi Fokus dihapus, dihitung otomatis)
  double _intervalFocus = 45;
  double _breakDuration = 5;
  bool _activateImmediately = true;

  final List<String> _days = const ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"];

  @override
  void initState() {
    super.initState();
    if (widget.scheduleToEdit != null) {
      final s = widget.scheduleToEdit!;
      _titleController.text = s.title;
      _startTime = _parseTime(s.startTime);
      _endTime = _parseTime(s.endTime);
      _selectedDays = List.from(s.activeDays);
      _intervalFocus = s.intervalDuration.toDouble();
      _breakDuration = s.breakDuration.toDouble();
      _activateImmediately = s.isActive;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // --- HELPERS ---

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  // Menghitung durasi otomatis (End - Start)
  int _calculateTotalDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    
    int duration = endMinutes - startMinutes;
    if (duration < 0) duration += 1440; // Handle lintas hari (overlap midnight)
    return duration == 0 ? 60 : duration; // Default minimal 60 menit jika sama
  }

  void _saveSchedule() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama jadwal tidak boleh kosong")),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih minimal satu hari")),
      );
      return;
    }

    // Kalkulasi Total Duration Otomatis
    final calculatedTotalDuration = _calculateTotalDuration();

    final newSchedule = ScheduleModel(
      id: widget.scheduleToEdit?.id ?? DateTime.now().toString(),
      title: _titleController.text.trim(),
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      activeDays: _selectedDays,
      isActive: _activateImmediately,
      totalDuration: calculatedTotalDuration, // Hasil hitung otomatis
      intervalDuration: _intervalFocus.toInt(),
      breakDuration: _breakDuration.toInt(),
    );

    Navigator.pop(context, newSchedule);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.scheduleToEdit != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Shadow colors (pengganti withOpacity)
    final shadowColor = isDark ? const Color(0x4D000000) : const Color(0x0D000000);
    final borderColor = isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEdit ? "Edit Jadwal" : "Buat Jadwal Baru",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. NAMA JADWAL
            _SectionCard(
              title: "Nama Jadwal",
              icon: Icons.calendar_today_rounded,
              shadowColor: shadowColor,
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: "cth: Jadwal Kerja Pagi",
                  hintStyle: TextStyle(color: theme.hintColor),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF303030) : const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. PILIH HARI
            _SectionCard(
              title: "Pilih Hari",
              icon: Icons.date_range_rounded,
              shadowColor: shadowColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _days.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected
                            ? _selectedDays.remove(day)
                            : _selectedDays.add(day);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? cs.primary : borderColor,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  // Menggunakan withAlpha sbg pengganti withOpacity
                                  color: cs.primary.withAlpha(64),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            color: isSelected
                                ? cs.onPrimary
                                : theme.textTheme.bodyMedium?.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 3. WAKTU AKTIF
            _SectionCard(
              title: "Waktu Aktif",
              icon: Icons.access_time_rounded,
              shadowColor: shadowColor,
              child: Row(
                children: [
                  Expanded(
                    child: _TimePickerButton(
                      label: "Mulai",
                      time: _startTime,
                      borderColor: borderColor,
                      onTap: () async {
                        final p = await showTimePicker(context: context, initialTime: _startTime);
                        if (p != null) setState(() => _startTime = p);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TimePickerButton(
                      label: "Selesai",
                      time: _endTime,
                      borderColor: borderColor,
                      onTap: () async {
                        final p = await showTimePicker(context: context, initialTime: _endTime);
                        if (p != null) setState(() => _endTime = p);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. KONFIGURASI SESI (Total Sesi Dihapus)
            _SectionCard(
              title: "Konfigurasi Sesi",
              icon: Icons.tune_rounded,
              shadowColor: shadowColor,
              child: Column(
                children: [
                  _MiniSlider(
                    label: "Interval Fokus",
                    value: _intervalFocus,
                    min: 1,
                    max: 120,
                    color: const Color(0xFF6B4EFF),
                    onChanged: (v) => setState(() => _intervalFocus = v),
                  ),
                  const SizedBox(height: 16),
                  _MiniSlider(
                    label: "Durasi Istirahat",
                    value: _breakDuration,
                    min: 1,
                    max: 30,
                    color: Colors.pinkAccent,
                    onChanged: (v) => setState(() => _breakDuration = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. SWITCH AKTIFKAN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Aktifkan Langsung",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Jadwal akan langsung berjalan",
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _activateImmediately,
                    activeTrackColor: cs.primary,
                    onChanged: (v) => setState(() => _activateImmediately = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // TOMBOL SIMPAN
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: cs.primary.withAlpha(100),
                ),
                onPressed: _saveSchedule,
                icon: Icon(Icons.save_rounded, color: cs.onPrimary),
                label: Text(
                  isEdit ? "Simpan Perubahan" : "Simpan Jadwal",
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET COMPONENTS (Extracted for cleaner code) ---

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color shadowColor;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color borderColor;
  final VoidCallback onTap;

  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: Theme.of(context).iconTheme.color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _MiniSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            Text(
              "${value.toInt()} menit",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withAlpha(25),
            thumbColor: color,
            trackHeight: 4,
            overlayColor: color.withAlpha(51),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}