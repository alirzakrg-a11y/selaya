package com.selaya.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired when the system clock, timezone or locale changes. A manual time/zone
 * change would otherwise leave the absolute prayer alarms (and the ongoing
 * countdown) misaligned until the next app launch — dedicated azan apps listen
 * for these too.
 *
 * Prayer alarms themselves are re-computed when the app next resumes (it
 * reschedules a rolling window on every launch/resume); this manifest receiver
 * additionally nudges the ongoing foreground service — even across a service
 * restart — to recompute its countdown so the persistent notification is
 * correct the moment the clock/zone changes.
 */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Saat/zaman dilimi değişince ezan alarm penceresini yeniden tak
        // (geçmişe düşenler elenir, sıradaki 50 gelecek girişi yeniden kurulur).
        try { AdhanAlarmReceiver.reschedule(context) } catch (_: Exception) {}
        // Saat/zaman dilimi değişince kalıcı geri-sayım bildirimini de yeniden
        // hizala (sıradaki vakit + chronometer doğru kalsın).
        try { OngoingNotif.post(context) } catch (_: Exception) {}
    }
}
