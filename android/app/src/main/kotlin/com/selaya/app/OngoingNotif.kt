package com.selaya.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.text.HtmlCompat

/**
 * Play-uyumlu kalıcı "sıradaki vakit" geri-sayım bildirimi (id 2000).
 *
 * ÖNEMLİ: Eskiden bunu bir foreground-service (PrayerOngoingService,
 * FOREGROUND_SERVICE_TYPE_SPECIAL_USE) yapıyordu; Play bunun için tanıtım videosu
 * istediğinden o servis kaldırıldı. Onun yerine bu obje aynı zengin bildirimi
 * DOĞRUDAN NotificationManager ile yayınlar — FOREGROUND SERVICE YOK → Play
 * specialUse video şartı / izin sorunu yok.
 *
 * Canlı geri sayım, gövdedeki sistem [android.widget.Chronometer] ile yapılır:
 * sistem saniyede bir KENDİLİĞİNDEN tikler (yeniden-gönderme YOK → jank yok),
 * ekran kapalıyken / uygulama öldürülmüşken de çalışır. Vakit geçince "sıradaki"
 * vakte ilerlemek için tek bir tam AlarmManager alarmı kurulur → her vakitte
 * [OngoingNotifReceiver] tetiklenir → yeni sıradaki vakitle yeniden gönderir +
 * sonraki alarmı kurar (kendini zincirler). Kullanıcı kaydırırsa deleteIntent
 * geri getirir. Veri Dart'tan "selaya_ongoing" prefs'ine yazılır; her gönderimde
 * yeniden okunur → BOOT / saat değişimi sonrası da doğru hizalanır.
 */
object OngoingNotif {
    const val NOTIF_ID = 2000
    const val CHANNEL = "selaya_ongoing"
    const val PREFS = "selaya_ongoing"
    const val SEP = "|#|"
    const val ACTION_TICK = "com.selaya.app.ongoing.TICK"
    private const val ALARM_REQ = 2009

    /** Sıradaki vakti hesaplar, kalıcı geri-sayım bildirimini yayınlar ve bir
     *  sonraki vakit için ilerletme alarmını kurar. Geçerli veri yoksa
     *  bildirimi + alarmı temizler. */
    fun post(context: Context) {
        val ctx = context.applicationContext
        ensureChannel(ctx)
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val location = prefs.getString("location", null)
        val names = prefs.getString("names", "").orEmpty()
            .split(SEP).filter { it.isNotEmpty() }
        val times = prefs.getString("times", "").orEmpty()
            .split(",").mapNotNull { it.toLongOrNull() }
        if (location == null || names.isEmpty() || times.size != names.size) {
            try { nm.cancel(NOTIF_ID) } catch (_: Exception) {}
            cancelAlarm(ctx)
            return
        }
        val gridHm = prefs.getString("gridHm", "").orEmpty().split(SEP)
        val template = prefs.getString("template", "{}") ?: "{}"
        val icon = prefs.getString("icon", "🕌") ?: "🕌"

        val now = System.currentTimeMillis()
        var nextIdx = times.indexOfFirst { it > now }
        // TÜKENME BEKÇİSİ: pencere (≈30 gün) aşıldıysa donmuş/yanlış geri sayım
        // göstermek yerine kullanıcıyı uygulamayı açmaya çağır (açılışta pencere
        // yeniden kurulur → start() tekrar çağrılır).
        val exhausted = nextIdx < 0
        if (nextIdx < 0) nextIdx = times.size - 1
        val nextName = names[nextIdx]
        val nextMs = times[nextIdx]

        // ⏱️ Canlı geri sayım GÖVDEDE bir Chronometer ile: base = şu anki
        // elapsedRealtime + (vakte kalan); setChronometerCountDown ile geri sayar.
        // Sistem saniyede bir kendiliğinden tikler → yeniden-gönderme yok (jank
        // yok), ekran kapalıyken de çalışır.
        val base = SystemClock.elapsedRealtime() + (nextMs - now)
        val fmt = if (exhausted) "$icon SELAYA'yı açın — vakitler güncellensin"
            else "$icon " + template.replace("{}", nextName) + " : %s"

        // Genişletilmiş görünüm: bugünkü altı vakit 2×3 ızgara; sıradaki kalın.
        val highlight = if (nextIdx < 6) nextIdx else -1
        fun cell(i: Int): String {
            val nm2 = names.getOrElse(i) { "" }
            val hm = gridHm.getOrElse(i) { "" }
            return if (i == highlight) "<b>$nm2</b> <b>$hm</b>" else "<b>$nm2</b> $hm"
        }
        val gridHtml = StringBuilder()
        if (names.size >= 6 && gridHm.size >= 6) {
            gridHtml.append("${cell(0)}  |  ${cell(1)}  |  ${cell(2)}<br>")
            gridHtml.append("${cell(3)}  |  ${cell(4)}  |  ${cell(5)}")
        }

        val collapsed = RemoteViews(ctx.packageName, R.layout.ongoing_notif).apply {
            setChronometer(R.id.chrono, base, fmt, !exhausted)
            if (Build.VERSION.SDK_INT >= 24) setChronometerCountDown(R.id.chrono, true)
        }
        val expanded = RemoteViews(ctx.packageName, R.layout.ongoing_notif_big).apply {
            setChronometer(R.id.chrono, base, fmt, !exhausted)
            if (Build.VERSION.SDK_INT >= 24) setChronometerCountDown(R.id.chrono, true)
            // Genişletilmişte üst başlık zaten "SELAYA" (sistem dekorasyonu) →
            // 2. satıra konum yazılır (çift SELAYA olmasın).
            setTextViewText(R.id.appname, location)
            setTextViewText(
                R.id.grid,
                HtmlCompat.fromHtml(gridHtml.toString(), HtmlCompat.FROM_HTML_MODE_LEGACY)
            )
        }

        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setSound(null)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(launchPendingIntent(ctx))
            // Kullanıcı kaydırırsa hemen geri getir → kalıcı.
            .setDeleteIntent(tickPendingIntent(ctx))
            .build()
        try { nm.notify(NOTIF_ID, n) } catch (_: Exception) {}

        if (exhausted) cancelAlarm(ctx) else scheduleAdvance(ctx, nextMs)
    }

    /** Bildirimi ve ilerletme alarmını kaldırır (kullanıcı "Sürekli bildirim"i
     *  kapatınca veya geçerli veri kalmayınca). */
    fun cancel(context: Context) {
        val ctx = context.applicationContext
        try {
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.cancel(NOTIF_ID)
        } catch (_: Exception) {}
        cancelAlarm(ctx)
    }

    /** Sıradaki vakit geçer geçmez (+2 sn) yeniden gönderecek tek tam alarm. */
    private fun scheduleAdvance(ctx: Context, nextMs: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = tickPendingIntent(ctx)
        val at = nextMs + 2000L
        try {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (_: Exception) {
            try { am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi) } catch (_: Exception) {}
        }
    }

    private fun cancelAlarm(ctx: Context) {
        try {
            (ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)
                ?.cancel(tickPendingIntent(ctx))
        } catch (_: Exception) {}
    }

    private fun tickPendingIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, OngoingNotifReceiver::class.java).setAction(ACTION_TICK)
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(ctx, ALARM_REQ, i, f)
    }

    private fun launchPendingIntent(ctx: Context): PendingIntent? {
        val intent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP) }
            ?: return null
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(ctx, 0, intent, f)
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Sıradaki Vakit", NotificationManager.IMPORTANCE_LOW)
                .apply {
                    description = "Durum çubuğunda sürekli görünen sıradaki namaz vakti geri sayımı"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                }
        )
    }
}
