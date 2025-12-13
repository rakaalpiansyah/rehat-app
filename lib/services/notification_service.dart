// File: lib/services/notification_service.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; 
import '../screens/alarm_lock_screen.dart';
import 'database_helper.dart';

// Top-level function untuk handle background action
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId != null) {
    WidgetsFlutterBinding.ensureInitialized();
    final service = NotificationService();
    // Init tanpa request permission di background untuk hemat resource
    await service.init(requestPermissions: false);
    await service.handleActionLogic(
      notificationResponse.actionId!,
      notificationResponse.payload,
      closeApp: true,
    );
  }
}

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static bool isLockScreenOpen = false;
  static const String channelIdBase = 'rehat_fullscreen_v1';
  static const int snoozeIdOffset = 900000;
  static const int maxSnoozeCount = 3;

  // Hapus tanda ? agar tidak warning nullable
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inisialisasi Service
  Future<void> init({bool requestPermissions = true}) async {
    _initTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );

    await notificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId != null) {
          handleActionLogic(response.actionId!, response.payload);
        } else {
          debugPrint("🔔 Notifikasi diklik (Body): Masuk ke aplikasi biasa.");
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (requestPermissions) {
      await _autoRequestPermissions();
      _checkAppLaunchDetails();
    }
  }

  void _initTimeZone() {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      debugPrint("⚠️ Timezone Error: $e");
    }
  }

  Future<void> _checkAppLaunchDetails() async {
    final details = await notificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      debugPrint("🚀 App launched via Full Screen Intent");
      Future.delayed(const Duration(milliseconds: 100), () {
        _navigateToLockScreen(details.notificationResponse!.payload!);
      });
    }
  }

  void _navigateToLockScreen(String payload) {
    if (isLockScreenOpen) return;
    if (navigatorKey.currentState == null) return;

    isLockScreenOpen = true;
    navigatorKey.currentState!
        .push(
      MaterialPageRoute(builder: (_) => AlarmLockScreen(payload: payload)),
    )
        .then((_) {
      isLockScreenOpen = false;
      _cancelAlarmFromPayload(payload);
    });
  }

  // --- LOGIKA UTAMA AKSI (SNOOZE / DISMISS) ---

  Future<void> handleActionLogic(String actionId, String? payload,
      {bool closeApp = false}) async {
    if (payload == null || payload.isEmpty) return;

    final data = _parsePayload(payload);
    if (data == null) return;

    await cancelNotification(data.id);

    if (actionId == 'dismiss') {
      await _handleDismiss(data);
      if (closeApp) exit(0);
    } else if (actionId == 'snooze') {
      await _handleSnooze(data);
      if (closeApp) exit(0);
    }
  }

  Future<void> _handleDismiss(_PayloadData data) async {
    await cancelNotification(snoozeIdOffset + data.id);

    if (data.nextDuration > 0) {
      final isRehatPhase = data.title.contains("Rehat");
      final nextTitle =
          isRehatPhase ? "Kembali Fokus 🎯" : "Waktunya Rehat Sejenak 🍵";
      final nextBody = isRehatPhase
          ? "Ayo lanjutkan aktivitasmu."
          : "Lepaskan penat sebentar.";

      await _scheduleFollowUpAlarm(
        nextTitle,
        nextBody,
        data.nextDuration,
        data.id,
      );
    }
  }

  Future<void> _handleSnooze(_PayloadData data) async {
    if (data.snoozeCount < maxSnoozeCount) {
      await _addDelayToDatabase(data.dbId, 5);
      await rescheduleAllNotificationsBackground();
    }
  }

  // --- DATABASE & SCHEDULING ---

  Future<void> rescheduleAllNotificationsBackground() async {
    final allSchedules = await DatabaseHelper.instance.readAllSchedules();
    if (allSchedules.isEmpty) return;

    await cancelAllNotifications();

    int globalIdCounter = 1000;
    final now = DateTime.now();

    for (var item in allSchedules) {
      if (!item.isActive || item.activeDays.isEmpty) continue;

      final startMin = _timeToMinutes(_parseTime(item.startTime));
      final endMin = _timeToMinutes(_parseTime(item.endTime));
      final fixedEndMin = (endMin <= startMin) ? endMin + 1440 : endMin;

      for (String dayName in item.activeDays) {
        final dayOfWeek = _getDayInt(dayName);

        // 1. Jadwal Awal
        await scheduleWeeklyNotification(
          id: globalIdCounter++,
          dbId: item.id,
          title: "Mari Mulai Aktivitas 🌱",
          body: "Siapkan diri untuk sesi ${item.title}. Semangat!",
          time: _minutesToTime(startMin),
          dayOfWeek: dayOfWeek,
          nextDuration: item.intervalDuration,
        );

        // 2. Loop Interval & Istirahat
        int currentMin = startMin;
        while (currentMin < fixedEndMin) {
          final int rawRehatStart = currentMin + item.intervalDuration;
          if (rawRehatStart >= fixedEndMin) break;

          final rehatTimeObj = _minutesToTime(rawRehatStart);
          final rehatDateTime = _calcNextDateTime(now, dayOfWeek, rehatTimeObj);
          
          final bool isFuture = rehatDateTime.isAfter(now);
          final int effectiveRehatMin = isFuture 
              ? rawRehatStart + item.delayMinutes 
              : rawRehatStart;

          if (effectiveRehatMin >= fixedEndMin) break;

          await scheduleWeeklyNotification(
            id: globalIdCounter++,
            dbId: item.id,
            title: "Waktunya Rehat Sejenak 🍵",
            body: "Lepaskan penat sebentar, regangkan ototmu.",
            time: _minutesToTime(effectiveRehatMin),
            dayOfWeek: dayOfWeek,
            nextDuration: item.breakDuration,
          );

          currentMin = rawRehatStart; 

          final int rawFokusStart = currentMin + item.breakDuration;
          if (rawFokusStart >= fixedEndMin) break;

          final fokusTimeObj = _minutesToTime(rawFokusStart);
          final fokusDateTime = _calcNextDateTime(now, dayOfWeek, fokusTimeObj);
          
          final bool isFokusFuture = fokusDateTime.isAfter(now);
          final int effectiveFokusMin = isFokusFuture 
              ? rawFokusStart + item.delayMinutes 
              : rawFokusStart;

          if (effectiveFokusMin >= fixedEndMin) break;

          await scheduleWeeklyNotification(
            id: globalIdCounter++,
            dbId: item.id,
            title: "Kembali Fokus 🎯",
            body: "Ayo lanjutkan aktivitasmu dengan energi baru.",
            time: _minutesToTime(effectiveFokusMin),
            dayOfWeek: dayOfWeek,
            nextDuration: item.intervalDuration,
          );

          currentMin = rawFokusStart;
        }

        // 3. Jadwal Selesai
        await scheduleWeeklyNotification(
          id: globalIdCounter++,
          dbId: item.id,
          title: "Aktivitas Selesai ✨",
          body: "Terima kasih sudah produktif hari ini. Selamat beristirahat!",
          time: _minutesToTime(fixedEndMin),
          dayOfWeek: dayOfWeek,
          nextDuration: 0,
        );
      }
    }
  }

  Future<void> scheduleWeeklyNotification({
    required int id,
    required String dbId,
    required String title,
    required String body,
    required TimeOfDay time,
    required int dayOfWeek,
    required int nextDuration,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    final details = await _buildNotificationDetails(showSnooze: true);
    final payload = "$id|$dbId|$title|$body|0|$nextDuration";

    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  Future<void> _scheduleFollowUpAlarm(
      String title, String body, int durationMinutes, int sourceId) async {
    final now = tz.TZDateTime.now(tz.local);
    final nextTime = now.add(Duration(minutes: durationMinutes));
    final newId = sourceId + 1;

    final details = await _buildNotificationDetails(showSnooze: true);
    final payload = "$newId|none|$title|$body|0|0";

    await notificationsPlugin.zonedSchedule(
      newId,
      title,
      body,
      nextTime,
      details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
  }

  Future<void> showInstantNotification(String title, String body,
      {int nextDuration = 0}) async {
    int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final details = await _buildNotificationDetails(showSnooze: true);
    final payload = "$id|none|$title|$body|0|$nextDuration";
    
    await notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  // ✅ UPDATED: Membaca settingan Vibration dari SharedPrefs
  Future<NotificationDetails> _buildNotificationDetails(
      {bool showSnooze = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final int soundIndex = prefs.getInt('selected_sound_index') ?? 5;
    
    // 1. Baca status getaran (Default: True/Hidup)
    final bool isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    // Konfigurasi Suara (Native res/raw)
    AndroidNotificationSound? androidSound;
    if (soundIndex == 0) {
      androidSound = const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert');
    } else {
      androidSound = RawResourceAndroidNotificationSound('sound$soundIndex');
    }

    // 2. ID Channel Dinamis
    // Jika user mematikan getaran -> ID channel berubah (..._vibOff) -> Android buat channel baru tanpa getar
    final String vibStatus = isVibrationEnabled ? 'vibOn' : 'vibOff';
    final String dynamicChannelId = '${channelIdBase}_FINAL_idx${soundIndex}_$vibStatus';

    // 3. Tentukan Pattern Getaran
    final Int64List? vibrationPattern = isVibrationEnabled
        ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
        : null; // Jika mati, pattern null

    final List<AndroidNotificationAction> actions = [
      const AndroidNotificationAction('dismiss', 'Hentikan / Lanjut',
          showsUserInterface: false, cancelNotification: true),
    ];
    if (showSnooze) {
      actions.insert(
          0,
          const AndroidNotificationAction('snooze', 'Tunda 5 Menit',
              showsUserInterface: false, cancelNotification: true));
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        dynamicChannelId,
        'Rehat Alarm (Full Screen)',
        channelDescription: 'Alarm Full Screen & Pop Up',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: androidSound,
        
        // ✅ 4. Terapkan Setting Getaran di sini
        enableVibration: isVibrationEnabled, 
        vibrationPattern: vibrationPattern,
        
        category: AndroidNotificationCategory.call,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        additionalFlags: Int32List.fromList(<int>[4]),
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }

  Future<void> _addDelayToDatabase(String id, int minutesToAdd) async {
    if (id == 'none') return;
    try {
      final item = await DatabaseHelper.instance.readSchedule(id);
      if (item != null) {
        item.delayMinutes = item.delayMinutes + minutesToAdd;
        await DatabaseHelper.instance.update(item);
      }
    } catch (e) {
      debugPrint("❌ Error Update DB Delay: $e");
    }
  }

  void _cancelAlarmFromPayload(String payload) {
    final data = _parsePayload(payload);
    if (data != null) {
      cancelNotification(data.id);
    }
  }

  _PayloadData? _parsePayload(String payload) {
    try {
      final parts = payload.split('|');
      if (parts.length < 4) return null;
      return _PayloadData(
        id: int.tryParse(parts[0]) ?? 0,
        dbId: parts[1],
        title: parts[2],
        body: parts[3],
        snoozeCount: (parts.length > 4) ? int.tryParse(parts[4]) ?? 0 : 0,
        nextDuration: (parts.length > 5) ? int.tryParse(parts[5]) ?? 0 : 0,
      );
    } catch (e) {
      debugPrint("Error parsing payload: $e");
      return null;
    }
  }

  Future<void> _autoRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  // --- TIME HELPERS ---
  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _minutesToTime(int totalMinutes) {
    int normalized = totalMinutes % 1440;
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  int _getDayInt(String dayName) {
    const days = {
      'Sen': DateTime.monday, 'Sel': DateTime.tuesday, 'Rab': DateTime.wednesday,
      'Kam': DateTime.thursday, 'Jum': DateTime.friday, 'Sab': DateTime.saturday,
      'Min': DateTime.sunday
    };
    return days[dayName] ?? DateTime.monday;
  }

  DateTime _calcNextDateTime(DateTime now, int targetDay, TimeOfDay targetTime) {
    int daysToAdd = (targetDay - now.weekday + 7) % 7;
    final targetDate = DateTime(
        now.year, now.month, now.day, targetTime.hour, targetTime.minute);
    return targetDate.add(Duration(days: daysToAdd));
  }
}

class _PayloadData {
  final int id;
  final String dbId;
  final String title;
  final String body;
  final int snoozeCount;
  final int nextDuration;

  _PayloadData({
    required this.id,
    required this.dbId,
    required this.title,
    required this.body,
    required this.snoozeCount,
    required this.nextDuration,
  });
}