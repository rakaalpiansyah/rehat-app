// File: android/app/src/main/java/com/example/rehat_app/MainActivity.java

package com.example.rehat_app; // ⚠️ Pastikan package ini sesuai dengan struktur folder Anda

import android.os.Build; // Tambahan import untuk cek versi Android
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    // 1. Definisikan Channel Name (Harus SAMA PERSIS dengan di Dart)
    private static final String CHANNEL = "com.rehat/task_manager";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    // 2. Handle pemanggilan 'finishAndRemoveTask' dari Flutter
                    if (call.method.equals("finishAndRemoveTask")) {
                        
                        // Logika untuk Menutup App & Menghapus dari History
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            finishAndRemoveTask(); // ✅ Ini yang menghapus dari Recent Apps
                        } else {
                            finish(); // Fallback untuk Android lama
                        }
                        
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }
}