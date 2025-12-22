// File: lib/services/notification_service.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../main.dart';
import '../screens/alarm_lock_screen.dart';
import 'database_helper.dart';

// -----------------------------------------------------------------------------
// TOP-LEVEL FUNCTION (BACKGROUND HANDLER)
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId != null) {
    WidgetsFlutterBinding.ensureInitialized();
    final service = NotificationService();
    // Init tanpa request permission agar hemat resource di background
    await service.init(requestPermissions: false);
    await service.handleActionLogic(
      notificationResponse.actionId!,
      notificationResponse.payload,
      closeApp: true,
    );
  }
}

class NotificationService {
  // ---------------------------------------------------------------------------
  // 1. SINGLETON & CONSTANTS
  // ---------------------------------------------------------------------------
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool isLockScreenOpen = false;
  static const String channelIdBase = 'rehat_fullscreen_v1';
  static const int snoozeIdOffset = 900000;
  static const int snoozeDurationMinutes = 5;
  Timer? _audioTimeoutTimer;
  static const int autoDismissSeconds = 20;

  // ---------------------------------------------------------------------------
  // 2. INITIALIZATION
  // ---------------------------------------------------------------------------
  Future<void> init({bool requestPermissions = true}) async {
    _initTimeZone();

    const androidInit = AndroidInitializationSettings('@drawable/splash');
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

  Future<void> _autoRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  // ---------------------------------------------------------------------------
  // 3. NAVIGATION & LOCK SCREEN
  // ---------------------------------------------------------------------------
  Future<void> _checkAppLaunchDetails() async {
    final details = await notificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      debugPrint("🚀 App launched via Full Screen Intent");
      await playAlarmSound();
      Future.delayed(const Duration(milliseconds: 100), () {
        _navigateToLockScreen(details.notificationResponse!.payload!);
      });
    }
  }

  void _navigateToLockScreen(String payload) {
    if (isLockScreenOpen) return;
    if (navigatorKey.currentState == null) {
      debugPrint("⚠️ Navigator belum siap");
      return;
    }

    playAlarmSound();
    isLockScreenOpen = true;

    navigatorKey.currentState!
        .push(
      MaterialPageRoute(builder: (_) => AlarmLockScreen(payload: payload)),
    )
        .then((_) {
      isLockScreenOpen = false;
      stopAlarmSound();
      _cancelAlarmFromPayload(payload);
    });
  }

  // ---------------------------------------------------------------------------
  // 4. ACTION LOGIC (SNOOZE / DISMISS)
  // ---------------------------------------------------------------------------
  Future<void> handleActionLogic(String actionId, String? payload,
      {bool closeApp = false}) async {

    if (payload == null || payload.isEmpty) return;

    final data = _parsePayload(payload);
    if (data == null) return;

    // Bersihkan notifikasi terkait
    if (data.id < snoozeIdOffset) {
      await cancelNotification(data.id);
    }

    await cancelNotification(snoozeIdOffset + data.id);


    // 2. CEK VALIDITAS DATABASE
    // Sebelum melakukan Dismiss (Lanjut next phase) atau Snooze,
    // Cek apakah jadwal ini masih VALID (Ada dan Aktif) di database.
    bool isValid = await _isScheduleValid(data.dbId);

    if (!isValid) {
      debugPrint("🛑 Jadwal ID ${data.dbId} sudah dihapus/nonaktif. Hentikan Loop.");
      // Jika tidak valid, kita hentikan proses di sini.
      // Karena notifikasi sudah di-cancel di langkah 1, alarm akan diam selamanya.
      if (closeApp) exit(0);
      return;
    }

    if (actionId == 'dismiss') {
      await _handleDismiss(data);
    } else if (actionId == 'snooze') {
      await _handleSnooze(data);
    }

    if (closeApp) exit(0);
  }

  Future<bool> _isScheduleValid(String dbId) async {
    if (dbId == 'none') return true; // Untuk alarm test/instant
    try {
      final schedule = await DatabaseHelper.instance.readSchedule(dbId);
      // Valid jika: Jadwal ditemukan (tidak null) DAN Jadwal statusnya aktif
      return (schedule != null && schedule.isActive);
    } catch (e) {
      debugPrint("⚠️ Gagal cek validitas jadwal: $e");
      return false; // Anggap tidak valid jika error, biar aman (alarm mati)
    }
  }

  Future<void> _handleDismiss(_PayloadData data) async {
    await cancelNotification(snoozeIdOffset + data.id);
    await cancelNotification(data.id);

    // Jadwalkan alarm berikutnya (Interval/Istirahat selanjutnya)
    if (data.nextDuration > 0) {
      final isRehatPhase = data.title.contains("Rehat");
      final nextTitle =
          isRehatPhase ? "Kembali Fokus 🎯" : "Waktunya Rehat Sejenak 🍵";
      final nextBody =
          isRehatPhase ? "Ayo lanjutkan aktivitasmu." : "Lepaskan penat sebentar.";

      await _scheduleFollowUpAlarm(
        nextTitle,
        nextBody,
        data.nextDuration,
        data.id,
        dbId: data.dbId,
        snoozeCount: 0,
        nextDuration: data.nextDuration,
      );
    }

    // Reset delay di DB jika user dismiss (tepat waktu)
    if (data.dbId != 'none') {
      await _resetDelayInDatabase(data.dbId);
      await rescheduleAllNotificationsBackground();
    }
  }

  Future<void> _handleSnooze(_PayloadData data) async {
    await cancelNotification(data.id);
    await cancelNotification(snoozeIdOffset + data.id);

    // Update delay di DB
    if (data.dbId != 'none') {
      await _addDelayToDatabase(data.dbId, snoozeDurationMinutes);
    }

    // Jadwalkan ulang notifikasi yang sama 5 menit lagi
    await _scheduleFollowUpAlarm(
      data.title,
      data.body,
      snoozeDurationMinutes,
      data.id,
      dbId: data.dbId,
      snoozeCount: data.snoozeCount + 1,
      nextDuration: data.nextDuration,
    );

    // Reschedule jadwal masa depan agar bergeser
    await rescheduleAllNotificationsBackground();
  }

  // ---------------------------------------------------------------------------
  // 5. AUDIO & VIBRATION
  // ---------------------------------------------------------------------------
  Future<void> playAlarmSound() async {
    _audioTimeoutTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final int index = prefs.getInt('selected_sound_index') ?? 5;

    debugPrint("🔊 Playing Alarm Sound. Index: $index");

    _audioTimeoutTimer = Timer(const Duration(seconds: autoDismissSeconds), () {
      debugPrint("⏰ Timeout 20s: Matikan suara otomatis.");
      stopAlarmSound();
    });

    if (index == 0) {
      // Default System Alarm
      FlutterRingtonePlayer().playAlarm(
          looping: true, volume: 1.0, asAlarm: true);
    } else {
      // Custom Asset Sound
      await FlutterRingtonePlayer().play(
        fromAsset: "assets/sounds/sound$index.mp3",
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    }
  }

  Future<void> stopAlarmSound() async {
    debugPrint("🔇 Stopping Alarm Sound");
    _audioTimeoutTimer?.cancel();
    await FlutterRingtonePlayer().stop();
  }

  // ---------------------------------------------------------------------------
  // 6. SCHEDULING SYSTEM (CORE LOGIC)
  // ---------------------------------------------------------------------------
  Future<void> rescheduleAllNotificationsBackground() async {
    debugPrint("\n🔄 --- MEMULAI PENJADWALAN ULANG ---");

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

      // Hitung batas akhir (Handle lewat tengah malam secara sederhana +24jam)
      final fixedEndMin = (endMinOriginal <= startMinOriginal)
          ? endMinOriginal + 1440
          : endMinOriginal;

      for (String dayName in item.activeDays) {
        final dayOfWeek = _getDayInt(dayName);

        // Cari tanggal terdekat untuk hari tersebut
        var baseDate = tz.TZDateTime(tz.local, now.year, now.month, now.day);
        while (baseDate.weekday != dayOfWeek) {
          baseDate = baseDate.add(const Duration(days: 1));
        }

        bool isSameDay = baseDate.year == now.year &&
            baseDate.month == now.month &&
            baseDate.day == now.day;

        // --- INTERNAL HELPER UNTUK SCHEDULE SATU TITIK WAKTU ---
        Future<void> schedulePoint(String type, String title, String body,
            int originalMinute, int duration) async {
          
          int calculatedMinute = isSameDay ? (originalMinute + currentDelay) : originalMinute;

          // 1. Cut-Off Check: Jika melebihi waktu akhir
          if (calculatedMinute >= fixedEndMin) return;

          var scheduleDate = baseDate.add(Duration(minutes: calculatedMinute));

          // 2. Past Check: Jika waktu aslinya sudah lewat hari ini
          var originalDate = baseDate.add(Duration(minutes: originalMinute));
          if (isSameDay && originalDate.isBefore(now.add(const Duration(seconds: 1)))) {
            // Pindahkan ke minggu depan
            scheduleDate = baseDate.add(const Duration(days: 7)).add(Duration(minutes: originalMinute));
            // Cek lagi limit minggu depan (tanpa delay hari ini)
            if (originalMinute >= fixedEndMin) return;
          }

          if (scheduleDate.isBefore(now)) return;

          // Logging
          bool isDelayedLog = isSameDay && (calculatedMinute > originalMinute);
          _logScheduleDirect(type, title, scheduleDate, isDelayedLog ? currentDelay : 0);

          // Buat Notifikasi
          final details = await _buildNotificationDetails(showSnooze: true);
          final payload = "${globalIdCounter++}|${item.id}|$title|$body|0|$duration";

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

        // --- GENERATE SEQUENCE (Start -> Focus -> Break -> Focus...) ---
        
        // 1. Start Point
        await schedulePoint("MULAI", "Mari Mulai Aktivitas 🌱", "Siapkan diri.",
            startMinOriginal, item.intervalDuration);

        // 2. Loop Focus/Break
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

        // 3. Finish Point
        var finishDate = baseDate.add(Duration(minutes: fixedEndMin));
        if (finishDate.isBefore(now)) {
          finishDate = finishDate.add(const Duration(days: 7));
        }
        _logScheduleDirect("FINISH", "Aktivitas Selesai ✨", finishDate, 0);
        
        final details = await _buildNotificationDetails(showSnooze: true);
        final payload = "${globalIdCounter++}|${item.id}|Aktivitas Selesai ✨|Selesai!|0|0";
        
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

  Future<void> showInstantNotification(String title, String body) async {
    int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final details = await _buildNotificationDetails(showSnooze: true);
    // Payload dummy
    final payload = "$id|none|$title|$body|0|0"; 
    await notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  // ---------------------------------------------------------------------------
  // 7. NOTIFICATION DETAILS & CHANNELS
  // ---------------------------------------------------------------------------
  Future<NotificationDetails> _buildNotificationDetails({bool showSnooze = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final int soundIndex = prefs.getInt('selected_sound_index') ?? 5;
    final bool isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    // Konfigurasi Suara
    AndroidNotificationSound? androidSound;
    if (soundIndex == 0) {
      androidSound = const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    } else {
      androidSound = RawResourceAndroidNotificationSound('sound$soundIndex');
    }

    // Konfigurasi ID Channel (Dinamis berdasarkan getaran agar update real-time)
    final String vibStatus = isVibrationEnabled ? 'vibOn' : 'vibOff';
    final String dynamicChannelId = '${channelIdBase}_FINAL_idx${soundIndex}_$vibStatus';

    // Konfigurasi Pola Getaran
    final Int64List? vibrationPattern = isVibrationEnabled
        ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
        : null;

    // Aksi (Tombol)
    final List<AndroidNotificationAction> actions = [
      const AndroidNotificationAction('dismiss', 'Hentikan / Lanjut',
          showsUserInterface: false, cancelNotification: true),
    ];
    if (showSnooze) {
      actions.insert(0, const AndroidNotificationAction('snooze', 'Tunda 5 Menit',
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
        enableVibration: isVibrationEnabled,
        vibrationPattern: vibrationPattern,
        visibility: NotificationVisibility.secret,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true, // PENTING: Untuk muncul di lock screen
        ongoing: true,
        autoCancel: false,
        timeoutAfter: autoDismissSeconds * 1000,
        additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: false,
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

  // ---------------------------------------------------------------------------
  // 8. DATABASE & PAYLOAD HELPERS
  // ---------------------------------------------------------------------------
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

  Future<void> _resetDelayInDatabase(String id) async {
    if (id == 'none') return;
    try {
      final item = await DatabaseHelper.instance.readSchedule(id);
      if (item != null) {
        item.delayMinutes = 0;
        await DatabaseHelper.instance.update(item);
      }
    } catch (e) {
      debugPrint("❌ Error Reset DB Delay: $e");
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

  // ---------------------------------------------------------------------------
  // 9. TIME & UTILS
  // ---------------------------------------------------------------------------
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

  void _logScheduleDirect(String type, String title, tz.TZDateTime date, int delay) {
    final dateStr =
        "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    String delayInfo = delay > 0 ? " (Delay +$delay)" : "";
    debugPrint("📅 [$dateStr] ($type)$delayInfo : $title");
  }
}

// -----------------------------------------------------------------------------
// MODEL CLASS FOR PAYLOAD
// -----------------------------------------------------------------------------
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