// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

// Import file-file project kamu
import 'core/theme.dart';
import 'screens/nav_bar.dart';
import 'services/notification_service.dart';
import 'screens/alarm_lock_screen.dart';
import 'providers/settings_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Data Timezone
  tz.initializeTimeZones();

  // ✅ PERUBAHAN 1: Bungkus Init Notifikasi dengan Try-Catch
  // Agar jika plugin notifikasi gagal (error), aplikasi TIDAK STUCK dan tetap bisa terbuka.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("⚠️ ERROR CRITICAL: Gagal Inisialisasi NotificationService: $e");
    // Aplikasi akan lanjut ke baris berikutnya, tidak macet.
  }

  String? alarmPayload;

  // ✅ PERUBAHAN 2: Bungkus Cek Launch Details dengan Try-Catch
  try {
    // Logika Cek apakah aplikasi dibuka oleh Notifikasi/Alarm
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
    
    // Jika aplikasi diluncurkan lewat notifikasi & ada payload-nya
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final response = notificationAppLaunchDetails!.notificationResponse;
      if (response != null && response.payload != null) {
        alarmPayload = response.payload;
        NotificationService.isLockScreenOpen = true;
      }
    }
  } catch (e) {
    debugPrint("⚠️ ERROR: Gagal membaca Notification Launch Details: $e");
  }

  // 3. WRAP APLIKASI DENGAN MULTIPROVIDER
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
    // 4. AMBIL DATA SETTING (Theme Mode)
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Rehat',
      debugShowCheckedModeBanner: false,
      
      // 5. KONFIGURASI TEMA
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