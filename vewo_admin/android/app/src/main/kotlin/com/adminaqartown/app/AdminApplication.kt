package com.adminaqartown.app

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class AdminApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ensureHeadsUpChannel()
    }

    private fun ensureHeadsUpChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel(
                "aqar_admin_alert",
                "تنبيهات فورية",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "محادثات ومنشورات وريلز وطلبات"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(
                    android.media.RingtoneManager.getDefaultUri(
                        android.media.RingtoneManager.TYPE_NOTIFICATION
                    ),
                    null
                )
            }
        )
    }
}
