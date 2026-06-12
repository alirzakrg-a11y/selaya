package com.selaya.app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAdhanIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAdhanIntent(intent)
    }

    /** When launched/resumed by an at-time adhan notification (tap or full-screen
     *  intent), wake the screen + show over the lock screen, and stash the slot
     *  so Dart can pop the full-screen alarm on resume (the auto full-screen
     *  launch doesn't go through flutter_local_notifications' tap callback). */
    private fun handleAdhanIntent(intent: Intent?) {
        val payload = intent?.getStringExtra("payload") ?: return
        if (!payload.startsWith("adhan:")) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
            .edit()
            .putString("pending_adhan", payload)
            .putLong("pending_adhan_ts", SystemClock.elapsedRealtime())
            .apply()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Home-screen widget bridge.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selaya/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        // Write every string key the Dart side sent, then refresh
                        // all NIDA widgets (each provider reads its own keys).
                        val prefs = getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        (call.arguments as? Map<*, *>)?.forEach { (k, v) ->
                            if (k is String) editor.putString(k, v?.toString())
                        }
                        editor.apply()
                        refreshAllWidgets()
                        result.success(true)
                    }
                    "getPendingAdhan" -> {
                        // Consume the slot stashed by handleAdhanIntent (if any).
                        // Guard against a stale stash (an FSI write that was never
                        // consumed): ignore anything older than 2 min so we never
                        // pop an old prayer's alarm on a much later resume. Uses
                        // elapsedRealtime so manual clock changes don't fool it.
                        val prefs = getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
                        var p = prefs.getString("pending_adhan", null)
                        if (p != null) {
                            val ts = prefs.getLong("pending_adhan_ts", 0L)
                            val fresh = SystemClock.elapsedRealtime() - ts < 120_000L
                            prefs.edit().remove("pending_adhan").remove("pending_adhan_ts").apply()
                            if (!fresh) p = null
                        }
                        result.success(p)
                    }
                    "canUseFullScreen" -> {
                        // Android 14+ gates auto full-screen adhan alarms behind a
                        // special access; pre-14 it is granted at install.
                        if (Build.VERSION.SDK_INT >= 34) {
                            val nm = getSystemService(NotificationManager::class.java)
                            result.success(nm?.canUseFullScreenIntent() ?: false)
                        } else {
                            result.success(true)
                        }
                    }
                    "requestFullScreen" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                        Uri.parse("package:$packageName")
                                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    }
                    // ⑨ Ezan: KAPALI at-time ezanı durdurulabilir native servisle
                    // çalmak için AlarmManager alarmı kur / iptal et / durdur.
                    "scheduleAdhanAlarm" -> {
                        val id = (call.argument<Number>("id"))?.toInt() ?: 0
                        val time = (call.argument<Number>("time"))?.toLong() ?: 0L
                        val res = call.argument<String>("res") ?: AdhanPlayerService.DEFAULT
                        val label = call.argument<String>("label") ?: "Namaz"
                        AdhanAlarmReceiver.addAlarm(this, id, time, res, label)
                        result.success(true)
                    }
                    "cancelAllAdhanAlarms" -> {
                        AdhanAlarmReceiver.cancelAll(this)
                        result.success(true)
                    }
                    "stopAdhan" -> {
                        try {
                            startService(
                                Intent(this, AdhanPlayerService::class.java)
                                    .setAction(AdhanPlayerService.ACTION_STOP)
                            )
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    "setAdhanVolume" -> {
                        val v = (call.arguments as? Number)?.toFloat() ?: 1f
                        try {
                            startService(
                                Intent(this, AdhanPlayerService::class.java)
                                    .setAction(AdhanPlayerService.ACTION_VOLUME)
                                    .putExtra(AdhanPlayerService.EXTRA_VOLUME, v)
                            )
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    // Posteri olmayan videodan KAPAK üret: ~1.5sn'deki kareyi
                    // WEBP olarak cache'e yazar, dosya yolunu döner (tekrarında
                    // cache'ten). Arka iş parçacığında — UI donmaz.
                    "videoThumb" -> {
                        val url = call.argument<String>("url") ?: ""
                        if (url.isEmpty()) { result.success(null); return@setMethodCallHandler }
                        val out = File(cacheDir, "vthumb_${url.hashCode()}.webp")
                        if (out.exists() && out.length() > 0) {
                            result.success(out.absolutePath)
                        } else {
                            Thread {
                                var path: String? = null
                                try {
                                    val r = android.media.MediaMetadataRetriever()
                                    r.setDataSource(url, HashMap<String, String>())
                                    val bmp = r.getFrameAtTime(1_500_000)
                                    try { r.release() } catch (_: Exception) {}
                                    if (bmp != null) {
                                        @Suppress("DEPRECATION")
                                        java.io.FileOutputStream(out).use { o ->
                                            bmp.compress(
                                                android.graphics.Bitmap.CompressFormat.WEBP, 80, o)
                                        }
                                        if (out.length() > 0) path = out.absolutePath
                                    }
                                } catch (_: Exception) {}
                                runOnUiThread { result.success(path) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Direct image share to a specific app (WhatsApp / Instagram / Facebook).
        // Returns false when the app isn't installed or can't handle the image so
        // Dart can fall back to the system share sheet.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.selaya.app/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareImageToApp" -> result.success(shareImageToApp(call))
                    else -> result.notImplemented()
                }
            }

        // Görseli cihaz duvar kâğıdı olarak ayarla (ana ekran / kilit / ikisi).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selaya/wallpaper")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setWallpaper" -> result.success(setWallpaper(call))
                    else -> result.notImplemented()
                }
            }

        // Smart Silent (#6.2): schedule AlarmManager windows that mute/restore the
        // ringer around prayer times. Needs DND / notification-policy access.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selaya/smart_silent")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> {
                        val granted = if (Build.VERSION.SDK_INT >= 23) {
                            (getSystemService(Context.NOTIFICATION_SERVICE)
                                as? NotificationManager)
                                ?.isNotificationPolicyAccessGranted ?: false
                        } else true
                        result.success(granted)
                    }
                    "requestAccess" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    "schedule" -> {
                        @Suppress("UNCHECKED_CAST")
                        val windows = call.argument<List<Map<String, Any>>>("windows")
                            ?: emptyList()
                        scheduleSmartSilent(windows)
                        result.success(true)
                    }
                    "cancel" -> {
                        cancelSmartSilent()
                        restoreRingerNow()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Ongoing "next prayer" foreground service: keeps notification 2000's
        // worded "kalan : X dk" body ticking every minute even when the app is
        // killed. Dart hands in the rolling-window prayer data; the service
        // re-reads it from SharedPreferences on every tick.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selaya/ongoing")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { startOngoing(call); result.success(true) }
                    "stop" -> { stopOngoing(); result.success(true) }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Ongoing prayer foreground service bridge ───────────────────────────────
    private fun startOngoing(call: MethodCall) {
        val sep = "|#|"
        getSharedPreferences("selaya_ongoing", Context.MODE_PRIVATE).edit().apply {
            putString("location", call.argument<String>("location"))
            putString(
                "names",
                (call.argument<List<String>>("names") ?: emptyList()).joinToString(sep)
            )
            putString(
                "times",
                (call.argument<List<Number>>("times") ?: emptyList())
                    .joinToString(",") { it.toLong().toString() }
            )
            putString(
                "gridHm",
                (call.argument<List<String>>("gridHm") ?: emptyList()).joinToString(sep)
            )
            putString("template", call.argument<String>("template") ?: "{}")
            putString("hourUnit", call.argument<String>("hourUnit") ?: "saat")
            putString("minUnit", call.argument<String>("minUnit") ?: "dk")
            putString("icon", call.argument<String>("icon") ?: "🕌")
            apply()
        }
        try {
            ContextCompat.startForegroundService(
                this, Intent(this, PrayerOngoingService::class.java)
            )
        } catch (_: Exception) {}
    }

    private fun stopOngoing() {
        try {
            stopService(Intent(this, PrayerOngoingService::class.java))
        } catch (_: Exception) {}
        // Belt-and-suspenders in case the notification lingers after stop.
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.cancel(2000)
        } catch (_: Exception) {}
    }

    // ── Smart Silent (#6.2): AlarmManager windows that mute/restore the ringer ──
    private val silentReqBase = 47000

    private fun scheduleSmartSilent(windows: List<Map<String, Any>>) {
        val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        cancelSmartSilent()
        val now = System.currentTimeMillis()
        var req = silentReqBase
        for (w in windows) {
            val start = (w["start"] as? Number)?.toLong()
            val end = (w["end"] as? Number)?.toLong()
            if (start != null && start > now) scheduleSilentAlarm(am, req, start, "silence")
            req++
            if (end != null && end > now) scheduleSilentAlarm(am, req, end, "restore")
            req++
        }
        getSharedPreferences("selaya_silent", Context.MODE_PRIVATE).edit()
            .putInt("alarm_count", req - silentReqBase).apply()
    }

    private fun scheduleSilentAlarm(am: AlarmManager, req: Int, at: Long, action: String) {
        val pi = silentPendingIntent(req, action)
        try {
            if (Build.VERSION.SDK_INT >= 23) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (_: Exception) {
            am.set(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun silentPendingIntent(req: Int, action: String?): PendingIntent {
        val intent = Intent(this, SmartSilentReceiver::class.java)
        if (action != null) intent.putExtra("action", action)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(this, req, intent, flags)
    }

    private fun cancelSmartSilent() {
        val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val count = getSharedPreferences("selaya_silent", Context.MODE_PRIVATE)
            .getInt("alarm_count", 64)
        for (i in 0 until maxOf(count, 64)) {
            var flags = PendingIntent.FLAG_NO_CREATE
            if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getBroadcast(
                this, silentReqBase + i,
                Intent(this, SmartSilentReceiver::class.java), flags
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
    }

    private fun restoreRingerNow() {
        val prefs = getSharedPreferences("selaya_silent", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("muted", false)) return
        val granted = Build.VERSION.SDK_INT < 23 ||
            (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.isNotificationPolicyAccessGranted ?: false
        if (granted) {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            try {
                am?.ringerMode = prefs.getInt("prev_mode", AudioManager.RINGER_MODE_NORMAL)
            } catch (_: Exception) {}
        }
        prefs.edit().putBoolean("muted", false).apply()
    }

    /** Broadcast an update to every NIDA home-screen widget provider. */
    private fun refreshAllWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        val providers = listOf(
            HadithWidgetProvider::class.java,
            PrayerWidgetProvider::class.java,
            AyahWidgetProvider::class.java,
            EsmaWidgetProvider::class.java,
            HijriWidgetProvider::class.java,
            ClockMinimalWidgetProvider::class.java,
            ClockGreenWidgetProvider::class.java,
            ClockPrayerWidgetProvider::class.java
        )
        for (p in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(this, p))
            if (ids.isEmpty()) continue
            sendBroadcast(Intent(this, p).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            })
        }
    }

    /** Verilen görsel baytlarını cihaz duvar kâğıdı yapar: target = home/lock/both. */
    private fun setWallpaper(call: MethodCall): Boolean {
        return try {
            val bytes = call.argument<ByteArray>("bytes") ?: return false
            val target = call.argument<String>("target") ?: "home"
            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return false
            val wm = WallpaperManager.getInstance(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val flag = when (target) {
                    "lock" -> WallpaperManager.FLAG_LOCK
                    "both" -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    else -> WallpaperManager.FLAG_SYSTEM
                }
                wm.setBitmap(bmp, null, true, flag)
            } else {
                @Suppress("DEPRECATION")
                wm.setBitmap(bmp)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun shareImageToApp(call: io.flutter.plugin.common.MethodCall): Boolean {
        val target = call.argument<String>("target")
        val path = call.argument<String>("path") ?: return false
        val text = call.argument<String>("text") ?: ""
        val pkg = when (target) {
            "whatsapp" -> "com.whatsapp"
            "instagram" -> "com.instagram.android"
            "facebook" -> "com.facebook.katana"
            else -> return false
        }
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "$packageName.selayashare", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, text)
                setPackage(pkg)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (intent.resolveActivity(packageManager) == null) return false
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
