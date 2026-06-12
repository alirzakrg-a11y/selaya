# NIDA — İslami Asistan

NIDA; namaz vakitlerinden Kur'an-ı Kerim'e, Kıble'den dini takvime kadar günlük
ibadet hayatını tek çatı altında toplayan bir **Flutter** İslami asistan
uygulamasıdır. Koyu/altın tema kimliği, sade arayüz ve "az reklam" hedefiyle
geliştirilir.

## Özellikler

- **Namaz vakitleri** — 17 hesaplama yöntemi, dakika/Hicri düzeltme, genişletilmiş
  vakitler (işrak, evvabin, seher, kerahat) ve 3 stilli geri-sayım göstergesi
  (hero kart / dairesel kadran / zaman çizelgesi) video arka planla.
- **Bildirimler** — vakit zamanında + vakitlerden önce (çoklu dakika hatırlatma),
  8 isimli müezzin ezan sesi (önizlemeli), Android kalıcı geri-sayım bildirimi.
- **İçerik** — Kur'an-ı Kerim (ses + meal + favoriler), Dualar, Esmaül Hüsna,
  Yâsîn, Zikirmatik, İslami Kütüphane, Sesli Hikayeler.
- **Takip** — İbadet, Oruç ve Kaza takibi; İslami takvim + dini günler
  (güne tıkla → paylaşılabilir tebrik kartı).
- **Araçlar** — Kıble pusulası, En Yakın Cami (yol tarifi), Duvar Kağıtları,
  İslami Sticker'lar, NIDA AI asistanı, Hava durumu (Open-Meteo).
- **Ana ekran widget'ları** — Android (8 widget) + iOS WidgetKit (5 widget):
  namaz vakitleri, hadis, ayet, esma, Hicri tarih, saat stilleri.
- **Temalar & dil** — Altın / İslami Yeşil paleti × koyu/açık/sistem + AMOLED;
  Türkçe / İngilizce.
- **Paylaşım** — WhatsApp / Instagram / Facebook'a doğrudan görsel paylaşımı.

## Mimari

- **Flutter + Riverpod** (durum yönetimi), feature-first klasör yapısı
  (`lib/features/...`, ortak parçalar `lib/core/...`).
- Kalıcılık: SharedPreferences + JSON asset'ler (`assets/data/...`).
- Yerel (native): Android Kotlin App Widget'ları + iOS Swift WidgetKit
  (App Group ile veri senkronu).

## Geliştirme

Yol haritası ve faz durumu için **[GELISTIRME_PLANI.md](GELISTIRME_PLANI.md)**.

```bash
flutter pub get
flutter run
```

Görsel kaynak telifleri için `assets/images/CREDITS.md` dosyasına bakın.
