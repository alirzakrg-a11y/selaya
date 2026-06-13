package com.selaya.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
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
            // Kullanıcı "Kapat" dedi → iz bırakmadan kapat.
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
        // Tam Ekran Alarm AÇIK → Dart, vakit slotunu (0..5) geçirir; bildirim
        // fullScreenIntent ile MainActivity'yi uyandırır (kilitli/ölü dahil) ve
        // mevcut pending_adhan köprüsü alarm ekranını açar. KAPALI → -1.
        val slot = intent?.getIntExtra(EXTRA_SLOT, -1) ?: -1
        startForegroundNow(label, slot)
        play(intent?.getStringExtra(EXTRA_RES))
        return START_NOT_STICKY
    }

    /** Seçili ezanı res/raw'dan çalar; bittiğinde kendini kapatır. */
    private fun play(resName: String?) {
        val name = if (!resName.isNullOrEmpty()) resName else selectedRes()
        var resId = resources.getIdentifier(name, "raw", packageName)
        if (resId == 0) resId = resources.getIdentifier(DEFAULT, "raw", packageName)
        if (resId == 0) { stopEverything(lingering = false); return }
        try {
            player?.release()
            // MediaPlayer ELLE kurulur (create() değil): ses öznitelikleri
            // prepare'dan ÖNCE set edilmeli (sonradan set bazı cihazlarda yok
            // sayılıp ezanı MEDYA kanalına düşürüyordu) + PARTIAL wake-lock —
            // ekran kapalı/doze'da uzun ezan ORTADAN KESİLMESİN.
            val afd = resources.openRawResourceFd(resId)
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setWakeMode(this@AdhanPlayerService, PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                isLooping = false
                // Ezan KENDİLİĞİNDEN bitti → kalıcı "ezan okundu" kaydı bırak
                // (kullanıcı bildirimi kaçırmasın; perdede silene dek durur).
                setOnCompletionListener { stopEverything(lingering = true) }
                setOnErrorListener { _, _, _ -> stopEverything(lingering = false); true }
                prepare()
                start()
            }
            afd.close()
        } catch (_: Exception) {
            stopEverything(lingering = false)
        }
    }

    private fun stopEverything(lingering: Boolean) {
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

    override fun onDestroy() {
        try { player?.release() } catch (_: Exception) {}
        player = null
        super.onDestroy()
    }

    private fun startForegroundNow(label: String, slot: Int) {
        // "Tek bildirim, tek Kapat": tam-ekran tetik de ARTIK bu bildirimde —
        // eskiden ayrıca sessiz bir flutter_local_notifications bildirimi
        // kuruluyordu; onun Dart "Durdur" aksiyonu uygulama ölüyken native
        // MediaPlayer'ı DURDURAMIYORDU (bg isolate'te kanal yok) → "Kapat ses
        // kesmiyor" şikâyetinin kökü. Kapat burada native ACTION_STOP'tur ve
        // uygulama ölü olsa da keser.
        val b = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SELAYA · Ezan")
            .setContentText("$label vakti — ezan okunuyor")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Kapat", stopPendingIntent())
            .setDeleteIntent(stopPendingIntent())
        if (slot >= 0) {
            // Tam Ekran AÇIK: bildirim ekranı uyandırıp alarm sayfasını açar
            // (soğuk başlatma dahil — MainActivity.handleAdhanIntent payload'ı
            // pending_adhan'a yazar, Dart resume'da tüketir). Dokunmak da
            // alarmı açar; sesi yalnız Kapat/Durdur keser.
            val pi = fullScreenPendingIntent(slot)
            b.setFullScreenIntent(pi, true)
            b.setContentIntent(pi)
        } else {
            // Tam Ekran KAPALI: bildirim ezanın kendisidir — dokunmak da
            // alarm saatindeki gibi kapatır (eski davranış aynen).
            b.setContentIntent(stopPendingIntent())
        }
        val n = b.build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIF_ID, n)
            }
        } catch (_: Exception) {}
    }

    /** Tam-ekran tetik: MainActivity'yi `adhan:<slot>` payload'ıyla açar —
     *  mevcut pending_adhan köprüsü (soğuk/sıcak) alarm ekranını gösterir. */
    private fun fullScreenPendingIntent(slot: Int): PendingIntent {
        val i = Intent(this, MainActivity::class.java)
            .putExtra("payload", "adhan:$slot")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 73, i, f)
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
        // 4100: namaz bloğunun (3000-3699) ve özel günlerin (5000+) DIŞINDA —
        // Dart'ın blok-süpürme iptalleri (cancelActivePrayerSounds / bg Durdur)
        // bu FGS bildirimiyle itişmesin. (Eskiden 3100'dü: bloğun içindeydi;
        // FGS koruması fiilen kurtarıyordu ama tasarım kirliydi.)
        const val NOTIF_ID = 4100
        // Kalıcı "ezan okundu" kaydı da aynı şekilde blokların DIŞINDA ki
        // reschedule / "Kapat" / tam-ekran kapanışı onu silmesin.
        const val LINGER_ID = 4333
        const val CHANNEL = "selaya_adhan_player"
        const val PREFS = "selaya_widget"
        const val KEY_RES = "adhan_res"
        const val DEFAULT = "adhan_mecca_full"
        const val ACTION_STOP = "com.selaya.app.adhan.STOP"
        const val ACTION_VOLUME = "com.selaya.app.adhan.VOLUME"
        const val EXTRA_RES = "res"
        const val EXTRA_LABEL = "label"
        const val EXTRA_VOLUME = "volume"
        const val EXTRA_SLOT = "slot" // 0..5 = tam-ekran alarm vakti; -1 = kapalı
    }
}
