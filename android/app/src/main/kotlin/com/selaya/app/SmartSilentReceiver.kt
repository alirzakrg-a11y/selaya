package com.selaya.app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager

/**
 * Fired by AlarmManager at each Smart Silent window boundary.
 *
 * On "silence" it remembers the current ringer mode (once per window) and
 * switches the phone to silent; on "restore" it puts the previous mode back.
 * A no-op without DND / notification-policy access, so it can never get stuck.
 */
class SmartSilentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("action") ?: return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        if (android.os.Build.VERSION.SDK_INT >= 23 && !nm.isNotificationPolicyAccessGranted) return
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val prefs = context.getSharedPreferences("selaya_silent", Context.MODE_PRIVATE)

        when (action) {
            "silence" -> {
                // Save the mode we're interrupting, but only when not already in
                // a window (so we never save SILENT over the user's real mode).
                if (!prefs.getBoolean("muted", false)) {
                    prefs.edit()
                        .putInt("prev_mode", am.ringerMode)
                        .putBoolean("muted", true)
                        .apply()
                }
                try {
                    am.ringerMode = AudioManager.RINGER_MODE_SILENT
                } catch (_: Exception) {}
            }
            "restore" -> {
                if (prefs.getBoolean("muted", false)) {
                    val prev = prefs.getInt("prev_mode", AudioManager.RINGER_MODE_NORMAL)
                    try {
                        am.ringerMode = prev
                    } catch (_: Exception) {}
                    prefs.edit().putBoolean("muted", false).apply()
                }
            }
        }
    }
}
