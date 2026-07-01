package com.selaya.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

/**
 * Ezanı GERÇEKTEN durdurulabilir şekilde çalan foreground-service.
 *
 * Tam Ekran Alarm KAPALI iken ezan, daha önce bildirim KANALI sesiyle çalıyordu;
 * Samsung'da "Durdur"a basınca bildirim kapanıyor ama uzun kanal sesi devam
 * ediyordu (sistem çalıyor, uygulama durduramıyor). Bunun yerine ezanı bu
 * servisin [MediaPlayer]'ı (res/raw) çalar → "Durdur" sesi ANINDA keser.
 *
 * Ezan bitince servis kendini kapatır. Çağrı: START → çal + ön plana al;
 * [ACTION_STOP] (Durdur düğmesi / Dart) → durdur + kapan.
 */
class AdhanPlayerService : Service() {
    private var player: MediaPlayer? = null
    private var label: String = "Namaz"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Kullanıcı "Kapat" dedi → otomatik-sessizi (Camide/Akıllı) GERİ AL +
            // iz bırakmadan kapat. (Kapat sesi kapatmıyordu; oto-sessiz kapatıyordu.)
            restoreSilencedRinger()
            stopEverything(lingering = false)
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_VOLUME) {
            // Tam-ekran alarmın ses kaydırıcısı: çalan ezanın sesini anında ayarla.
            val v = intent.getFloatExtra(EXTRA_VOLUME, 1f).coerceIn(0f, 1f)
            try { player?.setVolume(v, v) } catch (_: Exception) {}
            return START_NOT_STICKY
        }
        ensureChannel()
        label = intent?.getStringExtra(EXTRA_LABEL) ?: "Namaz"
        startForegroundNow(label)
        play(intent?.getStringExtra(EXTRA_RES))
        return START_NOT_STICKY
    }

    /** Seçili ezanı çalar; bittiğinde kendini kapatır. Ad '/' ile başlıyorsa
     *  KULLANICI ÖZEL SESİ (mutlak dosya yolu) → dosyadan; yoksa res/raw'dan. */
    private fun play(resName: String?) {
        val name = if (!resName.isNullOrEmpty()) resName else selectedRes()
        val isFile = name.startsWith("/")
        var afd: android.content.res.AssetFileDescriptor? = null
        if (!isFile) {
            var resId = resources.getIdentifier(name, "raw", packageName)
            if (resId == 0) resId = resources.getIdentifier(DEFAULT, "raw", packageName)
            if (resId == 0) { stopEverything(lingering = false); return }
            afd = resources.openRawResourceFd(resId)
        }
        try {
            player?.release()
            // MediaPlayer ELLE kurulur (create() değil): ses öznitelikleri
            // prepare'dan ÖNCE set edilmeli + PARTIAL wake-lock — ekran kapalı/
            // doze'da uzun ezan ORTADAN KESİLMESİN.
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setWakeMode(this@AdhanPlayerService, PowerManager.PARTIAL_WAKE_LOCK)
                if (isFile) setDataSource(name)
                else setDataSource(afd!!.fileDescriptor, afd!!.startOffset, afd!!.length)
                isLooping = false
                setOnCompletionListener { stopEverything(lingering = true) }
                setOnErrorListener { _, _, _ -> stopEverything(lingering = false); true }
                prepare()
                start()
            }
            afd?.close()
            registerStopHooks() // güç/ses tuşuyla durdurma
        } catch (_: Exception) {
            afd?.close()
            stopEverything(lingering = false)
        }
    }

    // ── Güç/ses tuşuyla HIZLI SUSTURMA (kullanıcı isteği): ezan çalarken kullanıcı
    // toplantıda vb. olabilir → SES-KISMA tuşuna (alarm akışı sesi değişir) veya
    // GÜÇ tuşuna (ekran kapanır) basınca ezanı ANINDA durdur. Servis kapanınca
    // dinleyiciler bırakılır. Uygulama ön planda OLMASA da çalışır (native).
    private var volumeObserver: ContentObserver? = null
    private var screenOffReceiver: BroadcastReceiver? = null
    private var lastAlarmVol: Int = -1

    private fun registerStopHooks() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        lastAlarmVol = am?.getStreamVolume(AudioManager.STREAM_ALARM) ?: -1
        // Ses tuşu (ALARM akışı) değişince → durdur. (Ezan STREAM_ALARM çaldığından
        // donanım ses tuşları bu akışı ayarlar → değişim gözlemcisi yakalar.)
        volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                val v = am?.getStreamVolume(AudioManager.STREAM_ALARM) ?: return
                if (v != lastAlarmVol) {
                    lastAlarmVol = v
                    restoreSilencedRinger()
                    stopEverything(lingering = false)
                }
            }
        }
        try {
            contentResolver.registerContentObserver(
                Settings.System.CONTENT_URI, true, volumeObserver!!)
        } catch (_: Exception) {}
        // Güç tuşu → ekran kapanır → durdur.
        screenOffReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, i: Intent?) {
                if (i?.action == Intent.ACTION_SCREEN_OFF) {
                    restoreSilencedRinger()
                    stopEverything(lingering = false)
                }
            }
        }
        try {
            registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        } catch (_: Exception) {}
    }

    private fun unregisterStopHooks() {
        try {
            volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
        } catch (_: Exception) {}
        volumeObserver = null
        try { screenOffReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        screenOffReceiver = null
    }

    private fun stopEverything(lingering: Boolean) {
        unregisterStopHooks()
        try { player?.let { if (it.isPlaying) it.stop() } } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
        if (lingering) postLingering()
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    /** Kullanıcı ezanı "Kapat" dedi → otomatik sessiz (Camide / Akıllı Sessiz)
     *  cihazı sessize aldıysa GERİ AL — kullanıcı burada ve sesini geri istiyor.
     *  DND/bildirim-politikası izni yoksa no-op. NOT: camide geofence HÂLÂ yakında
     *  ise app öne geldiğinde tekrar sessize alabilir → kalıcı çözüm "Camide
     *  Otomatik Sessiz"i ayarlardan kapatmaktır. */
    private fun restoreSilencedRinger() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= 23 && !nm.isNotificationPolicyAccessGranted) return
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        for (p in listOf("selaya_mosque_silent", "selaya_silent")) {
            val prefs = getSharedPreferences(p, Context.MODE_PRIVATE)
            if (prefs.getBoolean("muted", false)) {
                try {
                    am.ringerMode = prefs.getInt("prev_mode", AudioManager.RINGER_MODE_NORMAL)
                } catch (_: Exception) {}
                prefs.edit().putBoolean("muted", false).apply()
            }
        }
    }

    /** Ezan bittikten sonra perdede KALAN sessiz kayıt: "Öğle • 12:40 — ezan
     *  okundu". Kullanıcı kaydırarak siler; dokununca uygulama açılır. Servis
     *  bildirimi (FGS) kapanınca bu ayrı id'li bildirim geride kalır. */
    private fun postLingering() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        val pi = if (launch == null) null else
            PendingIntent.getActivity(this, 72, launch, f)
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SELAYA · Ezan")
            .setContentText("$label — ezan okundu")
            .setOngoing(false)
            .setAutoCancel(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .apply { if (pi != null) setContentIntent(pi) }
            .build()
        try { nm.notify(LINGER_ID, n) } catch (_: Exception) {}
    }

    /** Android 14+ shortService 3 dk sınırı güvenlik ağı: ezan normalde çok daha
     *  kısa ve bitince kendini kapatır; sınıra ulaşılırsa sistem bunu çağırır →
     *  temiz kapan (ANR/öldürülme olmasın). */
    override fun onTimeout(startId: Int) {
        stopEverything(lingering = false)
    }

    override fun onDestroy() {
        unregisterStopHooks()
        try { player?.release() } catch (_: Exception) {}
        player = null
        super.onDestroy()
    }

    private fun startForegroundNow(label: String) {
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SELAYA · Ezan")
            .setContentText("$label vakti — ezan okunuyor")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Kapat", stopPendingIntent())
            .setContentIntent(stopPendingIntent())
            .setDeleteIntent(stopPendingIntent())
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                // shortService: Android 14+ ARKA PLANDAKİ exact-alarm alıcısından
                // başlatılmasına İZİN VERİLEN tiplerden biri (mediaPlayback DEĞİL —
                // o yüzden ezan sessizce düşüyordu) VE Play tanıtım-videosu
                // gerektirmez (specialUse gibi değil). Ezan 3 dk'dan kısadır ve
                // bitince kendini kapatır; sınıra ulaşılırsa onTimeout temiz kapatır.
                startForeground(
                    NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE
                )
            } else {
                startForeground(NOTIF_ID, n)
            }
        } catch (_: Exception) {}
    }

    /** "Durdur" → bu servise [ACTION_STOP] gönderir (ses kesilir, bildirim kapanır). */
    private fun stopPendingIntent(): PendingIntent {
        val i = Intent(this, AdhanPlayerService::class.java).setAction(ACTION_STOP)
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, 71, i, f)
    }

    /** Dart'ın yazdığı seçili ezan res adı (yoksa varsayılan). */
    private fun selectedRes(): String =
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_RES, DEFAULT) ?: DEFAULT

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Ezan (çalar)", NotificationManager.IMPORTANCE_HIGH)
                .apply {
                    description = "Ezan okunurken görünen, 'Durdur'lu bildirim"
                    // Sesi MediaPlayer çalar → kanal SESSİZ (çift ses olmasın).
                    setSound(null, null)
                    enableVibration(true)
                    setBypassDnd(true)
                }
        )
    }

    companion object {
        const val NOTIF_ID = 3100
        // Temizlik aralıkları 3000-3699 (namaz bloğu) + 5000+ (özel günler) →
        // kalıcı "ezan okundu" kaydı bunların DIŞINDA olmalı ki reschedule /
        // "Kapat" / tam-ekran kapanışı onu silmesin.
        const val LINGER_ID = 4333
        const val CHANNEL = "selaya_adhan_player"
        const val PREFS = "selaya_widget"
        const val KEY_RES = "adhan_res"
        const val DEFAULT = "vakit_sabah"
        const val ACTION_STOP = "com.selaya.app.adhan.STOP"
        const val ACTION_VOLUME = "com.selaya.app.adhan.VOLUME"
        const val EXTRA_RES = "res"
        const val EXTRA_LABEL = "label"
        const val EXTRA_VOLUME = "volume"
    }
}
