// File: lib/screens/create_schedule_screen.dart
import 'package:flutter/material.dart';
// import '../core/theme.dart';
import '../models/schedule_model.dart';

class CreateScheduleScreen extends StatefulWidget {
  final ScheduleModel? scheduleToEdit; // Data opsional untuk mode EDIT

  const CreateScheduleScreen({super.key, this.scheduleToEdit});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  // Controllers & State
  final TextEditingController _titleController = TextEditingController();
  
  // Default Values
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  List<String> _selectedDays = [];
  
  double _totalFocus = 120;
  double _intervalFocus = 45;
  double _breakDuration = 5;
  bool _activateImmediately = true;

  final List<String> _days = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"];

  @override
  void initState() {
    super.initState();
    // Jika Mode Edit, isi form dengan data lama
    if (widget.scheduleToEdit != null) {
      final s = widget.scheduleToEdit!;
      _titleController.text = s.title;
      _startTime = _parseTime(s.startTime);
      _endTime = _parseTime(s.endTime);
      _selectedDays = List.from(s.activeDays);
      _totalFocus = s.totalDuration.toDouble();
      _intervalFocus = s.intervalDuration.toDouble();
      _breakDuration = s.breakDuration.toDouble();
      _activateImmediately = s.isActive;
    }
  }

  // Helper Parse String "09:00" ke TimeOfDay
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // Format TimeOfDay ke String "09:00"
  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  void _saveSchedule() {
    if (_titleController.text.isEmpty) {
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

    // Buat Object Model Baru
    final newSchedule = ScheduleModel(
      id: widget.scheduleToEdit?.id ?? DateTime.now().toString(), // ID Lama atau Baru
      title: _titleController.text,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      activeDays: _selectedDays,
      isActive: _activateImmediately,
      totalDuration: _totalFocus.toInt(),
      intervalDuration: _intervalFocus.toInt(),
      breakDuration: _breakDuration.toInt(),
    );

    // Kirim balik data ke halaman sebelumnya
    Navigator.pop(context, newSchedule);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.scheduleToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(isEdit ? "Edit Jadwal" : "Buat Jadwal Baru", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. NAMA JADWAL
            _buildSectionCard(
              title: "Nama Jadwal",
              icon: Icons.calendar_today_rounded,
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: "cth: Jadwal Kerja Pagi",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. PILIH HARI
            _buildSectionCard(
              title: "Pilih Hari",
              icon: Icons.date_range_rounded,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _days.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected ? _selectedDays.remove(day) : _selectedDays.add(day);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6B4EFF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6B4EFF) : Colors.grey.shade300,
                        ),
                        boxShadow: isSelected 
                          ? [const BoxShadow(color: Color(0x406B4EFF), blurRadius: 8, offset: Offset(0, 4))] 
                          : [],
                      ),
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 10, // Font kecil agar muat
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
            _buildSectionCard(
              title: "Waktu Aktif",
              icon: Icons.access_time_rounded,
              child: Row(
                children: [
                  Expanded(child: _buildTimePicker("Mulai", _startTime, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimePicker("Selesai", _endTime, false)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. KONFIGURASI SESI (SLIDERS)
            _buildSectionCard(
              title: "Konfigurasi Sesi",
              icon: Icons.tune_rounded,
              child: Column(
                children: [
                  _buildMiniSlider("Total Sesi Fokus", _totalFocus, 5, 300, Colors.blue, (v) => setState(() => _totalFocus = v)),
                  const SizedBox(height: 16),
                  _buildMiniSlider("Interval Fokus", _intervalFocus, 1, 120, const Color(0xFF6B4EFF), (v) => setState(() => _intervalFocus = v)),
                  const SizedBox(height: 16),
                  _buildMiniSlider("Durasi Istirahat", _breakDuration, 1, 30, Colors.pinkAccent, (v) => setState(() => _breakDuration = v)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. SWITCH AKTIFKAN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Aktifkan Langsung", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text("Jadwal akan langsung berjalan", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Switch.adaptive(
                    value: _activateImmediately,
                    activeColor: const Color(0xFF6B4EFF),
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
                  backgroundColor: const Color(0xFF6B4EFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: const Color(0xFF6B4EFF).withOpacity(0.4),
                ),
                onPressed: _saveSchedule,
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(isEdit ? "Simpan Perubahan" : "Simpan Jadwal", 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF6B4EFF)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, bool isStart) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) {
          setState(() {
            if (isStart) {
              _startTime = picked;
            } else {
              _endTime = picked;
            }
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSlider(String label, double value, double min, double max, Color color, Function(double) onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            Text("${value.toInt()} menit", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.1),
            thumbColor: color,
            trackHeight: 4,
            overlayColor: color.withOpacity(0.2),
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