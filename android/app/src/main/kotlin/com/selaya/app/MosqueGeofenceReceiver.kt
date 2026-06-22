package com.selaya.app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/**
 * Fired by the geofencing service when the user enters/leaves a mosque geofence.
 *
 * On ENTER (or DWELL) it remembers the current ringer mode (once) and switches
 * the phone to silent; on EXIT it puts the previous mode back. Uses its own
 * prefs namespace ("selaya_mosque_silent") so it never clobbers the time-based
 * Smart Silent state. A no-op without DND / notification-policy access, so it
 * can never get stuck muted.
 */
class MosqueGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        val transition = event.geofenceTransition

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        if (android.os.Build.VERSION.SDK_INT >= 23 && !nm.isNotificationPolicyAccessGranted) return
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val prefs = context.getSharedPreferences("selaya_mosque_silent", Context.MODE_PRIVATE)

        when (transition) {
            Geofence.GEOFENCE_TRANSITION_ENTER, Geofence.GEOFENCE_TRANSITION_DWELL -> {
                if (!prefs.getBoolean("muted", false)) {
                    val cur = am.ringerMode
                    // Never store SILENT as the "previous" mode (would stick muted).
                    val prev = if (cur == AudioManager.RINGER_MODE_SILENT)
                        AudioManager.RINGER_MODE_NORMAL else cur
                    prefs.edit()
                        .putInt("prev_mode", prev)
                        .putBoolean("muted", true)
                        .apply()
                }
                try {
                    am.ringerMode = AudioManager.RINGER_MODE_SILENT
                } catch (_: Exception) {}
            }
            Geofence.GEOFENCE_TRANSITION_EXIT -> {
                if (prefs.getBoolean("muted", false)) {
                    // If the time-based Smart Silent still wants silence (e.g. a
                    // prayer window is active), don't un-mute on leaving the
                    // mosque — release our claim and let it own the restore.
                    val timeMuted = context
                        .getSharedPreferences("selaya_silent", Context.MODE_PRIVATE)
                        .getBoolean("muted", false)
                    if (!timeMuted) {
                        val prev = prefs.getInt("prev_mode", AudioManager.RINGER_MODE_NORMAL)
                        try {
                            am.ringerMode = prev
                        } catch (_: Exception) {}
                    }
                    prefs.edit().putBoolean("muted", false).apply()
                }
            }
        }
    }
}
