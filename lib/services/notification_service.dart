import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // =========================
  // ✅ INIT SERVICE
  // =========================
  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      debugPrint("⚠️ Timezone Error: $e");
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );

    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await notificationsPlugin.initialize(initSettings);
    await _requestPermissions();
    await _createHighPriorityChannel();
  }

  // =========================
  // ✅ PERMISSION REQUEST
  // =========================
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();
    }
  }

  // =========================
  // ✅ CHANNEL SETUP
  // =========================
  Future<void> _createHighPriorityChannel() async {
    const channel = AndroidNotificationChannel(
      'rehat_channel',
      'Rehat Notification',
      description: 'Notifikasi jadwal istirahat',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
  }

  // =========================
  // ✅ DETAIL SETTINGS
  // =========================
  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'rehat_channel',
        'Rehat Notification',
        channelDescription: 'Notifikasi jadwal istirahat',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      ),
    );
  }

  // =========================
  // ✅ TES 1 MENIT (YANG TADI ERROR)
  // =========================
  Future<void> testOneMinute() async {
    final scheduled =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

    await notificationsPlugin.zonedSchedule(
      9999,
      "TES 1 MENIT",
      "Kalau ini bunyi berarti sistem kamu SUDAH SIAP ✅",
      scheduled,
      _details(),
      
      // --- PERBAIKAN DISINI ---
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime, // <--- WAJIB DITAMBAHKAN
    );

    debugPrint("✅ TES 1 MENIT DISET: $scheduled");
  }

  // =========================
  // ✅ WEEKLY NOTIFICATION
  // =========================
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required int dayOfWeek,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    debugPrint("🕒 MENCOBA JADWALKAN ID:$id pada ${scheduledDate.toString()}");

    try {
      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rehat_channel',
            'Rehat Notification',
            channelDescription: 'Notifikasi jadwal istirahat',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        
        // --- SETTING MODE ---
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      
      debugPrint("✅ SUKSES JADWALKAN ID:$id");
    } catch (e) {
      debugPrint("❌ GAGAL JADWALKAN ID:$id error: $e");
    }
  }

  // =========================
  // ✅ INSTANT NOTIFICATION
  // =========================
  Future<void> showNotification(String title, String body) async {
    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _details(),
    );
  }

  // =========================
  // ✅ CANCEL
  // =========================
  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }
}