# SELAYA — Kapsamlı Proje Dökümantasyonu

> İslami yardımcı uygulama (namaz vakitleri, ezan, Kur'an, Kıble, içerik akışı vb.)
> Bu dosya: hangi kod ne işe yarıyor, hangi servis/API kullanılıyor, panelden ne
> yapınca uygulamada ne oluyor — **gizli anahtar/şifre içermez.**
> Paket adı: `com.selaya.app` · Flutter + Dart · Son sürüm: bkz. `pubspec.yaml`.

---

## 1. Teknoloji Yığını

| Katman | Kullanılan |
|---|---|
| UI / Çatı | **Flutter** (Dart) |
| Durum yönetimi | **Riverpod 3** (Notifier/FutureProvider/StreamProvider) |
| Navigasyon | **go_router** (StatefulShellRoute.indexedStack — 6 sekmeli kabuk) |
| Ses | **just_audio** + **audio_service** (arka plan + bildirim kumandası) |
| Video | **video_player** (Akış + hikâye videoları) |
| Yerelleştirme | **easy_localization** (TR / EN, `assets/translations/*.json`) |
| Bildirim | **flutter_local_notifications** + **NATIVE Kotlin servisler** (ezan/sürekli) |
| Yerel depolama | **shared_preferences** (ayarlar, cache, son-okunan vb.) |
| Görsel | **cached_network_image** (`AppImage` sarmalayıcısı, CDN + asset fallback) |
| Konum | **geolocator** + **geocoding** + **permission_handler** |
| Saat dilimi | **timezone** (vakit hesabı için) |

Backend tamamen **Cloudflare** üzerinde (R2 + D1 + Worker + Pages admin panel) — bkz. Bölüm 8.

---

## 2. Proje Yapısı (klasörler)

```
lib/
├── main.dart                 # Bootstrap: binding, yerelleştirme, timezone, audio_service init, runApp
├── app.dart                  # MaterialApp + GLOBAL OVERLAY (mini player) + _AdhanWatcher (ezan tetikleyici)
├── core/                     # Paylaşılan altyapı (tüm özellikler kullanır)
│   ├── router/               # app_router.dart (rotalar + kabuk), routes.dart (rota sabitleri)
│   ├── theme/                # app_colors, app_typography, app_icons, app_spacing
│   ├── config/               # cdn.dart (SelayaCdn: cdn/api uç noktaları)
│   ├── models/               # content.dart (Surah, Verse, Wallpaper, Mosque, FeedItem, Story…)
│   ├── data/                 # content_providers, manifest_service, likes_service, notifications_sync
│   ├── services/             # location, overpass (cami), notification, ongoing_prayer
│   ├── widgets/              # selaya_scaffold, mini_player_chrome, global_mini_player_host,
│   │                         # app_image, rotating_image_background, content_detail_dialog…
│   ├── di/                   # providers.dart (sharedPreferences, audioHandler override noktaları)
│   └── share/                # share_helper (paylaşım kartları)
├── features/                 # ÖZELLİK MODÜLLERİ (her biri presentation/ + data/ + domain/)
│   ├── home/                 # Ana Sayfa
│   ├── prayer_times/         # Vakitler + geri sayım kartı + vakit şeridi + clock dial/gauge
│   ├── quran/                # Kur'an listesi, okuyucu, Yâsîn, Mushaf, now-playing, mini
│   ├── qibla/                # Kıble pusulası
│   ├── social_feed/          # Akış (video/görsel feed)
│   ├── stories/              # Hikâyeler (üstteki yuvarlak avatarlar)
│   ├── audio_stories/        # Sesli hikâyeler + AppAudioHandler (PAYLAŞILAN ses motoru)
│   ├── asma_ul_husna/        # Esmaül Hüsna (99 isim)
│   ├── hatim/                # Hatim takibi
│   ├── guides/               # Rehberler (abdest/gusül/teyemmüm/namaz hub)
│   ├── dhikr/                # Zikirmatik
│   ├── calendar/             # Dini günler/takvim
│   ├── notifications/        # Bildirim ayarları + ezan alarm ekranı + Ramazan modu
│   ├── settings/             # Ayarlar (tema, dil, hesaplama yöntemi…)
│   └── ai_assistant/         # SELAYA AI Asistan (dini soru-cevap)
android/app/src/main/kotlin/  # NATIVE: AdhanPlayerService, AdhanAlarmReceiver,
                              # PrayerOngoingService, TimeChangeReceiver, MainActivity
assets/                       # images, audio (ezan + zikir sesleri), translations, fonts, branding
```

**Kural:** `core/` hiçbir `features/`'a bağımlı olmaz; `features/` `core/`'u kullanır.

---

## 3. Navigasyon & Kabuk

- **`StatefulShellRoute.indexedStack`** (go_router) — 6 alt sekme, her biri kendi
  Navigator'ı + durumu korunur (IndexedStack):
  1. **Ana Sayfa** (home) 2. **Vakitler** (prayer_times) 3. **Kur'an** (quran)
  4. **Kıble** (qibla) 5. **Akış** (social_feed) 6. **Daha Fazla** (more)
- **Kur'an dalı** içinde nested rotalar: `reader/:surah` (okuyucu), `yasin`, `mushaf`.
  Bunlar "kabuk-altı" rotalardır → sure okurken/çalarken **alt menü görünür kalır**.
  Kural: kabuk-altı rotaya **`go`** ile gidilir (push ile değil); merkezi yardımcı
  `openRoute(context, route)` (mini_player_chrome.dart) doğru olanı seçer.
- **Global mini player** (`GlobalMiniPlayerOverlay`, `app.dart`): root Navigator'ın da
  ÜSTÜNDE, `MaterialApp.builder`'daki Stack'te **tek** mount edilir → ses çalarken
  kumanda TÜM rotalarda görünür. Tam-ekran çalar açıkken / belirli rotalarda gizlenir.
- **offstage sekme durur:** IndexedStack görünmeyen sekmeyi `Offstage` + `TickerMode(false)`
  ile söndürür → arka plandaki videolar/animasyonlar boşa frame üretmez (performans).

---

## 4. Durum Yönetimi (Riverpod)

- **Provider tipleri:** `FutureProvider` (CDN içerik), `StreamProvider` (saat),
  `NotifierProvider` (kontrolcüler: quranAudio, audioStory, hatim, settings…).
- **Önemli provider'lar:**
  - `clockProvider` — saniyede bir `DateTime` (geri sayım/saat; **sadece** küçük
    sayaç widget'larında izlenir, tüm ekran her saniye yeniden çizilmez).
  - `prayerViewProvider` / `dailyTimesProvider` — günün vakitleri + sonraki vakit.
  - `surahsProvider`, `versesProvider(n)` — Kur'an meta + ayetler.
  - `wallpapersProvider`, `feedProvider`, `storiesProvider`, `duasProvider`,
    `inspirationProvider`, `hadithsProvider` — CDN içerikleri (manifest'ten).
  - `audioHandlerProvider` — paylaşılan `AppAudioHandler` (tekil).
- **manifest cache-first:** `manifestProvider` önce prefs'teki kopyayı ANINDA döner
  (ayrı isolate'ta parse), ağdan arka planda tazeler, gövde değişmişse `invalidateSelf`.

---

## 5. Özellikler (modül modül)

### Ana Sayfa (`features/home`)
Canlı geri sayım kartı (NextPrayerCard), vakit şeridi (PrayerStrip), en yakın cami kartı,
hikâye rail'i, öne-çıkan araç ızgarası (FeatureIcon), günün ayeti/hadisi/duası kartları,
video vitrini (manuel kaydırmalı carousel), duvar kâğıdı + "bunu biliyor muydun".
> Arka plan: **video kaldırıldı**, yerine panel/CDN wallpaper'larından 3 görsel döner
> (`RotatingImageBackground`) — eski telefonlarda akıcılık için. Animasyonlar statik.

### Vakitler (`features/prayer_times`)
Günlük 6 vakit + geri sayım + ilerleme + İmsakiye + bildirim ayarları kısayolu.
- `NextPrayerCard` (home ile ortak hero kart), `PrayerStrip`, `PrayerClockDial`
  (saat kadranı), `PrayerTimelineGauge` (zaman çizgisi) — hepsi `clockProvider` (1sn).
- **Vakit hesabı:** yerel hesap (adhan algoritması) + çevrimiçi **AlAdhan API** ile
  senkron (resmî/otorite; 12 saatte bir + 14 gün kapsama tazelenir → veri bitmez).

### Kur'an (`features/quran`)
- **Liste** (quran_screen): sureler/cüzler/favoriler + arama + "son okunan" + "Dinlemeye Başla" + Mushaf Modu.
- **Okuyucu** (quran_reader_screen): ayet kartları (Arapça + okunuş + meal), "Sureyi Dinle",
  canlı ayet vurgusu + oto-kaydırma, sure geçişleri (alttan/üstten çekme + kartlar),
  transport çubuğu (ilerleme çizgisi). **`ListView.builder`** (tembel) — uzun surelerde
  takılma yapmaz.
- **Yâsîn**: aynı okuyucu (surah 36).
- **Mushaf**: 604 sayfa görseli (Medine Mushaf KFGQPC, CDN), sayfa çevirme + çift-dokunuş zoom + pinch.
- **Ses:** `QuranAudioController` → paylaşılan `AppAudioHandler`. Her ayet ayrı parça;
  sure bitince otomatik N+1'e geçer (kesintisiz okuma), Nâs'ta durur.

### Kıble (`features/qibla`)
Manyetometre/pusula ile Kâbe yönü (derece + yön) + kalibrasyon + Mekke'ye uzaklık.

### Akış (`features/social_feed`)
Dikey kaydırmalı video/görsel feed (`video_player`). Beğeni (API), paylaşım (dosya),
sessize alma. **Akış videosu sesli çalınca arka plandaki Kur'an'ı duraklatır** (çift ses olmaz).

### Hikâyeler (`features/stories`)
Üstteki yuvarlak avatarlar → tam-ekran hikâye oynatıcı (görsel + video slaytlar).
Video hikâye de Kur'an'ı duraklatır.

### Sesli Hikâyeler (`features/audio_stories`) — + PAYLAŞILAN SES MOTORU
- **`AppAudioHandler`** (audio_service): tek paylaşılan `just_audio` çalar; `mode`
  alanı `idle`/`story`/`quran`. Kur'an + sesli hikâye AYNI motoru kullanır (aynı anda
  yalnız biri). Bildirim kumandası + arka plan oynatma + konum/süre bildirimi.
- `AudioStoryController` + `QuranAudioController` — UI kontrolcüleri; `positionStream`
  **200ms throttle'lı** (eski 60fps yük gitti).

### Esmaül Hüsna / Dualar / Ayetler / Hadisler
İçerik listesi + adaptif popup (`showContentDetail` / `content_detail_dialog`) —
Arapça + okunuş + meal + paylaş; Esma'da Zikir kısayolu.

### Hatim (`features/hatim`)
Hatim takibi (günlük hedef, ilerleme, streak, geçmiş). Yerel kayıt + (girişliyse) bulut senkron.

### Rehberler (`features/guides`)
Taharet hub'ı: Abdest/Gusül/Teyemmüm/Mest/Sargı (Diyanet/Hanefi içerik, adım popup'ları,
görselli/görselsiz). `Guide`/`GuideStep` modeli.

### Zikirmatik (`features/dhikr`)
14 sahih zikir, sayaç, bead/tık sesi, görev oto-işaretleme.

### Takvim (`features/calendar`)
Dini günler (Hicri'den türetilen kandil/bayram/arefe), çok-günlü bayramlar.

### Ayarlar (`features/settings`)
Dil, tema (koyu/açık/oto), renk teması, AMOLED, yazı boyutu, konum, hesaplama yöntemi,
namaz sorusu, kadın özel modu, sürüm rozeti (gerçek PackageInfo).

### AI Asistan (`features/ai_assistant`)
"SELAYA AI" — dini soru-cevap. **DİKKAT: LLM/üretken model DEĞİL.** Hiçbir AI
sağlayıcısına (OpenAI/Anthropic/Gemini/Workers AI…) bağlanmaz; API çağrısı/anahtar
YOK. Tamamen **çevrimdışı, kurallı SSS eşleştirici**:
- Kaynak: **pakete gömülü `assets/data/ai_qa.json`** (`aiQaProvider`) — önceden
  yazılmış `AiQa` çiftleri (TR/EN soru + anahtar kelime + cevap + Kur'an/hadis/Diyanet
  kaynak referansları).
- `_bestMatch()`: yazılan metni yerel **anahtar-kelime puanlamasıyla** eşleştirir
  (Türkçe sadeleştirme + token skoru); eşik üstündeyse hazır cevabı, yoksa yönlendirici
  mesajı döner.
- 750ms "düşünme" gecikmesi + yazıyor noktaları → yalnızca **"AI hissi"** (kozmetik).
> Gerçek bir LLM istenirse: cevap üretimini bir Worker uç noktasına (api.selaya.app)
> taşıyıp anahtarı sunucuda tutmak gerekir — şu an böyle bir bağlantı YOK.

---

## 6. Ses Sistemi (özet akış)

```
Kullanıcı "Sureyi Dinle"
  → QuranAudioController.play(tracks)
    → AppAudioHandler.playPlaylist(tracks, mode:'quran')
      → just_audio: AudioSource.uri (api.selaya.app ses proxy'si)
      → audio_service: bildirim + kilit-ekranı kumandası
  → GlobalMiniPlayerOverlay: mini çalar belirir (tüm sekmelerde)
  → Okuyucu: çalan ayeti vurgular + üstüne kaydırır (ref.listen)
```
- **Bildirim ilerleme çubuğu:** handler `PlaybackState`'e `updatePosition` + gerçek
  `duration` (parça yüklenince `durationStream`'den) bildirir → çubuk hareket eder.
- **Tek motor kuralı:** hikâye çalınca Kur'an temizlenir (tek `onModeChanged` bağı).
- **Akış/hikâye videosu** sesli çalınca handler `pause()` → Kur'an susar (çift ses yok).

---

## 7. Bildirimler & Ezan (NATIVE Kotlin)

| Bileşen | Görev |
|---|---|
| **AdhanAlarmReceiver** | `AlarmManager` (exact, while-idle) ile vakit gelince tetiklenir; uygulama ÖLÜYKEN bile çalar. Prefs'te **kayan pencere** (~30 gün); BOOT/saat değişiminde yeniden kurar. |
| **AdhanPlayerService** | FGS (specialUse) + `MediaPlayer` (USAGE_ALARM) → ezanı çalar; **"Kapat"** anında keser; ezan bitince "ezan okundu" kalıcı kaydı bırakır. |
| **PrayerOngoingService** | FGS — "Sürekli Bildirim": gövdede **Chronometer** ("İmsak vaktine kalan : S:DD:SS") + genişletilmişte 6-vakit ızgarası (RemoteViews). |
| **TimeChangeReceiver** | Saat/saat-dilimi/dil değişince alarmları + sürekli bildirimi tazeler. |
| **MainActivity** | MethodChannel köprüleri (`selaya/widget`, `nida/ongoing`); ezan payload'ı (cold-start tam-ekran alarm). |
| **AdhanAlarmScreen** (Flutter) | Tam-ekran alarm ekranı (GÖRSEL); sesi native servis çalar; "Kapat" → native `stopAdhan`. |

- **Kanallar:** ezan (alarm akışı), sessiz görsel tetik, sürekli bildirim, özel günler.
- **Vakit hesabı:** yerel + AlAdhan. **Özel bildirimler:** kandil/Cuma/Ramazan (sahur/iftar),
  Ramazan Modu (auto/on/off — Hicri ay 9).
- **Ezan sesleri:** yalnız lisanslı (Wikimedia, atıflı; `NOTICE_AUDIO.md`).

---

## 8. Backend / Panel (Cloudflare)

**Tüm backend Cloudflare'de; uygulama yalnız HTTPS ile okur.** Üç alan adı:

| Alan | Ne |
|---|---|
| **cdn.selaya.app** | **R2** (nesne deposu) — görseller (wallpaper), videolar (feed), Mushaf sayfaları, rehber görselleri, ses dosyaları. Anahtar = asset yolu (`images/wallpapers/x.jpg`). |
| **api.selaya.app** | **İçerik API Worker** — `/v1/manifest` (tüm içerik listesi, edge-cache TTL ~120sn), `/v1/likes` (beğeni sayıları, ~30sn), Kur'an ses proxy'si. Auth: `/v1/auth/*` (JWT). |
| **panel.selaya.app** | **Admin panel** (Pages) — içerik yükleme/yönetim arayüzü. |

- **D1** (SQL veritabanı): içerik meta verisi (wallpapers/feed/stories/inspiration/hadith/dua…),
  **users** + **user_data** (üyelik + bulut senkron).
- **Manifest cache-first:** uygulama prefs'teki kopyayı anında gösterir, arka planda
  tazeler. Panelden yazınca Worker **edge cache'i temizler (bustManifest)** → uygulama
  bir sonraki tazelemede/resume'da görür.
- **Üyelik/senkron (opsiyonel, misafir-öncelikli):** D1 users/user_data + Worker JWT.
  Faz 1 hazır. Hassas veri (ör. kadın özel günleri) **senkronlanmaz**.

> **Gizli bilgiler bu dosyada YOK:** Cloudflare hesap/zone id'leri, R2/D1 erişim
> anahtarları, Worker secret'ları, JWT imza anahtarı, wrangler token'ları — bunlar
> yalnız panel/Cloudflare yönetiminde, koda gömülü değil.

---

## 9. Kullanılan Dış API'ler & Servisler

| Servis | Kullanım |
|---|---|
| **SELAYA İçerik API** (api.selaya.app) | Manifest (içerik), beğeniler, Kur'an ses proxy'si, auth |
| **AlAdhan API** | Çevrimiçi resmî namaz vakitleri (yerel hesabı doğrular/günceller) |
| **Overpass API** (OpenStreetMap) | En yakın cami (GPS + sorgu) |
| **Google Maps** | Camiye yol tarifi (harici link) |
| **Açık Kuran API** (api.acikkuran.com) | **Tek seferlik** Türkçe okunuş üretimi (runtime DEĞİL — JSON'lar pakette) |
| **Wikimedia Commons** | Ezan ses kaynakları (lisanslı, atıflı) |
| Cihaz sensörleri | Manyetometre (Kıble), GPS (konum) |

---

## 10. Panelden Ne Yapınca Uygulamada Ne Olur

| Panelde yaptığın | Olan |
|---|---|
| **Duvar kâğıdı yükle** (görsel) | R2'ye görsel + **otomatik ≤560px WebP önizleme** + D1 satırı → manifest temizlenir → uygulamada **Duvar Kâğıtları** ızgarasında + **ana ekran arka plan dönüşümünde** (ilk 3 ücretsiz) belirir |
| **Video yükle** | R2 + D1 → feed manifest → **Akış**'ta + ana ekran video vitrininde belirir (thumbnail videonun karesinden) |
| **Ayet/Hadis/Dua/İlham ekle** | D1 → manifest → **Ayetler/Hadisler/Dualar** + **Akış** + ana ekran "Günün …" kartlarında belirir |
| **Hikâye ekle** | D1 + R2 → **üstteki hikâye rail'inde** belirir |
| **Özel bildirim gönder** | `/v1/...` → uygulama açılışta/resume'da çeker, görülmeyenleri gösterir |
| **İçerik sil** | D1'den kalkar → manifest temizlenir → uygulamadan kaybolur |
| **Premium işaretle** | `premium:true` → ücretsiz akışlarda (ör. ana ekran arka planı) atlanır |

> İçerik **anında** değil, edge-cache TTL (~2 dk) + uygulamanın bir sonraki tazelemesi/
> resume'u ile yansır. Panel yazımı edge cache'i temizlediği için genelde hızlıdır.

---

## 11. Build & Dağıtım

```bash
flutter analyze                          # statik kontrol (SIFIR bulgu hedefi)
flutter test                             # birim/widget testleri
flutter build apk --release --split-per-abi   # arm64/v7a/x86_64 ayrı APK'lar
```
- Telefon (Galaxy A55) **arm64** → `app-arm64-v8a-release.apk`.
- `--split-per-abi` ŞART (versionCode doğru olur; tek-arch build düşük kod üretip
  "downgrade" hatası verir).
- Dağıtım: `G:\Drive'ım\SELAYA APK\selaya-release-arm64-vX.Y.Z-TARIH.apk`.
- Sürüm: `pubspec.yaml` → `version: X.Y.Z+BUILD`.
- Kablosuz adb: port değişken → `adb mdns services` → `adb connect ip:port`.

---

## 12. Önemli Kurallar / Tuzaklar (geliştirici notları)

- **PowerShell ile `.dart` düzenleme YASAK** (UTF-8 mojibake bozar) — Edit aracı veya `bash sed` kullan.
- **Kabuk-altı rotaya `go`**, detay rotaya `push`; `go_router` push `uri`'yi güncellemez.
- **Sık görünen/kalıcı widget'a SONSUZ `repeat` animasyon koyma** — ticker sızıp CPU yakar
  (ana ekran/More donmalarının köküydü; hepsi statik yapıldı).
- **Global app-wrapper widget saat/stream'i `watch` etmesin** — `ref.listen` kullan
  (yoksa her saniye tüm ağaç kirlenir).
- **Uzun listelerde `ListView.builder`** (asla `ListView(children:[...])`/`Column`).
- **Ölçüm:** `dumpsys gfxinfo` Flutter'da 0 verir; `top`/`top -H` + `flutter run --debug` +
  `debugPrintRebuildDirtyWidgets` ile teşhis.
- **Native ezan/alarm** force-stop sonrası "stopped state"te tetiklenmez (gerçek cihazda
  kaydırarak-kapatıp test et).

---

*Bu dosya proje köküne (`SELAYA_DOKUMANTASYON.md`) konuldu. Kod değiştikçe güncellenmeli;
gizli anahtar/şifre EKLENMEMELİ.*
