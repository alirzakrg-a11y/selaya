import 'basic_item.dart';

/// Hac & Umre temelleri — çeşitleri, farz/vâcip, menâsik terimleri. İçerik
/// Diyanet İşleri Başkanlığı İlmihali (Hanefî mezhebi) esas alınarak
/// hazırlanmıştır; özel durumlar için yetkili kaynaklara başvurulmalıdır.

/// Hac çeşitleri (Hanefî): İfrad, Temettü, Kıran.
const hacCesitleri = <BasicItem>[
  BasicItem(
      'İfrad Haccı',
      'Ifrad Hajj',
      'Umre yapmaksızın yalnız hac için ihrama girilerek yapılan hactır. İfrad haccı yapana şükür kurbanı (hedy) vâcip olmaz.',
      'Hajj performed alone, without combining it with an umrah. The thanksgiving sacrifice (hady) is not required.'),
  BasicItem(
      'Temettü Haccı',
      'Tamattu Hajj',
      'Aynı yolculukta önce umre yapılıp ihramdan çıkılır; sonra (Terviye günü) hac için yeniden ihrama girilir. Şükür kurbanı (hedy) vâciptir.',
      'In one journey, umrah is performed first and ihram is exited; later one re-enters ihram for hajj. The thanksgiving sacrifice (hady) is required.'),
  BasicItem(
      'Kırân Haccı',
      'Qiran Hajj',
      'Umre ile hac, tek ihramda birleştirilerek (ihramdan çıkmadan) yapılır. Şükür kurbanı (hedy) vâciptir.',
      'Umrah and hajj are combined under a single ihram (without exiting ihram in between). The thanksgiving sacrifice (hady) is required.'),
];

/// Haccın farzları (Hanefî): biri şart (ihram), ikisi rükündür.
const haccinFarzlari = <BasicItem>[
  BasicItem(
      'İhrama girmek (şart)',
      'Entering ihram (condition)',
      'Mîkat sınırında hacca niyet edip telbiye getirerek ihrama girmek. İhram, haccın sıhhat şartıdır.',
      'Intending hajj and entering ihram with the talbiyah at the miqat. Ihram is the validity-condition of hajj.'),
  BasicItem(
      'Arafat’ta vakfe (rükün)',
      'Standing at Arafat (pillar)',
      'Arefe (Zilhicce 9) günü zevalden başlayıp bayram gecesi fecre (sabaha) kadarki süre içinde bir an dahi Arafat’ta bulunmak; gece ulaşan da vakfeyi yapmış olur. Bu vakti tamamen kaçıran haccı kaçırmış olur.',
      'Being present at Arafat for even a moment between midday on the Day of Arafah (9 Dhul-Hijjah) and the dawn of Eid; reaching it at night still counts. Missing this entire window means missing the hajj.'),
  BasicItem(
      'Ziyaret tavafı (rükün)',
      'Tawaf al-ifadah (pillar)',
      'Bayram günlerinde Kâbe’nin yedi şavt tavaf edilmesi (tavâf-ı ziyâret / ifâda). Bu tavaf yapılmadan hac tamamlanmaz.',
      'The seven-circuit tawaf of the Kaaba during the festival days (tawaf al-ziyarah / ifadah). Hajj is not complete without it.'),
];

/// Haccın başlıca vâcipleri (Hanefî).
const haccinVacipleri = <BasicItem>[
  BasicItem('Sa’y', 'Sa’i',
      'Safâ ile Merve arasında yedi defa gidip gelmek.', 'Walking seven times between Safa and Marwah.'),
  BasicItem('Müzdelife’de vakfe', 'Standing at Muzdalifah',
      'Bayram (Kurban) sabahı, fecirden (tan yeri ağarınca) güneş doğana kadar Müzdelife’de vakfe yapmak. (Geceyi orada geçirmek sünnettir.)',
      'Standing (waqfah) at Muzdalifah on the morning of Eid, from dawn (fajr) until sunrise. (Spending the night there is a sunnah.)'),
  BasicItem('Şeytan taşlama', 'Stoning the Jamarat',
      'Bayram günlerinde cemrelere belirlenen sayıda taş atmak.', 'Throwing the prescribed number of pebbles at the Jamarat during the festival days.'),
  BasicItem('Saç tıraşı / kısaltma', 'Shaving or shortening hair',
      'Menâsik sonunda saçı tıraş etmek (halk) veya kısaltmak (taksîr).', 'Shaving (halq) or shortening (taqsir) the hair after the rites.'),
  BasicItem('Mîkatta ihrama girmek', 'Entering ihram at the miqat',
      'İhrama mîkat sınırını geçmeden girmek.', 'Entering ihram before crossing the miqat boundary.'),
  BasicItem('Veda tavafı', 'Farewell tawaf',
      'Âfâkî (Mekke dışından gelen) hacıların Mekke’den ayrılırken yaptığı son tavaf.', 'The final tawaf performed by pilgrims from outside Mecca (afaqi) upon departure.'),
];

/// Umrenin farzları (Hanefî): ihram şart, tavaf rükündür.
const umreninFarzlari = <BasicItem>[
  BasicItem('İhrama girmek (şart)', 'Entering ihram (condition)',
      'Mîkatta umreye niyet edip telbiye ile ihrama girmek.', 'Intending umrah and entering ihram with the talbiyah at the miqat.'),
  BasicItem('Tavaf (rükün)', 'Tawaf (pillar)',
      'Kâbe’yi yedi şavt tavaf etmek. Umrenin rüknü tavaftır.', 'Performing seven circuits around the Kaaba. Tawaf is the pillar of umrah.'),
];

/// Umrenin vâcipleri (Hanefî).
const umreninVacipleri = <BasicItem>[
  BasicItem('Sa’y', 'Sa’i',
      'Safâ ile Merve arasında yedi defa sa’y yapmak.', 'Performing sa’i seven times between Safa and Marwah.'),
  BasicItem('Saç tıraşı / kısaltma', 'Shaving or shortening hair',
      'Sa’yden sonra halk veya taksîr ile ihramdan çıkmak.', 'Exiting ihram after sa’i by shaving or shortening the hair.'),
];

/// Menâsik (hac/umre) terimleri sözlüğü.
const menasikTerimleri = <BasicItem>[
  BasicItem('İhram', 'Ihram',
      'Hac/umre niyetiyle, normalde helâl olan bazı şeyleri (dikişli elbise, koku, tıraş, avlanma vb.) kendine yasaklama hâli. Erkekler iki parça dikişsiz örtüye bürünür.',
      'The sacred state in which certain normally-permitted things (sewn clothes, perfume, cutting hair, hunting…) are forbidden. Men wear two unstitched cloths.'),
  BasicItem('Mîkat', 'Miqat',
      'İhrama girmeden geçilmemesi gereken belirli yer/sınırlar.', 'The fixed boundaries that must not be crossed without entering ihram.'),
  BasicItem('Telbiye', 'Talbiyah',
      '“Lebbeyk Allâhümme lebbeyk…” diye getirilen icabet duası.', 'The response-prayer “Labbayk Allahumma labbayk…”.'),
  BasicItem('Tavaf', 'Tawaf',
      'Hacerü’l-Esved hizasından başlayıp Kâbe’nin etrafında yedi defa dönmek. Her dönüş bir “şavt”tır.',
      'Circling the Kaaba seven times starting from the Black Stone. Each circuit is a “shawt”.'),
  BasicItem('Hacerü’l-Esved', 'Black Stone',
      'Kâbe’nin köşesindeki siyah taş; tavaf bu hizadan başlatılır ve istilâm edilir.', 'The black stone at the Kaaba’s corner; tawaf begins from its line and it is saluted (istilam).'),
  BasicItem('Remel', 'Ramal',
      'Tavafın ilk üç şavtında erkeklerin çalımlı ve hızlı yürümesi.', 'Men walking briskly with a proud gait in the first three circuits of tawaf.'),
  BasicItem('Iztıbâ', 'Idtiba',
      'Tavafta erkeklerin ihramın bir ucunu sağ koltuk altından geçirip sol omza atması.', 'Men passing the ihram cloth under the right armpit and over the left shoulder during tawaf.'),
  BasicItem('Sa’y', 'Sa’i',
      'Safâ ile Merve tepeleri arasında yedi defa gidip gelmek.', 'Walking seven times between the hills of Safa and Marwah.'),
  BasicItem('Hervele', 'Harwalah',
      'Sa’yde yeşil ışıklı bölümde erkeklerin koşar adım yürümesi.', 'Men jogging in the green-lit section during sa’i.'),
  BasicItem('Vakfe', 'Waqfah',
      'Arafat ve Müzdelife’de belirli vakitte bir süre durmak/bulunmak.', 'Standing/being present for a time at Arafat and Muzdalifah within the set period.'),
  BasicItem('Cemerât', 'Jamarat',
      'Mina’da şeytan taşlamanın yapıldığı üç taş yeri (Küçük, Orta, Akabe).', 'The three stoning sites at Mina (small, middle, Aqabah).'),
  BasicItem('Hedy', 'Hady',
      'Temettü ve kırân haccında kesilen şükür kurbanı.', 'The thanksgiving sacrifice offered in tamattu and qiran hajj.'),
  BasicItem('Halk / Taksîr', 'Halq / Taqsir',
      'Menâsik sonunda saçı tıraş etme (halk) veya kısaltma (taksîr).', 'Shaving (halq) or shortening (taqsir) the hair after the rites.'),
  BasicItem('Tahallül', 'Tahallul',
      'İhram yasaklarından çıkma. Hacda ilk ve ikinci tahallül vardır.', 'Exiting the restrictions of ihram. In hajj there is a first and a second tahallul.'),
];
