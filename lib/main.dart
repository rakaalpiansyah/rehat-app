// File: lib/main.dart
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/nav_bar.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz ;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Inisialisasi Data Timezone
  tz.initializeTimeZones();
  final notificationService = NotificationService();
  await NotificationService().init(); // Inisialisasi Notifikasi
  runApp(const RehatApp());
}

class RehatApp extends StatelessWidget {
  const RehatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rehat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavBar(),
    );
  }
}