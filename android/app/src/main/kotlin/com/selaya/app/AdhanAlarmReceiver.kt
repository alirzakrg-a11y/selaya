package com.selaya.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Ezan sesini tetikleyen alarm alıcısı. AlarmManager bir namaz vaktinde bunu
 * tetikler → [AdhanPlayerService]'i başlatır (ezan çalar, durdurulabilir).
 * Alarm-tetikli olduğu için arka plan FGS-başlatma kısıtından MUAFTIR → uygulama
 * öldürülmüş olsa bile çalışır. Cihaz açılışında (BOOT) kayıtlı ezan alarmlarını
 * SharedPreferences'tan yeniden kurar.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED -> reschedule(context)
            ACTION_TEST -> {
                val sec = intent.getIntExtra("sec", 40)
                val res = intent.getStringExtra(AdhanPlayerService.EXTRA_RES)
                    ?: AdhanPlayerService.DEFAULT
                setAlarm(context, 999, System.currentTimeMillis() + sec * 1000L, res, "Test")
            }
            else -> {
                // ACTION_FIRE → ezanı çal (servisi başlat).
                val res = intent?.getStringExtra(AdhanPlayerService.EXTRA_RES)
                val label = intent?.getStringExtra(AdhanPlayerService.EXTRA_LABEL) ?: "Namaz"
                val svc = Intent(context, AdhanPlayerService::class.java).apply {
                    putExtra(AdhanPlayerService.EXTRA_RES, res)
                    putExtra(AdhanPlayerService.EXTRA_LABEL, label)
                }
                try {
                    ContextCompat.startForegroundService(context, svc)
                } catch (_: Exception) {}
                // Kayan pencere: her ezan tetiklendiğinde prefs'teki GELECEK
                // girişlerden ilk MAX_ALARMS'ı yeniden takılır → 50 alarmlık
                // pencere ileri kayar; uygulama hiç açılmasa da liste bitene
                // (≈30 gün) dek ezan sürer.
                reschedule(context)
            }
        }
    }

    companion object {
        const val PREFS = "selaya_widget"
        const val KEY_ALARMS = "adhan_alarms"          // [{id,time,res,label}]
        const val ACTION_FIRE = "com.selaya.app.adhan.FIRE"
        const val ACTION_TEST = "com.selaya.app.adhan.TEST"
        const val REQ_BASE = 7100

        /** Tek bir ezan alarmı kur + prefs listesine ekle (BOOT yeniden-kurma için). */
        const val MAX_ALARMS = 50

        fun addAlarm(context: Context, id: Int, time: Long, res: String, label: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = try { JSONArray(prefs.getString(KEY_ALARMS, "[]")) } catch (_: Exception) { JSONArray() }
            // İPTAL'i garanti etmek için SIRALI küçük id (liste konumu) kullan:
            // sabit aralık [0,MAX) cancel'ı her zaman temizler. Dart'ın gönderdiği
            // büyük/bilinmez bildirim id'sine güvenmiyoruz (bazıları iptal olmuyordu).
            // İlk MAX_ALARMS girişi hemen takılır; FAZLASI prefs'te bekler —
            // her ezan tetiklendiğinde / BOOT'ta pencere ileri kayar (reschedule).
            val pos = arr.length()
            if (pos < MAX_ALARMS) setAlarm(context, pos, time, res, label)
            arr.put(JSONObject().put("id", pos).put("time", time).put("res", res).put("label", label))
            prefs.edit().putString(KEY_ALARMS, arr.toString()).apply()
        }

        /** TÜM ezan alarmlarını iptal et + listeyi temizle. Sıralı id'ler (0..MAX)
         *  + test (999) sabit aralıkta iptal edilir → garanti temiz (sızıntı yok). */
        fun cancelAll(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (id in 0 until MAX_ALARMS) am.cancel(firePendingIntent(context, id, "", ""))
            am.cancel(firePendingIntent(context, 999, "", ""))
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().remove(KEY_ALARMS).apply()
        }

        /** Prefs'teki GELECEK girişlerden ilk MAX_ALARMS'ı (kronolojik) kur —
         *  BOOT'ta, saat değişiminde ve her ezan tetiklenmesinde çağrılır;
         *  böylece 50'lik pencere liste bitene dek kendi kendine ileri kayar. */
        fun reschedule(context: Context) {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_ALARMS, null) ?: return
            val now = System.currentTimeMillis()
            try {
                val arr = JSONArray(raw)
                var armed = 0
                for (i in 0 until arr.length()) {
                    if (armed >= MAX_ALARMS) break
                    val o = arr.getJSONObject(i)
                    val time = o.getLong("time")
                    if (time <= now) continue
                    // id = takılma sırası (0..MAX): geçmişler elendiği için aynı
                    // sabit aralık yeniden kullanılır; cancelAll hep temizler.
                    setAlarm(context, armed, time,
                        o.optString("res"), o.optString("label", "Namaz"))
                    armed++
                }
            } catch (_: Exception) {}
        }

        fun setAlarm(context: Context, id: Int, time: Long, res: String, label: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = firePendingIntent(context, id, res, label)
            try {
                if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pi)
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pi)
                }
            } catch (_: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pi)
            }
        }

        private fun firePendingIntent(context: Context, id: Int, res: String, label: String): PendingIntent {
            val i = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra(AdhanPlayerService.EXTRA_RES, res)
                putExtra(AdhanPlayerService.EXTRA_LABEL, label)
            }
            var f = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, REQ_BASE + id, i, f)
        }
    }
}
