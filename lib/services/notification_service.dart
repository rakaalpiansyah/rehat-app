// File: lib/services/notification_service.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data'; // Untuk Int64List
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../screens/alarm_lock_screen.dart';
import 'database_helper.dart'; 
import '../models/schedule_model.dart'; 

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try { 
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta')); 
  } catch (e) { 
    debugPrint("⚠️ Timezone Error: $e"); 
  }

  final service = NotificationService();
  await service.init(); 

  if (notificationResponse.actionId != null) {
    await service.handleActionLogic(
      notificationResponse.actionId!, 
      notificationResponse.payload
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  static bool isLockScreenOpen = false;
  static String? _lastProcessedPayload;
  static DateTime? _lastProcessedTime;

  // ✅ Channel ID V15 (Versi Baru untuk Reset Settingan)
  static const String channelId = 'rehat_alarm_fix_v15';

  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int snoozeIdOffset = 900000;
  static const int maxSnoozeCount = 3; 

  Future<void> init() async {
    tz.initializeTimeZones();
    try { tz.setLocalLocation(tz.getLocation('Asia/Jakarta')); } catch (e) { debugPrint("⚠️ Timezone Error"); }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true, 
      requestAlertPermission: true, 
      requestBadgePermission: true
    );

    await notificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId != null) {
          handleActionLogic(response.actionId!, response.payload);
        } else if (response.payload != null) {
          _navigateToLockScreen(response.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _autoRequestPermissions();
  }

  void _navigateToLockScreen(String payload) {
   if (isLockScreenOpen) return;
    isLockScreenOpen = true; 
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => AlarmLockScreen(payload: payload)),
    ).then((_) {
      isLockScreenOpen = false; 
    });
  }

  Future<void> handleActionLogic(String actionId, String? payload) async {
    if (payload == null) return;

    final now = DateTime.now();
    if (_lastProcessedPayload == payload && 
        _lastProcessedTime != null && 
        now.difference(_lastProcessedTime!).inSeconds < 3) {
      return; 
    }

    _lastProcessedPayload = payload;
    _lastProcessedTime = now;

    final parts = payload.split('|');
    if (parts.length < 6) return;

    final int notifId = int.tryParse(parts[0]) ?? 0;
    final String dbId = parts[1];
    final String title = parts[2];
    final String body = parts[3];
    final int snoozeCount = int.tryParse(parts[4]) ?? 0;
    final int nextDuration = int.tryParse(parts[5]) ?? 0;

    if (actionId == 'dismiss') {
      await cancelNotification(snoozeIdOffset + notifId);
      await cancelNotification(notifId);

      if (nextDuration > 0) {
        String nextTitle = title.contains("Rehat") ? "Lanjut Fokus 🚀" : "Saatnya Rehat! ☕";
        String nextBody = title.contains("Rehat") ? "Istirahat selesai. Gas lagi!" : "Fokus selesai. Istirahat dulu!";
        await _scheduleFollowUpAlarm(nextTitle, nextBody, nextDuration, notifId);
      }
    } 
    else if (actionId == 'snooze') {
      if (snoozeCount < maxSnoozeCount) {
        await _addDelayToDatabase(dbId, 5);
        await rescheduleAllNotificationsBackground();
      }
    }
  }
  
  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }

  // ✅ LOGIC UTAMA: Menghilangkan FLAG INSISTENT
  Future<NotificationDetails> _details({required bool showSnooze}) async {
    final prefs = await SharedPreferences.getInstance();
    final int soundIndex = prefs.getInt('selected_sound_index') ?? 5; 
    final bool isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    AndroidNotificationSound? androidSound;
    
    if (soundIndex == 0) {
      // Index 0: URI System Alarm
      androidSound = const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    } else {
      // Custom: File raw
      androidSound = RawResourceAndroidNotificationSound('sound$soundIndex');
    }

    String vibStatus = isVibrationEnabled ? 'vibOn' : 'vibOff';
    // ✅ ID Channel V15
    String dynamicChannelId = 'rehat_v15_idx${soundIndex}_$vibStatus'; 

    List<AndroidNotificationAction> actions = [
      const AndroidNotificationAction('dismiss', 'Matikan / Mulai', showsUserInterface: false, cancelNotification: true),
    ];
    if (showSnooze) {
      actions.insert(0, const AndroidNotificationAction('snooze', 'Tunda 5 Menit', showsUserInterface: false, cancelNotification: true));
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        dynamicChannelId, 
        soundIndex == 0 ? 'Rehat (System Alarm)' : 'Rehat (Custom Sound)', 
        channelDescription: 'Alarm fokus',
        importance: Importance.max, 
        priority: Priority.max, 
        ongoing: true, // Tidak bisa di-swipe kiri/kanan
        autoCancel: false, // Tidak hilang saat diklik
        
        // ✅ PERUBAHAN UTAMA: additionalFlags: Int32List.fromList(<int>[4]) DIHAPUS.
        // Kita mengandalkan ongoing: true dan category: call untuk daya tahan suara.
        
        visibility: NotificationVisibility.public, 
        
        playSound: true, 
        sound: androidSound,
        
        category: AndroidNotificationCategory.call, // Kategori Call
        
        audioAttributesUsage: AudioAttributesUsage.alarm, // Volume Alarm
        
        // Logic Getar
        enableVibration: isVibrationEnabled,
        vibrationPattern: isVibrationEnabled ? null : Int64List.fromList([0]),

        fullScreenIntent: true, 
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive, 
      ),
    );
  }

  Future<void> _scheduleFollowUpAlarm(String title, String body, int durationMinutes, int sourceId) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime nextTime = now.add(Duration(minutes: durationMinutes));
    
    int newId = sourceId + 1; 
    final details = await _details(showSnooze: true);

    await notificationsPlugin.zonedSchedule(
      newId, title, body, nextTime, details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: "$newId|none|$title|$body|0|0",
    );
  }

  Future<void> _addDelayToDatabase(String id, int minutesToAdd) async {
    try {
      ScheduleModel? item = await DatabaseHelper.instance.readSchedule(id);
      if (item != null) {
        item.delayMinutes = item.delayMinutes + minutesToAdd;
        await DatabaseHelper.instance.update(item);
      }
    } catch (e) { debugPrint("❌ Error Update DB: $e"); }
  }

  Future<void> rescheduleAllNotificationsBackground() async {
    List<ScheduleModel> allSchedules = await DatabaseHelper.instance.readAllSchedules();
    if (allSchedules.isEmpty) return;
    await cancelAllNotifications();
    int globalIdCounter = 0;
    final DateTime now = DateTime.now(); 

    for (var item in allSchedules) {
      if (!item.isActive || item.activeDays.isEmpty) continue;
      
       int originalStartMin = _timeToMinutes(_parseTime(item.startTime));
       int originalEndMin = _timeToMinutes(_parseTime(item.endTime));
       int fixedEndMin = originalEndMin;
       if (fixedEndMin <= originalStartMin) fixedEndMin += 1440; 

       for (String dayName in item.activeDays) {
         int dayOfWeek = _getDayInt(dayName); 
         
         TimeOfDay openingTimeObj = _minutesToTime(originalStartMin);
         await scheduleWeeklyNotification(
           id: globalIdCounter++, dbId: item.id, title: "Selamat Beraktivitas! 💪", 
           body: "Waktunya mulai sesi ${item.title}.", time: openingTimeObj, 
           dayOfWeek: dayOfWeek, nextDuration: item.intervalDuration
         );

         int trackingMin = originalStartMin;
         while (trackingMin < fixedEndMin) {
           int originalRehatStart = trackingMin + item.intervalDuration;
           if (originalRehatStart >= fixedEndMin) break;

           TimeOfDay originalRehatTime = _minutesToTime(originalRehatStart);
           DateTime rehatDateTime = _calcNextDateTime(now, dayOfWeek, originalRehatTime);
           bool isFuture = rehatDateTime.isAfter(now);
           int effectiveRehatMin = isFuture ? originalRehatStart + item.delayMinutes : originalRehatStart;

           if (effectiveRehatMin >= fixedEndMin) break;

           TimeOfDay finalRehatTime = _minutesToTime(effectiveRehatMin);
           await scheduleWeeklyNotification(
             id: globalIdCounter++, dbId: item.id, title: "Saatnya Rehat! ☕", body: "Istirahat dulu!", 
             time: finalRehatTime, dayOfWeek: dayOfWeek, nextDuration: item.breakDuration
           );
           trackingMin = originalRehatStart;

           int originalFokusStart = trackingMin + item.breakDuration;
           if (originalFokusStart >= fixedEndMin) break;

           TimeOfDay originalFokusTime = _minutesToTime(originalFokusStart);
           DateTime fokusDateTime = _calcNextDateTime(now, dayOfWeek, originalFokusTime);
           bool isFokusFuture = fokusDateTime.isAfter(now);
           int effectiveFokusMin = isFokusFuture ? originalFokusStart + item.delayMinutes : originalFokusStart;

           if (effectiveFokusMin >= fixedEndMin) break;

           TimeOfDay finalFokusTime = _minutesToTime(effectiveFokusMin);
           await scheduleWeeklyNotification(
             id: globalIdCounter++, dbId: item.id, title: "Lanjut Fokus 🚀", body: "Gas lagi!", 
             time: finalFokusTime, dayOfWeek: dayOfWeek, nextDuration: item.intervalDuration
           );
           trackingMin = originalFokusStart;
         }

         TimeOfDay endTimeObj = _minutesToTime(fixedEndMin);
         await scheduleWeeklyNotification(
           id: globalIdCounter++, dbId: item.id, title: "Aktivitas Selesai! 🎉", body: "Sampai jumpa lagi!", 
           time: endTimeObj, dayOfWeek: dayOfWeek, nextDuration: 0
         );
       }
    }
  }
  
  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;
  TimeOfDay _minutesToTime(int totalMinutes) {
    int normalizedMinutes = totalMinutes % 1440;
    return TimeOfDay(hour: normalizedMinutes ~/ 60, minute: normalizedMinutes % 60);
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
  DateTime _calcNextDateTime(DateTime now, int targetDay, TimeOfDay targetTime) {
    int daysToAdd = (targetDay - now.weekday + 7) % 7;
    DateTime targetDate = DateTime(now.year, now.month, now.day, targetTime.hour, targetTime.minute);
    targetDate = targetDate.add(Duration(days: daysToAdd));
    return targetDate; 
  }

  Future<void> triggerActionManual(String actionId, String payload) async {
    await handleActionLogic(actionId, payload);
  }

  Future<void> scheduleWeeklyNotification({
    required int id, required String dbId, required String title, required String body, 
    required TimeOfDay time, required int dayOfWeek, required int nextDuration,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    while (scheduledDate.weekday != dayOfWeek) { scheduledDate = scheduledDate.add(const Duration(days: 1)); }
    if (scheduledDate.isBefore(now)) { scheduledDate = scheduledDate.add(const Duration(days: 7)); }

    final details = await _details(showSnooze: true);

    await notificationsPlugin.zonedSchedule(
      id, title, body, scheduledDate, details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: "$id|$dbId|$title|$body|0|$nextDuration", 
    );
  }
  
  Future<void> showInstantNotification(String title, String body, {int nextDuration = 0}) async {
    int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final details = await _details(showSnooze: true); 
    await notificationsPlugin.show(id, title, body, details, payload: "$id|none|$title|$body|0|$nextDuration");
  }
  
  Future<void> _autoRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }
}