import 'dart:convert';

class ScheduleModel {
  final String id;
  String title;
  String startTime;
  String endTime;
  List<String> activeDays;
  bool isActive;
  int totalDuration;
  int intervalDuration;
  int breakDuration;
  int delayMinutes; // ✅ FIELD BARU

  ScheduleModel({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.activeDays,
    this.isActive = true,
    required this.totalDuration,
    required this.intervalDuration,
    required this.breakDuration,
    this.delayMinutes = 0, // ✅ Default 0
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'activeDays': jsonEncode(activeDays),
      'isActive': isActive ? 1 : 0,
      'totalDuration': totalDuration,
      'intervalDuration': intervalDuration,
      'breakDuration': breakDuration,
      'delayMinutes': delayMinutes, // ✅ Simpan ke DB
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'].toString(),
      title: map['title'] ?? 'Tanpa Judul',
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '17:00',
      activeDays: map['activeDays'] != null 
          ? List<String>.from(jsonDecode(map['activeDays'])) 
          : [],
      isActive: (map['isActive'] == 1),
      totalDuration: (map['totalDuration'] as num? ?? 120).toInt(),
      intervalDuration: (map['intervalDuration'] as num? ?? 45).toInt(),
      breakDuration: (map['breakDuration'] as num? ?? 5).toInt(),
      delayMinutes: (map['delayMinutes'] as num? ?? 0).toInt(), // ✅ Ambil dari DB
    );
  }
}