/// Namazın temelleri — şartları, rükünleri, bozan şeyler, secde-i sehv.
/// İçerik Diyanet İlmihali esas alınarak hazırlanmıştır (Hanefî). Ayrıntı için
/// yetkili kaynaklara başvurulmalıdır.
class BasicItem {
  final String titleTr, titleEn;
  final String descTr, descEn;
  const BasicItem(this.titleTr, this.titleEn, this.descTr, this.descEn);
  String title(String l) => l == 'tr' ? titleTr : titleEn;
  String desc(String l) => l == 'tr' ? descTr : descEn;
}

/// Namazın şartları — namaza BAŞLAMADAN önce yerine getirilen (dış) farzlar.
const namazSartlari = <BasicItem>[
  BasicItem(
      'Hadesten Tahâret',
      'Purity from ritual impurity',
      'Abdesti olmayan abdest alır; gusül gerekiyorsa gusleder.',
      'Perform wudu before praying — or ghusl if a full bath is required.'),
  BasicItem(
      'Necâsetten Tahâret',
      'Purity from physical impurity',
      'Beden, elbise ve namaz kılınacak yer maddî pisliklerden temiz olmalıdır.',
      'The body, clothing and place of prayer must be free of physical impurity.'),
  BasicItem(
      'Setr-i Avret',
      'Covering the ʿawrah',
      'Örtülmesi gereken yerlerin (avret mahalli) uygun şekilde kapatılması.',
      'Properly covering the parts of the body that must be covered.'),
  BasicItem(
      'İstikbâl-i Kıble',
      'Facing the qibla',
      'Kâbe yönüne (kıbleye) dönmek.',
      'Turning toward the Kaaba (the qibla).'),
  BasicItem(
      'Vakit',
      'The appointed time',
      'Her namazı kendi vakti içinde kılmak.',
      'Praying each prayer within its own time.'),
  BasicItem(
      'Niyet',
      'Intention',
      'Kılınacak namaza kalben niyet etmek; dil ile söylemek müstehaptır.',
      'Intending in the heart which prayer one performs (saying it aloud is recommended).'),
];

/// Namazın rükünleri — namazın İÇİNDEKİ farzlar (asıl unsurları).
const namazRukunleri = <BasicItem>[
  BasicItem(
      'İftitah Tekbiri',
      'Opening takbir',
      '“Allâhü ekber” diyerek namaza başlamak.',
      'Beginning the prayer by saying “Allāhu akbar”.'),
  BasicItem(
      'Kıyam',
      'Standing',
      'Gücü yetenin farz ve vacip namazlarda ayakta durması.',
      'Standing upright for those able, in obligatory and wajib prayers.'),
  BasicItem(
      'Kıraat',
      'Recitation',
      'Kur’an’dan okumak: Fâtiha ve ardından bir miktar daha (zamm-ı sûre).',
      'Reciting from the Quran: al-Fātiha followed by some additional verses.'),
  BasicItem(
      'Rükû',
      'Bowing',
      'Eller dizlere varacak şekilde eğilmek.',
      'Bowing so that the hands reach the knees.'),
  BasicItem(
      'Sücûd (Secde)',
      'Prostration',
      'Her rekâtta alın ve burnu yere koyarak iki kez secde etmek.',
      'Prostrating twice each rakah, placing forehead and nose on the ground.'),
  BasicItem(
      'Ka‘de-i Ahîre',
      'Final sitting',
      'Son rekâtta Tahiyyat’ı okuyacak kadar oturmak.',
      'Sitting at the end long enough to recite the Tashahhud.'),
];

/// Namazı bozan başlıca şeyler.
const namaziBozanlar = <BasicItem>[
  BasicItem('Konuşmak', 'Speaking',
      'Az da olsa kasten konuşmak namazı bozar.', 'Speaking deliberately, even a little.'),
  BasicItem('Yiyip içmek', 'Eating or drinking',
      'Ağızdaki bir kırıntıyı yutmak dahi namazı bozar.', 'Swallowing even a small morsel.'),
  BasicItem('Kahkaha ile gülmek', 'Laughing out loud',
      'Sesli gülmek hem namazı hem abdesti bozar.', 'Audible laughter breaks both the prayer and wudu.'),
  BasicItem('Kıbleden dönmek', 'Turning from the qibla',
      'Özürsüz olarak göğsü kıbleden çevirmek.', 'Turning the chest away from the qibla without excuse.'),
  BasicItem('Amel-i kesir', 'Excessive movement',
      'Namazla ilgisi olmayan, dışarıdan “namazda değil” dedirtecek çok hareket.',
      'Movement so much that an onlooker would think one is not praying.'),
  BasicItem('Abdestin bozulması', 'Wudu being nullified',
      'Namaz içinde abdestin bozulması.', 'The wudu becoming invalid during prayer.'),
  BasicItem('Selam verip almak', 'Giving or returning salam',
      'Namaz içinde başkasına selam vermek veya sözle selam almak.',
      'Greeting someone or verbally returning a greeting during prayer.'),
];

/// Secde-i sehv (yanılma secdesi).
const secdeSehvTr =
    'Namazda yanılarak bir vâcibin terk edilmesi ya da bir farzın/vâcibin '
    'geciktirilmesi (örneğin ilk oturuşu —ka‘de-i ûlâ— unutmak) durumunda '
    'yapılır: son oturuşta sağ tarafa selâm verildikten sonra iki secde daha '
    'yapılır; ardından Tahiyyât ve dualar okunup her iki tarafa selâm verilerek '
    'namaz tamamlanır.';
const secdeSehvEn =
    'Performed when one forgetfully omits a wajib or delays a fard/wajib (e.g. '
    'forgetting the first sitting): after saluting to the right at the final '
    'sitting, two more prostrations are made; then the Tashahhud and '
    'supplications are recited and the prayer is completed with the salam to '
    'both sides.';
