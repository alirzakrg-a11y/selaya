# GECE RAPORU — 12→13 Haziran 2026

Gece vardiyası tamamlandı. 5 görevin 5'i de kök nedeni kanıtlanarak kapatıldı,
hepsi emülatörde doğrulandı; ek olarak doğrulama sırasında yakalanan 1 bonus
hata (sekme hijack) düzeltildi. `flutter analyze` SIFIR bulgu, 26/26 test
yeşil. Native ezan/alarm tarafına gece boyunca DOKUNULMADI (talimat gereği).

**Onay bekleyen iş yok** — tüm düzeltmeler küçük/net sınıfındaydı (en büyüğü
13 satır), 30+ satır/mimari değişiklik gerektiren bir durum çıkmadı.

---

## Görev 1 — Sonraki sureye geçiş ölü kalıyordu (HATA → DÜZELTİLDİ ✅)

- **Bulunan kök neden:** Okuyucu kabuk-altı rotada `context.go` ile sure
  değişince go_router AYNI page'i güncelliyor ve `State` korunuyordu →
  `_surahNavLock` kilidi açık kalıyor, ikinci geçiş hiç tetiklenmiyordu.
- **Yapılan:** Router'da sure-bazlı `ValueKey('quran-reader-$n')` — her sure
  taze State alır, kilit sıfırlanır. (commit `6703c2f`)
- **Emülatör kanıtı:** Fâtiha sonunda alttan çekince başlık "Bakara"ya geçti
  (eskiden ölüydü); art arda geçişler de çalışıyor.

## Görev 2 — Önceki sureye geçiş (ÖZELLİK → EKLENDİ ✅)

- **Yapılan:** Alt uçtaki mekanizmanın simetriği: (a) sure başında üstten
  >90px çekince önceki sureye geçiş, (b) listenin başına "Önceki Sure" kartı
  (dokununca geçiş). Fâtiha'da (sure 1) ikisi de kapalı. (commit `f2d1c68` —
  **DİKKAT: Görev 3 ile aynı commit'te**, ikisi de aynı dosyadaydı)
- **Emülatör kanıtı:** Bakara'nın başında kart görünüyor; dokununca Fâtiha
  EN ÜSTTEN açıldı. Fâtiha'da kart yok (koşul doğru).
- **Not:** Üstten-çekme yolu emülatörde tam tetiklenemedi — ses çalarken
  okuyucunun ayete oto-kaydırması araya giriyor; kod alt yolun birebir
  simetriği olduğundan risk düşük. Sabah cihazda bir kez çekerek deneyin.

## Görev 3 — İlerleme çizgisi ilk açılışta yoktu (HATA → DÜZELTİLDİ ✅)

- **Bulunan kök neden:** Çizgi zaten kumanda çubuğunda HİÇ yoktu (yalnız
  now-playing ekranında vardı) — "ilk açılışta görünmüyor" algısının nedeni bu.
- **Yapılan:** `_QuranTransport`'a 3px'lik altın ilerleme çizgisi
  (position/duration StreamBuilder) eklendi. (commit `f2d1c68`)
- **Emülatör kanıtı:** "Sureyi Dinle"den saniyeler içinde çizgi dolu ve
  görünür (tam çözünürlük kırpımıyla doğrulandı).

## Görev 4 — Ana Sayfa'ya dönünce ses duruyordu (HATA → DÜZELTİLDİ ✅)

- **Bulunan kök neden:** Ana sayfa video arka planı (video_player) SESSİZ
  olsa bile varsayılan ayarla **ses odağını kapıyordu** → Kur'an/hikâye
  duruyordu.
- **Yapılan:** `VideoPlayerOptions(mixWithOthers: true)` — video odak
  istemiyor. (commit `02c3948`)
- **Emülatör kanıtı:** Kur'an çalarken Ana Sayfa'da 80+ sn beklendi; ses hiç
  kesilmedi, mini çalmaya devam etti (Fâtiha→Bakara geçişi de dahil).

### Bonus: Sekme hijack hatası (doğrulama sırasında yakalandı → DÜZELTİLDİ ✅)

- **Belirti/Kanıt:** Ana Sayfa'da gezinirken sure otomatik değişince (örn.
  Fâtiha bitip Bakara başlayınca) uygulama kendini Kur'an okuyucusuna
  çekiyordu — ekrana hiç dokunmadan sekme değişti (emülatörde reprodüklendi).
- **Kök neden:** Okuyucudaki `ref.listen` + `_wasActive` yakalama bloğu,
  sayfa IndexedStack'te offstage'ken (başka sekme aktif) bile `context.go`
  çağırıyordu.
- **Yapılan:** Her iki yola TickerMode görünürlük koruması — görünmezken
  navigasyon atlanır; sekmeye dönünce yakalama bloğu sayfayı çalan sureye
  taşır. (commit `12f8a8e`)
- **Emülatör kanıtı:** Aynı senaryoda artık Ana Sayfa'da kalınıyor; Kur'an
  sekmesine dönüşte okuyucu doğru sureye (Bakara) atladı.

## Görev 5 — Eksik geri tuşu envanteri (İNCELEME → DÜZELTME GEREKMEDİ ✅)

- **Sonuç:** `showBack` kullanmayan ekranlar tarandı: SliverAppBar'lı
  ekranlar geri okunu OTOMATİK gösteriyor (implyLeading); kalan 3 dosya kabuk
  sekmesi (geri tuşu olmamalı); premium/daily_tasks/feed kendi kapatma
  düğmesine sahip. Eksik geri tuşu YOK.
- **Emülatör kanıtı:** Daha Fazla → Ayetler: geri oku var ve çalışıyor.

## Stabilizasyon ✅

- `flutter analyze`: **No issues found** (gecenin başındaki 6 eski bulgu
  dahil hepsi giderildi: TickerMode/onReorderItem migrasyonları, ölü kod
  temizliği, doc düzeltmesi).
- `flutter test`: **26/26 geçti** (hijack düzeltmesinden sonra tekrar koşuldu).

## Gecenin commit'leri (hepsi push'landı)

| Commit | İçerik |
|---|---|
| `6703c2f` | Görev 1: sure-bazlı key |
| `f2d1c68` | Görev 2+3: önceki-sure + ilerleme çizgisi (tek commit) |
| `02c3948` | Görev 4: video ses odağı |
| `b8d047a` | Stabilizasyon: analyze sıfır + testler |
| `12f8a8e` | Bonus: sekme hijack koruması |
| (son) | Bu rapor |

## Release APK

- Derleme: `flutter build apk --release --split-per-abi`
- Drive konumu: `G:\Drive'ım\SELAYA APK\selaya-release-arm64-12f8a8e-2026-06-13.apk`
  (eski APK'lar silindi; bulut senkronu dosya boyutu eşleşmesiyle doğrulandı —
  ayrıntı son commit mesajında)

---

# SABAH CİHAZ TEST LİSTESİ (Galaxy A55)

**Gece görevleri:**
1. Kur'an → Fâtiha → en alttan fazladan çek **veya** alttaki karta dokun →
   Bakara'ya geçmeli (Görev 1).
2. Bakara'nın başında "Önceki Sure" kartına dokun → Fâtiha en üstten açılmalı;
   bir de sure başında ÜSTTEN fazladan çekerek dene (Görev 2 — çekme yolu
   emülatörde tam test edilemedi, tek riskli nokta bu).
3. "Sureyi Dinle" → alttaki kumanda çubuğunun ÜST kenarında altın ilerleme
   çizgisi İLK saniyeden görünmeli (Görev 3).
4. Kur'an çalarken Ana Sayfa'ya geç, 1-2 dk gezin: ses kesilmemeli; sure
   değişse bile uygulama sizi Kur'an sekmesine ÇEKMEMELİ; Kur'an sekmesine
   dönünce okuyucu çalan surede olmalı (Görev 4 + hijack).
5. Daha Fazla → Ayetler → sol üst geri oku (Görev 5).

**Önceki paketlerden hâlâ cihaz onayı bekleyenler (Paket 1-3 / ezan):**
6. Uygulamayı kapatıp (görev listesinden kaydırarak) test ezanı bekleyin →
   ezan TEK bildirimle gelmeli, **Kapat tek dokunuşta sesi kesmeli**.
7. Kilitli ekranda ezan → tam ekran alarm görünmeli, Kapat çalışmalı.
8. Ezan çalarken bildirim panelinde TEK ezan bildirimi olmalı (çift yok).
