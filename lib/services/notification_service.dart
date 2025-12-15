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
void notificationTapBackground(
    NotificationResponse notificationResponse) async {
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
  static const snoozeDurationMinutes = 5;

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

    if (data.id < snoozeIdOffset) {
      await cancelNotification(data.id);
    }

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
    await cancelNotification(data.id);

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
        snoozeCount: 0,
        nextDuration: data.nextDuration,
      );
    }
    if (data.dbId != 'none') {
      await _resetDelayInDatabase(data.dbId);
      await rescheduleAllNotificationsBackground();
    }
  }

  Future<void> _handleSnooze(_PayloadData data) async {
    await cancelNotification(data.id);
    await cancelNotification(snoozeIdOffset + data.id);

    if (data.dbId != 'none') {
      await _addDelayToDatabase(data.dbId, snoozeDurationMinutes);
    }
    await _scheduleFollowUpAlarm(
      data.title,
      data.body,
      snoozeDurationMinutes,
      data.id,
      dbId: data.dbId,
      snoozeCount: data.snoozeCount + 1,
      nextDuration: data.nextDuration,
    );
    await rescheduleAllNotificationsBackground();
  }

// --- DEBUGGING HELPER ---
  void _logSchedule(String type, String title, String dayName, int dayOfWeek,
      int totalMinutes) {
    final now = tz.TZDateTime.now(tz.local);
    final time = _minutesToTime(totalMinutes);

    // Simulasi perhitungan tanggal yang sama dengan logic scheduling
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Jika waktu sudah lewat hari ini, berarti dijadwalkan minggu depan
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    final dateStr =
        "${scheduledDate.day}/${scheduledDate.month} ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}";

    // Print Log dengan warna/format agar mudah dibaca
    debugPrint("📅 [$dayName $dateStr] ($type) : $title");
  }

  Future<void> rescheduleAllNotificationsBackground() async {
    debugPrint("\n🔄 --- MEMULAI PENJADWALAN (LOGIKA CUT-OFF FIX) ---");

    await cancelAllNotifications();
    final allSchedules = await DatabaseHelper.instance.readAllSchedules();

    if (allSchedules.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);
    int globalIdCounter = 1000;

    for (var item in allSchedules) {
      if (!item.isActive || item.activeDays.isEmpty) continue;

      final startMinOriginal = _timeToMinutes(_parseTime(item.startTime));
      final endMinOriginal = _timeToMinutes(_parseTime(item.endTime));
      final currentDelay = item.delayMinutes;

      // Hitung batas akhir
      final fixedEndMin = (endMinOriginal <= startMinOriginal)
          ? endMinOriginal + 1440
          : endMinOriginal;

      // ✅ FIX: Format jam manual tanpa context agar tidak crash di background
      final finishTimeObj = _minutesToTime(fixedEndMin);
      final finishTimeStr =
          "${finishTimeObj.hour.toString().padLeft(2, '0')}:${finishTimeObj.minute.toString().padLeft(2, '0')}";

      debugPrint(
          "\n📌 Jadwal: ${item.title} (Delay: +$currentDelay mnt) | Finish: $finishTimeStr");

      for (String dayName in item.activeDays) {
        final dayOfWeek = _getDayInt(dayName);

        var baseDate = tz.TZDateTime(tz.local, now.year, now.month, now.day);
        while (baseDate.weekday != dayOfWeek) {
          baseDate = baseDate.add(const Duration(days: 1));
        }

        bool isSameDay = baseDate.year == now.year &&
            baseDate.month == now.month &&
            baseDate.day == now.day;

        // --- FUNGSI JADWAL SATU TITIK ---
        Future<void> schedulePoint(String type, String title, String body,
            int originalMinute, int duration) async {
          int calculatedMinute =
              isSameDay ? (originalMinute + currentDelay) : originalMinute;

          // 1. LOGIKA CUT-OFF (Batas Akhir)
          if (calculatedMinute >= fixedEndMin) {
            return;
          }

          var scheduleDate = baseDate.add(Duration(minutes: calculatedMinute));

          // 2. Cek Masa Lalu (Original Time Base)
          var originalDate = baseDate.add(Duration(minutes: originalMinute));

          if (isSameDay &&
              originalDate.isBefore(now.add(const Duration(seconds: 1)))) {
            scheduleDate = baseDate
                .add(const Duration(days: 7))
                .add(Duration(minutes: originalMinute));
            // Cek lagi untuk minggu depan
            if (originalMinute >= fixedEndMin) return;
          }

          if (scheduleDate.isBefore(now)) return;

          bool isDelayedLog = isSameDay && (calculatedMinute > originalMinute);
          _logScheduleDirect(
              type, title, scheduleDate, isDelayedLog ? currentDelay : 0);

          final details = await _buildNotificationDetails(showSnooze: true);
          final payload =
              "${globalIdCounter++}|${item.id}|$title|$body|0|$duration";

          await notificationsPlugin.zonedSchedule(
            globalIdCounter,
            title,
            body,
            scheduleDate,
            details,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payload,
          );
        }

        // --- LOOPING URUTAN ---
        await schedulePoint("MULAI", "Mari Mulai Aktivitas 🌱", "Siapkan diri.",
            startMinOriginal, item.intervalDuration);

        int currentMin = startMinOriginal;
        bool isFocusPhase = true;

        while (currentMin < fixedEndMin) {
          if (isFocusPhase) {
            currentMin += item.intervalDuration;
            if (currentMin >= fixedEndMin) break;

            await schedulePoint("REHAT", "Waktunya Rehat Sejenak 🍵",
                "Lepaskan penat.", currentMin, item.breakDuration);
            isFocusPhase = false;
          } else {
            currentMin += item.breakDuration;
            if (currentMin >= fixedEndMin) break;

            await schedulePoint("FOKUS", "Kembali Fokus 🎯", "Ayo kerja lagi.",
                currentMin, item.intervalDuration);
            isFocusPhase = true;
          }
        }

        // --- NOTIFIKASI FINISH ---
        var finishDate = baseDate.add(Duration(minutes: fixedEndMin));
        if (finishDate.isBefore(now))
          finishDate = finishDate.add(const Duration(days: 7));

        _logScheduleDirect("FINISH", "Aktivitas Selesai ✨", finishDate, 0);

        final details = await _buildNotificationDetails(showSnooze: true);
        final payload =
            "${globalIdCounter++}|${item.id}|Aktivitas Selesai ✨|Selesai!|0|0";
        await notificationsPlugin.zonedSchedule(
            globalIdCounter,
            "Aktivitas Selesai ✨",
            "Terima kasih sudah produktif!",
            finishDate,
            details,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payload);
      }
    }
    debugPrint("✅ --- PENJADWALAN SELESAI ---\n");
  }

  Future<void> _resetDelayInDatabase(String id) async {
    if (id == 'none') return;
    try {
      final item = await DatabaseHelper.instance.readSchedule(id);
      if (item != null) {
        // ✅ KUNCI: Kembalikan delay ke 0 saat Dismiss ditekan
        item.delayMinutes = 0;
        await DatabaseHelper.instance.update(item);
      }
    } catch (e) {
      debugPrint("❌ Error Reset DB Delay: $e");
    }
  }

  void _logScheduleDirect(
      String type, String title, tz.TZDateTime date, int delay) {
    final dateStr =
        "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    String delayInfo = delay > 0 ? " (Delay +$delay)" : "";
    debugPrint("📅 [$dateStr] ($type)$delayInfo : $title");
  }

  Future<void> scheduleWeeklyNotification({
    required int id,
    required String dbId,
    required String title,
    required String body,
    required TimeOfDay time,
    required int dayOfWeek,
    required int nextDuration,
    int snoozeCount = 0,
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
    final payload = "$id|$dbId|$title|$body|$snoozeCount|$nextDuration";

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
      String title, String body, int durationMinutes, int sourceId,
      {String dbId = 'none', int snoozeCount = 0, int nextDuration = 0}) async {
    final now = tz.TZDateTime.now(tz.local);
    final nextTime = now.add(Duration(minutes: durationMinutes));
    final newId = snoozeIdOffset + sourceId;

    final details = await _buildNotificationDetails(showSnooze: true);
    final payload = "$newId|$dbId|$title|$body|$snoozeCount|$nextDuration";

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
      {int nextDuration = 0, int snoozeCount = 0}) async {
    int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final details = await _buildNotificationDetails(showSnooze: true);
    final payload = "$id|none|$title|$body|$snoozeCount|$nextDuration";

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
    final String dynamicChannelId =
        '${channelIdBase}_FINAL_idx${soundIndex}_$vibStatus';

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

        category: AndroidNotificationCategory.alarm,
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
        item.delayMinutes = minutesToAdd;

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
      if (parts.length < 6) {
        debugPrint("⚠️ Payload tidak lengkap: $payload");
        return null;
      }
      return _PayloadData(
        id: int.tryParse(parts[0]) ?? 0,
        dbId: parts[1],
        title: parts[2],
        body: parts[3],
        snoozeCount: int.tryParse(parts[4]) ?? 0,
        nextDuration: int.tryParse(parts[5]) ?? 0,
      );
    } catch (e) {
      debugPrint("Error parsing payload: $e");
      return null;
    }
  }

  Future<void> _autoRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
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
      'Sen': DateTime.monday,
      'Sel': DateTime.tuesday,
      'Rab': DateTime.wednesday,
      'Kam': DateTime.thursday,
      'Jum': DateTime.friday,
      'Sab': DateTime.saturday,
      'Min': DateTime.sunday
    };
    return days[dayName] ?? DateTime.monday;
  }

  DateTime _calcNextDateTime(
      DateTime now, int targetDay, TimeOfDay targetTime) {
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
