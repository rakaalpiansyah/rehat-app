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
  });

  // --- UBAH BAGIAN INI UNTUK SQLITE ---
  
  // Convert object ke Map untuk database
  // List activeDays di-encode jadi String JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'activeDays': jsonEncode(activeDays), // List -> String JSON
      'isActive': isActive ? 1 : 0,         // SQLite tidak punya boolean, pakai 0/1
      'totalDuration': totalDuration,
      'intervalDuration': intervalDuration,
      'breakDuration': breakDuration,
    };
  }

  // Convert Map dari database ke Object
  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'].toString(),
      title: map['title'] ?? 'Tanpa Judul',
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '17:00',
      
      // String JSON -> List<String>
      activeDays: map['activeDays'] != null 
          ? List<String>.from(jsonDecode(map['activeDays'])) 
          : [],
      
      // Integer (0/1) -> Boolean
      isActive: (map['isActive'] == 1),
      
      totalDuration: (map['totalDuration'] as num? ?? 120).toInt(),
      intervalDuration: (map['intervalDuration'] as num? ?? 45).toInt(),
      breakDuration: (map['breakDuration'] as num? ?? 5).toInt(),
    );
  }

  String toJson() => json.encode(toMap());
  factory ScheduleModel.fromJson(String source) => ScheduleModel.fromMap(json.decode(source));
}