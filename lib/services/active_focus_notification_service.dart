import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ActiveFocusNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  ActiveFocusNotificationService() {
    _init();
  }

  void _init() {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    
    _notificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      // Tidak perlu onDidReceiveNotificationResponse karena tidak ada tombol
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'rehat_channel', 
        'Rehat Notification', 
        importance: Importance.max, 
        priority: Priority.high, 
        playSound: true, 
        fullScreenIntent: true, // Tetap muncul di layar penuh jika HP terkunci
        category: AndroidNotificationCategory.alarm,
        // ❌ ACTIONS DIHAPUS (Tombol hilang)
      ),
      iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
    );
  }

  /// Menampilkan notifikasi instan tanpa tombol aksi
  Future<void> showInstantFocusNotification(String title, String body) async {
    int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notificationsPlugin.show(
      id, 
      title, 
      body, 
      _details(), 
      // Payload tetap ada jika nanti butuh deteksi klik notifikasi (buka aplikasi)
      payload: "$id|active|$title|$body" 
    );
  }
}