// File: android/app/src/main/java/com/example/rehat_app/MainActivity.java

package com.example.rehat_app; // Pastikan nama package ini sesuai dengan punya Anda

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    // 1. Definisikan Channel Name (Harus sama dengan di Dart)
    private static final String CHANNEL = "com.example.rehat_app/app_control";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    // 2. Handle pemanggilan 'moveTaskToBack' dari Flutter
                    if (call.method.equals("moveTaskToBack")) {
                        // Panggil fungsi native Android untuk memindahkan aplikasi ke latar belakang
                        boolean success = moveTaskToBack(true);
                        if (success) {
                            result.success(true);
                        } else {
                            // moveTaskToBack jarang gagal, tapi kita siapkan error handling
                            result.error("UNAVAILABLE", "moveTaskToBack failed", null);
                        }
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }
}