// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ✅ Tambah ini
import 'core/theme.dart';
import 'screens/nav_bar.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/alarm_lock_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inisialisasi Data Timezone & Service
  tz.initializeTimeZones();
  await NotificationService().init();

  // 2. ✅ LOGIKA BARU: Cek apakah aplikasi dibuka oleh Notifikasi/Alarm?
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  
  String? alarmPayload;
  
  // Jika aplikasi diluncurkan lewat notifikasi & ada payload-nya
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    final response = notificationAppLaunchDetails!.notificationResponse;
    if (response != null && response.payload != null) {
      alarmPayload = response.payload;
      NotificationService.isLockScreenOpen = true;
    }
  }

  // Kirim data payload (jika ada) ke Widget Utama
  runApp(RehatApp(initialPayload: alarmPayload));
}

class RehatApp extends StatelessWidget {
  // Terima data payload dari main()
  final String? initialPayload;

  const RehatApp({super.key, this.initialPayload});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Rehat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      // 3. ✅ LOGIKA PENENTUAN HALAMAN:
      // Jika ada payload alarm (Layar mati/Alarm bunyi), buka Lock Screen.
      // Jika tidak (Buka biasa), buka MainNavBar.
      home: initialPayload != null 
          ? AlarmLockScreen(payload: initialPayload!) 
          : const MainNavBar(),
    );
  }
}