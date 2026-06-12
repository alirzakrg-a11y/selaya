package com.selaya.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.text.HtmlCompat

/**
 * Foreground service that keeps the persistent "next prayer" notification
 * (id 2000) updated every minute, so the worded "🕌 X vaktine kalan : N dk"
 * body counts down live even when the app is killed.
 *
 * The system chronometer (header row) already ticks per-second on its own; this
 * service refreshes the *worded* body and advances to the next prayer as each
 * time passes. The prayer data (names + epoch-ms times for the rolling window,
 * today's grid, and the localized format strings) is handed in from Dart via
 * SharedPreferences and re-read on every tick, so a START_STICKY restart keeps
 * working without the app.
 */
class PrayerOngoingService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    // Re-posts the notification every second so the worded body shows a LIVE
    // H:MM:SS countdown (e.g. "16:59" → "16:58"). Runs only while the screen is
    // on (started/stopped by the screen receiver) to keep it battery-cheap —
    // nobody sees it with the screen off, and the system chronometer covers the
    // lock screen / AOD.
    private val ticker = object : Runnable {
        override fun run() {
            update()
            handler.postDelayed(this, SECOND_MS)
        }
    }

    private fun startTicker() {
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    private fun stopTicker() = handler.removeCallbacks(ticker)

    /** Screen on → start the per-second live countdown; screen off → stop it (and
     *  post once more so the last visible value is correct). Other actions
     *  (minute tick, time/zone change) just refresh once. Keeps the body correct
     *  and in step with the header chronometer even if Samsung throttles us. */
    private val refreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            // Tüm tetikleyiciler bildirimi yalnızca bir kez (dakika seviyesinde)
            // yeniden gönderir. Canlı saniye sayımını üstteki kronometre yapar —
            // saniyede bir yeniden gönderme yok (SystemUI'yi yorup donma yapıyordu).
            update()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_TICK)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        ContextCompat.registerReceiver(
            this, refreshReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // User swiped the notification away (Android 14+ lets FGS notifications be
        // dismissed) → re-post it at once so it stays persistent ("kalıcı"),
        // without disturbing the running per-minute loop.
        if (intent?.action == ACTION_REPOST) {
            startForegroundNow()
            return START_STICKY
        }
        // Post once with the latest data. The worded body refreshes every minute
        // (ACTION_TIME_TICK) + on screen-on; the header chronometer shows the live
        // per-second countdown without re-posting. (Re-posting every second churned
        // SystemUI and caused app-wide jank/freezes.)
        startForegroundNow()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        try { unregisterReceiver(refreshReceiver) } catch (_: Exception) {}
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    /** Always calls startForeground (even on bad/empty data) so the system never
     *  kills us for "did not call startForeground"; bails out afterwards if there
     *  is nothing valid to show. */
    private fun startForegroundNow() {
        val n = build() ?: placeholder()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIF_ID, n)
            }
        } catch (_: Exception) {}
        if (build() == null) stopSelf()
    }

    private fun update() {
        val n = build() ?: return
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIF_ID, n)
        } catch (_: Exception) {}
    }

    /** Builds the rich notification from the SharedPreferences snapshot, or null
     *  when there is no valid prayer data yet. */
    private fun build(): Notification? {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val location = prefs.getString("location", null) ?: return null
        val names = prefs.getString("names", "").orEmpty()
            .split(SEP).filter { it.isNotEmpty() }
        val times = prefs.getString("times", "").orEmpty()
            .split(",").mapNotNull { it.toLongOrNull() }
        if (names.isEmpty() || times.size != names.size) return null
        val gridHm = prefs.getString("gridHm", "").orEmpty().split(SEP)
        val template = prefs.getString("template", "{}") ?: "{}"
        val icon = prefs.getString("icon", "🕌") ?: "🕌"

        val now = System.currentTimeMillis()
        var nextIdx = times.indexOfFirst { it > now }
        // TÜKENME BEKÇİSİ: pencere (7 gün) aşıldıysa donmuş/yanlış geri sayım
        // göstermek yerine kullanıcıyı uygulamayı açmaya çağır (açılış anında
        // pencere zaten yeniden kurulur).
        val exhausted = nextIdx < 0
        if (nextIdx < 0) nextIdx = times.size - 1
        val nextName = names[nextIdx]
        val nextMs = times[nextIdx]
        // ⏱️ Canlı geri sayım GÖVDEDE bir Chronometer ile: sistem saniyede bir
        // kendiliğinden tikler (yeniden-gönderme YOK → jank yok), ekran kapalıyken
        // de çalışır. format = "🕌 İmsak vaktine kalan : %s" → %s yerine S:DD:SS.
        // Üstteki (header) sistem kronometresi KALDIRILDI (setUsesChronometer yok).
        val base = SystemClock.elapsedRealtime() + (nextMs - now)
        // Tükenmişse %s'siz sabit metin: Chronometer formatı %s içermeyince
        // metni olduğu gibi gösterir; sayaç durdurulur (started=false).
        val fmt = if (exhausted) "$icon SELAYA'yı açın — vakitler güncellensin"
            else "$icon " + template.replace("{}", nextName) + " : %s"

        // Genişletilmiş görünüm: canlı geri sayım + bugünkü altı vakit 2×3 ızgara;
        // sıradaki vaktin hücresi kalın.
        val highlight = if (nextIdx < 6) nextIdx else -1
        fun cell(i: Int): String {
            val nm = names.getOrElse(i) { "" }
            val hm = gridHm.getOrElse(i) { "" }
            return if (i == highlight) "<b>$nm</b> <b>$hm</b>" else "<b>$nm</b> $hm"
        }
        val gridHtml = StringBuilder()
        if (names.size >= 6 && gridHm.size >= 6) {
            gridHtml.append("${cell(0)}  |  ${cell(1)}  |  ${cell(2)}<br>")
            gridHtml.append("${cell(3)}  |  ${cell(4)}  |  ${cell(5)}")
        }

        val collapsed = RemoteViews(packageName, R.layout.ongoing_notif).apply {
            setChronometer(R.id.chrono, base, fmt, !exhausted)
            if (Build.VERSION.SDK_INT >= 24) setChronometerCountDown(R.id.chrono, true)
        }
        val expanded = RemoteViews(packageName, R.layout.ongoing_notif_big).apply {
            setChronometer(R.id.chrono, base, fmt, !exhausted)
            if (Build.VERSION.SDK_INT >= 24) setChronometerCountDown(R.id.chrono, true)
            // Genişletilmişte üst başlık zaten "SELAYA" (sistem dekorasyonu) →
            // 2. satıra SELAYA yerine KONUM yazılır (çift SELAYA olmasın).
            setTextViewText(R.id.appname, location)
            setTextViewText(R.id.grid, html(gridHtml.toString()))
        }

        return NotificationCompat.Builder(this, CHANNEL)
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
            .setContentIntent(launchPendingIntent())
            // If the user swipes it away, bring it right back → persistent.
            .setDeleteIntent(repostPendingIntent())
            .build()
    }

    private fun placeholder(): Notification =
        NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SELAYA")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun html(s: String) =
        HtmlCompat.fromHtml(s, HtmlCompat.FROM_HTML_MODE_LEGACY)

    private fun launchPendingIntent(): PendingIntent? {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            } ?: return null
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    /** Fired by the system when the user dismisses the notification; re-delivers
     *  ACTION_REPOST to this (still-running) service so it re-posts immediately. */
    private fun repostPendingIntent(): PendingIntent {
        val intent = Intent(this, PrayerOngoingService::class.java).setAction(ACTION_REPOST)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, 2, intent, flags)
    }

    /** Idempotently (re)create the low-importance silent channel in case the
     *  service is restarted before the Dart side has set its channels up. */
    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Sıradaki Vakit", NotificationManager.IMPORTANCE_LOW)
                .apply {
                    description = "Durum çubuğunda sürekli görünen sıradaki namaz vakti"
                    setSound(null, null)
                    enableVibration(false)
                }
        )
    }

    companion object {
        const val NOTIF_ID = 2000
        const val CHANNEL = "selaya_ongoing"
        const val PREFS = "selaya_ongoing"
        const val SECOND_MS = 1000L
        const val ACTION_REPOST = "com.selaya.app.ongoing.REPOST"
        // Printable delimiter that never appears in a prayer name.
        const val SEP = "|#|"
    }
}
