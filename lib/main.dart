// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart'; // ✅ 1. Import Provider
import 'package:timezone/data/latest.dart' as tz;

// Import file-file project kamu
import 'core/theme.dart';
import 'screens/nav_bar.dart';
import 'services/notification_service.dart';
import 'screens/alarm_lock_screen.dart';
import 'providers/settings_provider.dart'; // ✅ 2. Import SettingsProvider yang baru dibuat

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Data Timezone & Service
  tz.initializeTimeZones();
  await NotificationService().init();

  // Logika Cek apakah aplikasi dibuka oleh Notifikasi/Alarm
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

  // ✅ 3. WRAP APLIKASI DENGAN MULTIPROVIDER
  // Ini penting agar SettingsProvider bisa diakses dari mana saja
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: RehatApp(initialPayload: alarmPayload),
    ),
  );
}

class RehatApp extends StatelessWidget {
  final String? initialPayload;

  const RehatApp({super.key, this.initialPayload});

  @override
  Widget build(BuildContext context) {
    // ✅ 4. AMBIL DATA SETTING (Theme Mode)
    // Kita 'watch' (pantau) perubahan di SettingsProvider
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Rehat',
      debugShowCheckedModeBanner: false,
      
      // ✅ 5. KONFIGURASI TEMA
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme, 
      
      // Logika ganti tema otomatis berdasarkan setting user
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light, 
      
      // Logika Penentuan Halaman (Alarm vs Normal)
      home: initialPayload != null 
          ? AlarmLockScreen(payload: initialPayload!) 
          : const MainNavBar(),
    );
  }
}