# SELAYA — Google Play Yayın Dosyası

Paket: `com.selaya.app` · Gizlilik politikası: `https://api.selaya.app/privacy` (Worker servis ediyor — kaynak store/privacy-policy.html → cloudflare/src/privacy.js; `wrangler deploy` ile yayına alınır)

---

## 1. Mağaza listeleme metinleri

### Türkçe
- **Uygulama adı (≤30):** `SELAYA: Namaz Vakti & Kur'an`
- **Kısa açıklama (≤80):** `Namaz vakitleri, Kur'an, kıble, zikir, ezan alarmı ve İslami topluluk.`
- **Tam açıklama (≤4000):**
```
SELAYA, günlük ibadet hayatını kolaylaştıran kapsamlı bir İslami yaşam uygulamasıdır.

🕌 NAMAZ VAKİTLERİ & EZAN
• Konumuna göre resmî, güncel namaz vakitleri (Diyanet ve 18 hesaplama yöntemi)
• Ezan sesli bildirimi ve tam ekran alarm
• Sonraki vakte kalan süre, imsakiye, kerahat vakitleri

📖 KUR'AN-I KERİM
• Mushaf okuyucu, sesli dinleme, ayet meali ve arama
• Yâsîn, kısa sureler, Kur'an okuma planı, hatim takibi

🧭 KIBLE & ZİKİR
• Hassas kıble pusulası
• Dijital zikirmatik (tesbihat) ve günlük zikir hedefleri

🤲 TOPLULUK
• Dua Duvarı: dualarını paylaş, "âmin" de
• Topluluk Hatmi: birlikte cüz al, oku, hatmi tamamla
• Bilgi Yarışması: haftalık yarışma ve liderlik tablosu

🌙 DAHA FAZLASI
• İslami takvim, kandiller, Ramazan modu, oruç takibi
• Hac & Umre rehberi, ilmihal, dualar, Esmâ-ül Hüsna
• İsim kütüphanesi, tebrik kartları, duvar kâğıtları, widget'lar
• Üyelikle cihazlar arası senkron

Reklamsız. Gizliliğine saygılı. Allah kabul etsin. 🤍
```

### English
- **Title (≤30):** `SELAYA: Prayer Times & Quran`
- **Short (≤80):** `Prayer times, Quran, qibla, dhikr, adhan alarm and an Islamic community.`
- **Full (≤4000):**
```
SELAYA is a complete Islamic lifestyle app for your daily worship.

🕌 PRAYER TIMES & ADHAN
• Accurate, up-to-date prayer times by location (Diyanet + 18 methods)
• Adhan sound notification and full-screen alarm
• Countdown to next prayer, imsakiyah, makruh times

📖 THE HOLY QURAN
• Mushaf reader, audio recitation, translation and search
• Yasin, short surahs, reading plan, khatm tracking

🧭 QIBLA & DHIKR
• Precise qibla compass
• Digital tasbih and daily dhikr goals

🤲 COMMUNITY
• Dua Wall: share your prayers, say "Amin"
• Community Khatm: claim and read juz together
• Knowledge Quiz: weekly challenge and leaderboard

🌙 AND MORE
• Islamic calendar, holy nights, Ramadan mode, fasting tracker
• Hajj & Umrah guide, catechism, duas, 99 Names of Allah
• Name library, greeting cards, wallpapers, widgets
• Cross-device sync with an account

Ad-free. Privacy-respecting. 🤍
```

---

## 2. Data Safety formu (Play Console → App content → Data safety)

**Toplanan veri tipleri (Collected):**
| Tür | Toplanan? | Paylaşılan? | Zorunlu? | Amaç |
|---|---|---|---|---|
| İsim | Evet | Hayır | Opsiyonel (üyelik) | Hesap |
| E-posta | Evet | Hayır | Opsiyonel (üyelik) | Hesap, parola sıfırlama |
| Yaklaşık + Kesin konum | Evet | Evet (AlAdhan/OSM — işlev için) | Opsiyonel | Namaz vakti, kıble, cami |
| Kullanıcı içeriği (dua) | Evet | Hayır (uygulama içinde herkese açık) | Opsiyonel | Topluluk özelliği |
| Uygulama etkinliği (skor/takip) | Evet | Hayır | Opsiyonel | Liderlik, senkron |
| Cihaz tanımlayıcı | Evet | Hayır | Opsiyonel | 2-cihaz sınırı |

**Genel beyanlar:**
- ✅ Veri aktarımı **şifreli (HTTPS)**.
- ✅ Kullanıcı **veri silmeyi talep edebilir** (uygulama içi hesap silme + e-posta).
- ✅ Veri **satılmaz**, reklam/üçüncü-taraf-pazarlama için kullanılmaz.
- ⚠️ Konum: "App functionality" amacıyla; "shared with third parties" = **Evet** (AlAdhan + OpenStreetMap'e koordinat gider — bunu işaretle).
- Hassas kadın-sağlığı verisi: **toplanmaz** (yalnız cihazda).

---

## 3. Hassas izin deklarasyonları (Play Console → App content)

| İzin | Beyan / gerekçe |
|---|---|
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | **Alarm & Reminders** kategorisi: namaz vakti tam zamanında ezan/alarm. |
| `USE_FULL_SCREEN_INTENT` | Tam ekran namaz alarmı (kilit ekranı üstünde). Deklarasyon gerekir. |
| `FOREGROUND_SERVICE` + `..._SPECIAL_USE` | "Sonraki vakte kalan süre" kalıcı bildirimi (canlı sayaç). Manifest'te `special_use` türü + Play'de amaç açıklaması. |
| `ACCESS_FINE_LOCATION` | Namaz vakti / kıble / yakın cami (yalnız foreground). |
| `SYSTEM_ALERT_WINDOW` | Alarmın arka plandan/kilit ekranından güvenilir açılması. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Namaz alarmlarının Doze'da kaçmaması. |
| `READ_MEDIA_IMAGES` | Duvar kâğıdı seçimi/paylaşım. |
| `POST_NOTIFICATIONS` | Vakit/ezan bildirimleri. |

> Not: `ACCESS_BACKGROUND_LOCATION` **kaldırıldı** (cami-sessiz artık foreground-only) → o zorlu inceleme/video gerekmez. ✅

---

## 4. İçerik derecelendirme (IARC)
- Tür: Referans / Yaşam tarzı (din). Şiddet/cinsellik yok.
- **Kullanıcı içeriği var** (Dua Duvarı, yarışma rumuzları): formda "kullanıcılar içerik paylaşabiliyor" + **moderasyon** olduğunu belirt (küfür filtresi + uygulama içi şikayet/engelle + panel moderasyonu + yasaklama).
- Beklenen: 3+ / Everyone.

## 5. Süreç hatırlatmaları
1. **AAB yükle:** `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (release upload key'iyle imzalı ✅).
2. **Yeni kişisel geliştirici hesabıysa:** üretimden önce **20 test kullanıcısı + 14 gün kapalı test** zorunlu — bunu erken başlat.
3. **App signing:** Play "Play App Signing"i öner; upload key'i (`selaya-upload-keystore.jks`) güvende sakla.
4. Gizlilik politikası URL'ini Console'a gir (`https://api.selaya.app/privacy` — `wrangler deploy` sonrası canlı).
5. Hedef kitle & içerik, reklam beyanı (= reklam yok).

## 6. Ekran görüntüleri (gerekli: telefon için 2–8 adet, min 320px)
Önerilen 6 kare: Ana ekran (vakitler) · Kur'an okuyucu · Kıble · Dua Duvarı · Bilgi Yarışması · Tesbihat/Zikirmatik. (İstersen emülatörden çekip hazırlayabilirim.)
Ayrıca: 512×512 ikon (var) + 1024×500 feature graphic (üretilebilir).
