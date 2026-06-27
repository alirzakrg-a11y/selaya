package com.selaya.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Kalıcı "sıradaki vakit" geri-sayım bildirimini (id 2000) yeniden yayınlayan
 * alıcı. İki yolla tetiklenir, ikisi de açık (explicit) intent — exported=false:
 *   • [OngoingNotif.ACTION_TICK] : vakit geçince kurulan tek ilerletme alarmı,
 *   • deleteIntent : kullanıcı bildirimi kaydırınca (kalıcı kalsın diye geri getir).
 * Cihaz açılışında (BOOT) yeniden gönderim, mevcut [AdhanAlarmReceiver] içinden
 * [OngoingNotif.post] çağrılarak yapılır (ayrı sistem-receiver gerekmez).
 * Foreground service YOK → Play uyumlu.
 */
class OngoingNotifReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try { OngoingNotif.post(context.applicationContext) } catch (_: Exception) {}
    }
}
