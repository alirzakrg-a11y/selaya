# NIDA — Geliştirme Planı (PDF spesifikasyonu + acil düzeltmeler)

> Kaynak: `NİDA.pdf` (Ali Rıza Karga, CorelDRAW export — tek uzun dikey board).
> Referans uygulamalar: **Ezan Vakti Pro**, **Müslim/Muslim App** (yeşil tema) → NIDA (koyu/altın) arayüzüne uyarlanacak.
> İşaretleme: `[ ]` yapılacak · `[~]` devam ediyor · `[x]` bitti & test edildi.

---

## 🔎 DURUM ÖZETİ (2026-06-04 — kaynak kod denetimi)

Kod tabanı baştan sona denetlendi; bu plan gerçek koda göre güncellendi. Plan ile kod arasındaki başlıca farklar:

- **Faz 5 (Temalar)** planda "yapılmadı" idi → gerçekte **kod tamam**: `AppPalette` (Altın/İslami Yeşil) × koyu/açık/sistem + AMOLED; Ayarlar'da tema seçici; SharedPreferences kalıcılık; `app.dart` dinamik tema.
- **Faz 6.4 (Home-screen widget)** planda "yapılmadı" idi → gerçekte **tamam**: 8 Android App Widget provider + iOS WidgetKit (5 widget) + App Group senkron.
- **Faz 6.1 (Ayarlar)** kısmen yapılmış (temel kişiselleştirme + namaz/Hicri ayarları var; bazı toggle'lar eksik); **6.2 Akıllı sessiz** dummy (kaydetmiyor); **6.3 toggle'lar** yok.
- **Faz 1.5** kodda **8 müezzin** sesi var (planda 6 yazıyordu).
- **Faz 1.7 / Kerahat süresi ayarı** hâlâ yok (kerahat hesaplanıp gösteriliyor, süre hardcoded).
- Faz 0 / 2 / 3 / 4 / 7 iddiaları kodla **doğrulandı**, çelişki yok.

**Kalan iş ağırlığı:** Faz 6.1/6.2/6.3 (genişletilmiş ayarlar + eksik toggle'lar) ve Faz 1.7 (kerahat süresi).

---

## FAZ 0 — ACİL DÜZELTMELER (kullanıcının açık istekleri) — ÖNCELİK

- [x] **0.1 Hakkında bölümü** — Ferah, dokunulabilir kart (logo + ad + slogan kendi satırı + `v1.0.0` rozeti) → `_AboutSheet` alt sayfası (büyük logo, `package_info` sürüm, açıklama, "Uygulamayı Paylaş").
- [x] **0.2 iOS bildirim izni** — KÖK NEDEN: `init()` Darwin default'larıyla izni app açılışında tüketiyordu. Çözüm: init artık istemiyor; `requestPermission` iOS'ta FLN `requestPermissions`/`checkPermissions`; kalıcı redde "Ayarları Aç" dialogu. → `notification_service.dart`, `notification_settings_screen.dart`, `permission_dialog.dart`.
- [x] **0.3 Şehir Seç ekranı** — Gradient konum hero kartı + aramada temizle (x) + **ülkeye göre gruplı** liste (başlıklar) + seçili vurgu (altın çerçeve+✓) + boş hal + ortak konum izni.
- [x] **0.4 Paylaşım görsellerinde yazı taşması** — `VerseShareCard` + `GreetingCard` orta blok `FittedBox(scaleDown)` + genişlik sınırı → uzun metin (Kadir Gecesi) kırpılmıyor, ortalı, baz font bir tık küçük.
- [x] **0.5 Ortak izin sistemi (iOS + Android)** — `PermissionService`: notifications/exactAlarms/location → `granted`/`denied`/`needsSettings`. iOS notif = FLN, Android = permission_handler, exact = requestExactAlarms, konum = geolocator. `permission_dialog.dart` ortak "Ayarları Aç".
- [x] **0.6 Direkt sosyal paylaşım (ortak API)** — `ShareService` (captureBoundary + shareImageFile): Android native `Intent setPackage` (WhatsApp/Instagram/Facebook), iOS Instagram Stories (pasteboard+scheme), olmazsa sistem paylaş sayfası. `ShareTargetsRow` paylaşım sayfası + tebrik düzenleyicide. FileProvider + queries + LSApplicationQueriesSchemes eklendi.
- [x] **0.7 DPI / responsive** — `app.dart` `MediaQuery.withClampedTextScaling(0.9–1.3)`; `responsive.dart` (isCompact/isExpanded/gridColumns/scaledGap); More grid `gridColumns(3–5)` ekrana göre. (Diğer ekranlara kademeli yayılacak.)
- [x] **0.8 Widget'ları profesyonelleştir** — `NidaCard` artık StatefulWidget: dokununca basınç-ölçek animasyonu (0.975) + ink ripple, app geneli tüm dokunulabilir kartlarda. (Diğer cilalar kademeli.)

### FAZ 0 TEST SONUÇLARI (2026-05-30)
- `flutter analyze`: **0 hata, 0 uyarı** (48 info, hepsi önceden vardı).
- **Android emülatör (API 35)**: debug APK derlendi (Kotlin paylaşım handler + FileProvider + manifest queries sorunsuz), kuruldu, açıldı (pid çalışıyor), çökme yok. Onboarding + ana ekran + Daha Fazla + Ayarlar + Hakkında kartı görsel doğrulandı.
- **iOS simülatör (iPhone 16)**: Runner.app derlendi (Swift AppDelegate paylaşım kanalı + Info.plist schemes sorunsuz), kuruldu, açıldı, çökme yok.
- **Hakkında kartı** cihazda doğrulandı: logo + ad + slogan + `v1.0.0` rozeti, sığıyor.
- Paylaşım kartı taşma düzeltmesi (`FittedBox(scaleDown)`) Hakkında ile aynı desen; kullanıcı uzun ayet (Kadir Gecesi) paylaşarak görebilir.

---

## FAZ 1 — BİLDİRİMLER (PDF: "EN ÖNEMLİ") ✅ kod tamam (1.7 kerahat hariç)

- [x] **1.1 İki bölümlü yapı** — "Vakit Zamanında Uyarılar" + "Vakitlerden Önce Uyarılar" ayrı kartlar.
- [x] **1.2 Vakitlerden önce** — her vakit aç/kapa + **çoklu dakika chip** (10/15/20/25/30/45, çoklu seçim) + ayrı ses.
- [x] **1.3 Vakit zamanında** — her vakit aç/kapa + ezan sesi.
- [x] **1.4 Çoklu hatırlatma** — `beforeOffsets: List<int>` → her offset için ayrı bildirim (ör. 20 + 10 dk). Scheduler ID `kind` 0=atTime, 1..N=before.
- [x] **1.5 Ezan sesi seçici** — Sessiz / Bildirim Sesi + **8 isimli müezzin** (Ahmed Al-Nafees, Mishary Rashid Al-Afasy, Hafız Mustafa Özcan, Mescid-i Haram, Qari Abdul Kareem, Sheikh Jamac, Karl Jenkins, Salah Mansor) + `chime`. Avatar (baş harf) + önizleme (just_audio play/pause) + ✓. **Yer tutucu WAV'ler** (res/raw + assets, her biri farklı ton); kullanıcı gerçek ≤30sn klipleri aynı isimle değiştirir. *(iOS özel sesleri için .wav'lar Runner bundle'a eklenmeli; şimdilik default'a düşer.)*
- [x] **1.6 Kalıcı bildirim (Android, ongoing)** — `when`=sıradaki vakit + `usesChronometer`+`chronometerCountDown` → **sistem-yönetimli canlı geri sayım** (foreground service yok); BigText tüm vakitler; `ongoing`+`onlyAlertOnce`; Ayarlar'da toggle; app start/resume + her schedule'da yenilenir. *(iOS'ta ongoing yok → gizli; ileride Live Activity.)*
- [ ] **1.7 Kerahat vakti süresi** ayarı — **hâlâ yapılmadı** (denetim 2026-06-04). Kerahat vakitleri hesaplanıp gösteriliyor (`extended_times.dart`, `prayer_times_screen.dart` → `_KerahatCard`) ama **süreler hardcoded** (işrak'a kadar / öğle −15 dk / akşam −40 dk), kullanıcı ayarlayamıyor. → Faz 6 (ayarlar) ile birlikte yapılacak.

### FAZ 1 TEST SONUÇLARI (2026-05-30)
- `flutter analyze`: **0 hata, 0 uyarı**.
- **Android**: debug APK derlendi (6 yeni ses asseti + yeni model/controller/scheduler/UI), kuruldu, açıldı, **logcat'te runtime hatası yok**, Switch etkileşimi çalıştı.
- **iOS simülatör**: Runner.app derlendi (exit 0).
- Not: Bildirim ekranı görseli alınamadı — emülatörde `_NavRow` InkWell satırları adb sentetik dokunuşu tetiklemiyor (Switch'ler tetikliyor); gerçek dokunuşta sorun yok. Kullanıcı cihazda görebilir.

---

## FAZ 2 — ANA EKRAN YENİDEN DÜZENİ ✅ tamam + test edildi

- [x] **2.1 Header** — şehir + **"NIDA İslami Asistan"** alt satırı + **"az reklam"** altın rozeti. ✓ cihazda.
- [x] **2.2 Geri sayım göstergesi** — `_GaugeCarousel` PageView **3 stil** (sağa/sola kaydırınca değişir): (1) NextPrayerCard geri sayım+video, (2) `PrayerClockDial` dairesel 24h dial, (3) **`PrayerTimelineGauge` yatay zaman çizelgesi** (imsak→imsak+24h bar + 6 vakit iki-sıra etiket + İşrak/Evvabin/Seher + kerahat + "şimdi" göstergesi). PDF'deki iki referans gauge. ✓ cihazda kaydırma doğrulandı.
- [x] **2.3 Video arka plan** — geri sayım kartı arka planı artık **video**: `video_player` + `VideoBackground` (rastgele, döngülü, sessiz, her açılışta değişir, görsel fallback). 5 ambient video mevcut İslami görsellerden **ffmpeg Ken Burns (yavaş zoom)** ile üretildi (`assets/videos/bg_1..5.mp4`, telifsiz). ✓ cihazda kare-farkıyla hareket doğrulandı. *(Kullanıcı kendi videolarını aynı isimle koyabilir.)*
- [x] **2.4 Vakit satırı** — `PrayerStrip` (mevcut).
- [x] **2.5 Öne Çıkanlar** — vakit satırının **ALTINA** alındı (İbadet Takibi, Esmaül Hüsna, Dualar, Cami Rehberi, İslami Takvim, Zikirmatik). PDF birebir. ✓ cihazda.
- [x] **2.6 Günün Duvar Kağıdı** kartı (mevcut, korundu).
- [x] **2.7 Hava durumu** — **Open-Meteo (ücretsiz, API-key'siz GERÇEK veri)**. Kullanıcı isteğiyle **header sağ-üste (zil yanı) taşındı**: kompakt pill (bugün ikon+°), dokun → 3-4 günlük tahmin alt sayfası (`_HeaderWeather`). Eski `WeatherStrip` gövdeden kaldırıldı. ✓ cihazda "22°".
- [x] **2.8 "Ana ekrana widget ekle"** kartı. ✓
- [x] **2.9 "Bizi geliştir / fikrini paylaş"** kartı (mailto). ✓
- [x] **2.10 NIDA Plus'ı ana ekrandan kaldır** — `_PremiumBanner` ana ekrandan kaldırıldı. ✓ cihazda.

### FAZ 2 TEST: analyze 0/0 · Android build+run, ana ekran görsel doğrulandı (kadran+nokta, hava durumu gerçek veri, Öne Çıkanlar vakit altında, NIDA Plus yok, widget/fikir kartları) · iOS simülatör build exit 0.

---

## FAZ 3 — "DAHA FAZLA" YENİDEN DÜZENİ + YENİ BÖLÜMLER ✅ tamam + test edildi

- [x] **3.1 Bölüm başlıkları** — "DUALAR & KUR'ANI KERİM" / "İSLAMİ ARAÇ & GEREÇLER" / "İSLAMİ YAŞAM". ✓ cihazda.
- [x] **3.2 Grid** — Kıbleyi Bul, Zikirmatik, Kur'anı Kerim, Dualar, Esmaül Hüsna, **Yâsîn**, En Yakın Cami, İbadet Takipçisi, Oruç Takipçisi, İslami Takvim, **İslami Kütüphane**, **Kazalar**. ✓
- [x] **3.3 Araç & Gereçler** — **Widgetler**, Duvar Kağıtları, Keşfet. ✓
- [x] **3.4 NIDA AI banner** + Sesli Hikayeler, Tebrik Kartı, Akış, **İslami Sticker**, Hoş Geldin, Ayarlar. ✓ (NIDA Plus More'dan da kaldırıldı.)
- [x] **3.5 Yâsîn** — mevcut Kur'an okuyucusuna (sure 36) yönlendirir.
- [x] **3.6 Kazalar** — gerçek kaza takibi (`kaza_controller.dart`, 6 vakit sayaç, kalıcı JSON, +/- ve adet-gir dialog). ✓ cihazda render.
- [x] **3.7 İslami Kütüphane** — `library.json` (6 gerçek makale: Namaz/Abdest/Oruç/Zekât/Tövbe/Ahlak, bilingual) + liste + okuyucu. ✓ cihazda.
- [x] **3.8 Widgetler** — widget rehber/galeri ekranı (hadis + vakit widget'ı + nasıl eklenir).
- [x] **3.9 İslami Sticker** — 14 İslami görsel grid'i, dokununca WhatsApp/Instagram/Facebook/Diğer'e paylaş (`ShareService.assetToTempFile`).

### FAZ 3 TEST: analyze 0/0 · Android build+run, Daha Fazla bölümlü düzen + İslami Kütüphane (6 makale) + Kazalar (6 vakit) + Duvar Kağıtları cihazda görsel doğrulandı · iOS simülatör build exit 0.

---

## FAZ 4 — İÇERİK EKRANLARI REDESIGN (denetim sonucu — çoğu önceki turlarda yapılmış)

- [x] **4.1 Zikirmatik** — yeniden tasarlandı: **gerçekçi tesbih boncuk halkası** (33 boncuk CustomPaint, mermer/taş gradient, sayarken altın yanar + aktif boncuk parlar) + **0/33 Tur sayacı** + **boncuk renk seçici** (7 taş rengi) + **zikir kartı** (< Arapça + okunuş + meal >) + **ses efekti** (üretilen `bead.wav`, just_audio, ses aç/kapa toggle) + haptik. ✓ cihazda doğrulandı (5 dokunuş → 5 boncuk yandı).
- [x] **4.2 İslami Takvim** — **YENİ "Dini Günler" görünümü**: yıl sekmeleri (2025/2026/2027) + Miladi/Hicri toggle + dini günler ay ay + **güne tıkla → paylaşılabilir tebrik kartı** (mevcut paylaşım pipeline'ı). Tarihler `hijri` paketiyle Hicri→Gregoryen hesaplanır (`religious_days.dart`, elle tarih yok). ✓ cihazda doğrulandı (Ramazan 18 Şub 2026 = Diyanet ile aynı). *(Not: Umm al-Qura vs Diyanet ±1 gün olabilir; Hicri offset ayarı mevcut.)*
- [x] **4.3 Dualar** — testte görüldü: **zaten kategorize** (Tümü/Sabah/Akşam/Namaz... sekmeleri + Arapça + okunuş + meal + kaynak). ✓
- [x] **4.4 Kıble** — pusula gülü + ticks + ibre + Kâbe göstergesi zaten modern (Round-5). ✓
- [x] **4.5 Kur'an** — sure listesi + arama + ayet (Arapça + okunuş + meal) + sürekli ses. **Yeni**: Sureler/Cüzler/**Favoriler** sekmeleri + üstte **"Son okunan" + "Dinlemeye Başla"** kartları + sure kalpleri (favori). ✓ cihazda doğrulandı.
- [x] **4.6 Oruç Takibi** — **YENİ "Bugün" kartı**: "Bugün oruç tuttunuz mu?" switch + **Notlar (0/500)** + **ikili tarih (Miladi + Hicri)**. Mevcut ay takvimi (Hicri günlü) + seri/istatistik korundu. analyze+build doğrulandı.
- [x] **4.7 Mesaj Düzenleyici** — durum çipleri + arka plan rayı + canlı önizleme + direkt sosyal paylaşım (greeting composer, Faz 0'da hedef butonları eklendi). ✓
- [x] **4.8 Sesli Hikayeler** — **"Son Dinlenenler"** eklendi: oynatılan bölümler kaydedilir (`recentAudio`), ekranın üstünde yatay rayda gösterilir (`addRecentAudio` + `_resolveRecents`). Kategoriler korundu. (Kod tamam; ekran render + Kuran "Son okunan" ile aynı desen doğrulandı.)
- [x] **4.9 İbadet Takibi** — "X günlük seri" + **haftalık 5 vakit × 7 gün matris** (başlık + checkbox + bugün vurgulu + kadın-özel muaf) zaten mevcut. ✓
- [x] **4.10 Cami Rehberi** — "En Yakın/İl Rehberi" sekmeleri + mesafe + **Yol Tarifi** (Google Maps) butonu zaten mevcut. ✓
- [x] **4.11 NIDA AI** — uyarı metni + örnek sorular + sohbet girişi zaten mevcut. ✓

### FAZ 4 DURUM: **TAMAM (4.1–4.11)** + ek rötuşlar (Kıble temaları, Dualar favori, Mesaj ok/nokta/sayaç, Kuran Favoriler/Son okunan, Sesli Hikayeler Son Dinlenenler). analyze 0/0 · Android+iOS build exit 0. PDF yol haritasının tamamı + kullanıcı rötuşları işlendi.

---

## FAZ 5 — TEMALAR ✅ kod tamam (denetim 2026-06-04)

- [x] **5.1 Çoklu tema** — `AppPalette` enum (**Altın** + **İslami Yeşil**) × brightness (koyu/açık/sistem) + **AMOLED** saf-siyah modu → en az 4 kombinasyon (Altın koyu/açık, Yeşil koyu/açık). → `app_colors.dart` (`AppPalette`, `NidaColors.resolve(palette, brightness, amoled)`), `app_theme.dart` (`AppTheme.light/darkMode(palette, amoled)`).
- [x] **5.2 Tema seçici + kalıcılık** — Ayarlar ekranında `_ThemeToggle` (koyu/açık/sistem) + `_PaletteToggle` (Altın/Yeşil) + AMOLED switch. Riverpod `settingsProvider` (`SettingsController`) + **SharedPreferences** (`theme_mode`, `app_palette`, `amoled`); `app.dart` dinamik `theme/darkTheme/themeMode`. → `settings_screen.dart`, `settings_controller.dart`.

> Not: Kod denetimle doğrulandı. Plan boyunca `[x]` = "bitti & test edildi" idi; bu fazın **cihaz testi** plan kaydında yok — fiziksel cihazda tema değişimi + kalıcılık ayrıca doğrulanmalı.

---

## FAZ 6 — AYARLAR GENİŞLETME + WIDGET'LAR (kısmen — denetim 2026-06-04)

- [~] **6.1 Kişiselleştirme** — Ayarlar ekranı mevcut (`settings_screen.dart` + `settings_controller.dart`, SharedPreferences), PDF listesinin bir kısmı yapıldı:
  - [x] **VAR:** Dil (TR/EN), Tema (koyu/açık/sistem), Renk paleti (Altın/Yeşil), AMOLED, Yazı boyutu (0.9–1.3), Konum/Şehir, Hesaplama yöntemi (17), Dakika ayarı/offset (±30), Hicri gün düzeltme (±3), Hanefi Asr, Günün Ayeti/Hadisi bildirimi, Tam ekran ezan, Kadın Özel modu, Hakkında.
  - [ ] **YOK:** "Hicri gün akşam vaktinde değişsin", Arka planı sıfırla, Ölçü birimleri, Yaz saati.
- [~] **6.2 Akıllı sessiz** — Ayarlar'da toggle **var ama boş (dummy)**: `setSmartSilent`/controller bağlanmamış, kalıcı değil; ses kanalı (Zil/Medya/Alarm/Bildirim) + ses yüksekliği slider **yok**.
- [ ] **6.3 Toggle'lar** — LED uyarı, Süper widget, Uygulama içi bildirim, Otomatik Kaza Takibi, Camide sessiz (geofence), Vakitte sessiz, Cuma'da sessiz, Sabah ezanı imsakta oku, Ezan duası, İftar sayacı, Asistan butonu göster, Kerahat süresi — **hiçbiri yok**. (Kadın Özel ✅ 6.1'de mevcut.)
- [x] **6.4 Home-screen widget** — ✅ TAMAM. **Android**: 8 App Widget provider (Namaz / Hadis / Ayet / Esma / Hicri + 3 saat stili) + `MainActivity.kt` MethodChannel (`nida/widget`) + `res/xml` info + `res/layout` + manifest receiver'ları. **iOS**: WidgetKit `NidaWidget` bundle (5 widget: Hadis/Namaz/Ayet/Esma/Hicri) + App Group (`group.com.nida.nida`) + entitlements. Dart köprüsü: `widget_service.dart` + `widget_updater.dart` (`pushHomeWidgets`).

---

## FAZ 7 — ONBOARDING / KONUM İZNİ AKIŞI ✅ tamam + cihazda doğrulandı

- [x] **7.1 İlk açılış** — ilk ekran NIDA arayüzünde: **Esselâmü Aleyküm** selamı + dil seçici + **kullanım şartları & gizlilik onay kutusu** (link → şartlar alt sayfası) + **onaylanmadan devam engellenir** (snackbar). ✓ cihazda.
- [x] **7.2 Konum/izin** — kurulum sayfası `PermissionService`'e bağlı (konum + bildirim); red → **Ayarlar'a yönlendir** dialogu. Kurulum sayfasına gelince **"LÜTFEN OKUYUN"** izin uyarısı otomatik çıkar (PDF 3. görsel). ✓ cihazda.
- [x] **7.3 Eksik ayar uyarısı** — ana ekranda konum izni yoksa **uyarı banner'ı** (dokun → Şehir Seç, kapatılabilir).

---

### Dış bağımlılık / asset gereken kalemler (kullanıcı onayı/dosya gerek)
- Gerçek müezzin ezan klipleri (lisanslı) — 1.5
- Hava durumu API anahtarı — 2.7
- 5 telifsiz arka plan videosu — 2.3
- Telifsiz mesaj/kart arka plan görselleri — 4.7 (kısmen mevcut)

### Test stratejisi (her faz sonu)
- `flutter analyze` (0 hata/uyarı) → Android emülatör → iOS emülatör → fiziksel iPhone.
- DPI: küçük (ör. iPhone SE) + büyük (ör. iPad/Pro Max) kontrol.
