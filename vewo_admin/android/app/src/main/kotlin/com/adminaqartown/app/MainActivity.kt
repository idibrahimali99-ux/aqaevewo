package com.adminaqartown.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launchExtras: HashMap<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        launchExtras = extrasFrom(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchExtras = extrasFrom(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.adminaqartown.app/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryUnrestricted" -> {
                    requestBatteryUnrestricted()
                    result.success(true)
                }
                "takeLaunchExtras" -> {
                    val extras = launchExtras
                    launchExtras = null
                    result.success(extras)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extrasFrom(intent: Intent?): HashMap<String, String>? {
        val extras = intent?.extras ?: return null
        val map = HashMap<String, String>()
        for (key in extras.keySet()) {
            if (key.startsWith("google.") ||
                key.startsWith("android.") ||
                key.startsWith("com.android") ||
                key == "from" ||
                key == "collapse_key"
            ) {
                continue
            }
            val value = extras.get(key) ?: continue
            if (value is String && value.isNotEmpty()) {
                map[key] = value
            }
        }
        return if (map.isEmpty()) null else map
    }

    private fun requestBatteryUnrestricted() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val pm = getSystemService(PowerManager::class.java) ?: return
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
            )
        } catch (_: Exception) {
        }
    }
}
