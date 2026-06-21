// Cami/mescit adabı + giriş-çıkış duaları. İçerik Diyanet İşleri Başkanlığı
// çizgisinde, Sünnî anlayışa göre hazırlanmıştır.

class MosqueDua {
  final String arabic, reading;
  final String meaningTr, meaningEn;
  final String source;
  const MosqueDua(this.arabic, this.reading, this.meaningTr, this.meaningEn,
      this.source);
  String meaning(String l) => l == 'tr' ? meaningTr : meaningEn;
}

/// Mescide girerken okunan dua (Müslim, Mesâcid 68).
const mosqueEnterDua = MosqueDua(
  'اَللّٰهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
  'Allâhümme’ftah lî ebvâbe rahmetik.',
  'Allah’ım! Bana rahmet kapılarını aç.',
  'O Allah, open for me the gates of Your mercy.',
  'Müslim, Mesâcid 68',
);

/// Mescidden çıkarken okunan dua (Müslim, Mesâcid 68).
const mosqueExitDua = MosqueDua(
  'اَللّٰهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
  'Allâhümme innî es’elüke min fadlik.',
  'Allah’ım! Senden lütfunu (fazlını) isterim.',
  'O Allah, I ask You of Your bounty.',
  'Müslim, Mesâcid 68',
);

class AdabItem {
  final String titleTr, titleEn;
  final String descTr, descEn;
  const AdabItem(this.titleTr, this.titleEn, this.descTr, this.descEn);
  String title(String l) => l == 'tr' ? titleTr : titleEn;
  String desc(String l) => l == 'tr' ? descTr : descEn;
}

const mosqueAdab = <AdabItem>[
  AdabItem(
    'Temiz ve abdestli gelmek',
    'Come clean and in wudu',
    'Camiye temiz bir beden ve elbiseyle, abdestli olarak gelmek; güzel koku sürünmek güzeldir.',
    'Come with a clean body and clothes, in a state of wudu; using a pleasant scent is recommended.',
  ),
  AdabItem(
    'Sağ ayakla ve dua ile girmek',
    'Enter right foot first, with the du‘a',
    'Camiye sağ ayakla, giriş duasını okuyarak girmek sünnettir.',
    'It is sunnah to enter right foot first while reciting the entry du‘a.',
  ),
  AdabItem(
    'Tahiyyetü’l-mescid',
    'Tahiyyat al-masjid',
    'Oturmadan önce, “mescidi selamlama” niyetiyle iki rekât namaz kılmak müstehaptır (mekruh vakitlerde veya hemen farza/cemaate duracaksa kılınmaz).',
    'Before sitting, praying two rak‘ahs to “greet the mosque” is recommended (omitted at disliked times or if the congregational prayer is about to begin).',
  ),
  AdabItem(
    'Sükûnet ve saygı',
    'Calm and respect',
    'İçeride sesi yükseltmemek, telefonu sessize almak, dünya kelâmından sakınmak; namaz kılanları rahatsız etmemek.',
    'Keep your voice low, silence your phone, avoid idle talk, and do not disturb those praying.',
  ),
  AdabItem(
    'Safları düzgün tutmak',
    'Keep the rows straight',
    'Cemaatte safları sık ve düzgün tutmak, öndeki boşlukları doldurmak; namaz kılanın önünden geçmemek (sütre edinmek).',
    'In congregation, keep the rows straight and filled; do not pass in front of someone praying (use a sutrah).',
  ),
  AdabItem(
    'Rahatsız edici kokulardan kaçınmak',
    'Avoid offensive smells',
    'Soğan, sarımsak gibi rahatsız edici kokularla veya sigara kokusuyla camiye girmemek.',
    'Do not enter the mosque smelling of onion, garlic or smoke that bothers others.',
  ),
  AdabItem(
    'Sol ayakla ve dua ile çıkmak',
    'Leave left foot first, with the du‘a',
    'Camiden sol ayakla, çıkış duasını okuyarak ayrılmak sünnettir.',
    'It is sunnah to leave left foot first while reciting the exit du‘a.',
  ),
];
