import 'package:flutter/material.dart';

/// Özel / nafile namazlar rehberi (5 vakit dışında). İçerik, çok-ajanlı
/// adversaryal DİYANET/Hanefî doğrulamasından geçirildi (2026-06-29):
/// 10'u ana akım, Teveccüh ana akım DIŞI olduğu için kendi içinde net uyarı
/// + doğru alternatif (Hâcet/Teheccüd) ile sunulur. Kaynak: Diyanet İlmihali.
class SpecialPrayer {
  final String key;
  final String nameTr, nameEn;
  final IconData icon;
  final String rakats;
  final String whenTr, whenEn;
  final String howTr, howEn;
  final String niyetTr;
  final String reciteTr;
  final bool mainstream; // Diyanet ana akımında müstakil namaz mı
  final String warningTr; // ana akım dışı/ihtilaflı uyarısı (yoksa boş)

  const SpecialPrayer({
    required this.key,
    required this.nameTr,
    required this.nameEn,
    required this.icon,
    required this.rakats,
    required this.whenTr,
    required this.whenEn,
    required this.howTr,
    required this.howEn,
    required this.niyetTr,
    required this.reciteTr,
    this.mainstream = true,
    this.warningTr = '',
  });

  String name(String l) => l == 'tr' ? nameTr : (nameEn.isEmpty ? nameTr : nameEn);
  String when(String l) => l == 'tr' ? whenTr : (whenEn.isEmpty ? whenTr : whenEn);
  String how(String l) => l == 'tr' ? howTr : (howEn.isEmpty ? howTr : howEn);
}

const specialPrayers = <SpecialPrayer>[
  SpecialPrayer(
    key: 'teheccud',
    nameTr: 'Teheccüd Namazı',
    nameEn: 'Tahajjud (Night Vigil) Prayer',
    icon: Icons.nightlight_round,
    rakats: 'En az 2 rekât; genellikle 2şer rekât hâlinde 4, 6 veya 8 rekât (üst sınır yoktur)',
    whenTr: 'Yatsıdan sonra bir süre uyunup, gecenin ikinci yarısında / seher vaktinde (sabah namazından önce) kalkılarak kılınır. En faziletli vakit gecenin son üçte biridir. Uyuyup kalkmak teheccüdün şartı sayılır.',
    whenEn: 'After Isha, one sleeps and then wakes in the latter part of the night (pre-dawn) to pray it. The most virtuous time is the last third of the night.',
    howTr: 'Abdest alınır, 2şer rekât hâlinde kılınır. Her rekâtta Fâtiha’dan sonra bir miktar Kur’an okunur; iki rekâtta bir oturup tahiyyat okunarak selâm verilir. İstenildiği kadar 2şer rekât tekrarlanabilir (4-6-8). Acele edilmeden, huşû ile, uzunca kıyam-rükû-secde ile kılınması müstehaptır. Namaz sonrası dua, istiğfar ve Kur’an okumak tavsiye edilir.',
    howEn: 'Perform wudu, then pray in sets of two rakats: in each rakat recite Fatiha plus a portion of the Quran, sit for tashahhud and give salam every two rakats. Repeat as desired (4, 6, 8). Praying slowly with devotion and longer recitation, followed by supplication and istighfar, is recommended.',
    niyetTr: '“Niyet ettim Allah rızası için teheccüd (gece) namazını kılmaya.”',
    reciteTr: 'Belirli bir sûre şartı yoktur; Fâtiha’dan sonra bilinen sûreler okunur. Uzun kıraat müstehaptır. Namaz sonrasında istiğfar, salavat ve münâcât; seher vaktinde Kur’an okumak tavsiye edilir.',
  ),
  SpecialPrayer(
    key: 'kusluk',
    nameTr: 'Kuşluk (Duhâ) Namazı',
    nameEn: 'Duha (Forenoon) Prayer',
    icon: Icons.wb_twilight_rounded,
    rakats: 'En az 2 rekât; genellikle 4 (2+2), 8 rekâta kadar (ikişer ikişer)',
    whenTr: 'Güneş bir-iki mızrak boyu (yaklaşık 45-50 dk) yükseldikten sonra başlar, öğleye (zevale) kadar sürer. En faziletli vakti kuşluğun ilerlediği, sıcağın bastırdığı zamandır.',
    whenEn: 'From about 45-50 min after sunrise until just before midday (zawal). The most virtuous time is later in the forenoon.',
    howTr: 'Nâfile niyetiyle ikişer rekât olarak kılınır. Her rekâtta Fâtiha ardından bir sûre okunur; iki rekâtta bir selâm verilir. 4 veya daha fazla rekât için ikişerli düzen tekrarlanır. Sünnet/nâfile namazların genel kılınışıyla aynıdır.',
    howEn: 'Prayed as a voluntary prayer in units of two rakats, giving salam after each two. Recite Fatiha plus a sura each rakat. Repeat for 4 or more rakats.',
    niyetTr: '“Niyet ettim Allah rızası için kuşluk (duhâ) namazını kılmaya.”',
    reciteTr: 'Belirli bir sûre şartı yoktur. Tavsiye: 1. rekâtta Şems, 2. rekâtta Duhâ sûresi; ya da Kâfirûn ve İhlâs. Bu zorunlu değil, müstehaptır.',
  ),
  SpecialPrayer(
    key: 'evvabin',
    nameTr: 'Evvâbîn Namazı',
    nameEn: 'Awwabin Prayer',
    icon: Icons.brightness_3_rounded,
    rakats: '6 rekât (2+2+2; tek selâmla veya 4+2 de olur)',
    whenTr: 'Akşam namazından sonra, yatsı vaktine kadar olan zaman diliminde kılınır. Akşamın son sünnetinden sonra kılınan altı rekât nafiledir (Diyanet’e göre akşamın sünneti bu altıya sayılabilir).',
    whenEn: 'After the Maghrib prayer, within the window before Isha. It is the six-rakat voluntary prayer following Maghrib.',
    howTr: 'İkişer rekâtlık bölümler hâlinde üç selâmla kılmak en yaygın uygulamadır (Hanefî’de tek selâmla veya 4+2 de olur). Her rekâtta Fâtiha’dan sonra bir sûre okunur, normal namaz gibi rükû ve secde yapılır; son oturuşta tahiyyat + salli-bârik + dua ile selâm verilir.',
    howEn: 'Most commonly three units of two rakats (three taslims); in the Hanafi school also six with one taslim or 4+2. Each rakat is like an ordinary prayer.',
    niyetTr: '“Niyet ettim Allah rızası için evvâbîn namazını kılmaya.” (İkişer rekât kılınıyorsa her bölümde yeniden niyet edilir.)',
    reciteTr: 'Belirli bir sûre şartı yoktur; kısa sûreler (İhlâs, Felak, Nâs) okunabilir. Namaz sonrası tevbe-istiğfar ve duaya yönelmek menduptur (evvâbîn = Allah’a çokça yönelenler).',
  ),
  SpecialPrayer(
    key: 'tesbih',
    nameTr: 'Tesbih Namazı',
    nameEn: 'Salat al-Tasbih',
    icon: Icons.auto_awesome_rounded,
    rakats: '4 rekât (gündüz tek selâmla, gece 2+2)',
    whenTr: 'Belirli bir vakti yoktur; mekruh vakitler (güneş doğarken, tam tepedeyken, batarken) dışında her zaman kılınabilir. Geçmiş hataların bağışlanması niyetiyle kılınan nafiledir; ömürde bir kez bile olsa kılınması tavsiye edilmiştir.',
    whenEn: 'Any time except the three forbidden times; a voluntary prayer for seeking forgiveness, recommended at least once in a lifetime.',
    howTr: '4 rekât kılınır; namaz boyunca her rekâtta 75, toplam 300 defa “Sübhânallâhi velhamdü lillâhi velâ ilâhe illallâhü vallâhü ekber” tesbihi okunur. Her rekâtta dağılım: ayakta Sübhâneke/kıraat sonrası 15, kıraat sonrası rükûdan önce 10, rükûda 10, rükûdan doğrulunca 10, 1. secdede 10, iki secde arası 10, 2. secdede 10 (15+10×6=75). Sübhâneke yalnız 1. ve 3. rekâtın başında okunur; okunmayan 2. ve 4. rekâtta o 15 tesbih, Fâtiha’dan önce ayakta okunur. Tesbihler tercihen kalben sayılır.',
    howEn: 'Four rakats with 75 tasbih per rakat (300 total), distributed across the standing, ruku and sujud postures: “SubhanAllahi wal-hamdu lillahi wa la ilaha illallahu wallahu akbar.”',
    niyetTr: '“Niyet ettim Allah rızası için tesbih namazı kılmaya.”',
    reciteTr: 'Fâtiha’dan sonra herhangi bir sûre okunabilir. Asıl zikir, namaz boyunca 300 defa tekrarlanan tesbih cümlesidir.',
    warningTr: 'Tesbih namazı sahih hadis kaynaklarında (Ebû Dâvûd, Tirmizî, İbn Mâce) yer alan ve Diyanet İlmihali’nde tanınan bir nafiledir. Rivayetin sübûtu ve kılınış biçimi konusunda fıkhî ihtilaf vardır; özü her rekâtta 75, toplam 300 tesbihtir. Tarikat-özel değildir.',
  ),
  SpecialPrayer(
    key: 'hacet',
    nameTr: 'Hâcet Namazı',
    nameEn: 'Prayer of Need (Salat al-Hajah)',
    icon: Icons.pan_tool_alt_rounded,
    rakats: '2 rekât (asgari); 4 rekât da kılınabilir',
    whenTr: 'Dünyevî veya uhrevî bir ihtiyaç/dilek için, mekruh vakitler dışında her zaman kılınabilir. Geceleri, özellikle teheccüd vaktinde kılınması faziletlidir. Belirli bir günü yoktur; ihtiyaç hissedildiğinde kılınır.',
    whenEn: 'For any worldly or otherworldly need, any time except the forbidden times. The late-night (tahajjud) hours are especially virtuous.',
    howTr: 'Güzelce abdest alınır. Dört rekât kılınacaksa: 1. rekâtta Fâtiha’dan sonra 3 defa Âyetü’l-kürsî; 2., 3. ve 4. rekâtlarda Fâtiha’dan sonra sırasıyla İhlâs, Felak ve Nâs okunur (dört rekât tek selâmla). İki rekât kılınacaksa Fâtiha’dan sonra bu kısa sûreler okunur. Selâmdan sonra Allah’a hamd, Peygamber’e salavat getirilir ve ihtiyaç içtenlikle Allah’tan istenir.',
    howEn: 'After wudu, the minimum is 2 rakats. For four: 1st rakat Fatiha + Ayat al-Kursi ×3; 2nd-4th Fatiha + al-Ikhlas, al-Falaq, an-Nas (one salam). After salam, praise Allah, send salawat, then present your need.',
    niyetTr: '“Niyet ettim Allah rızası için hâcet namazı kılmaya.”',
    reciteTr: '1. rekât: Fâtiha + 3 kez Âyetü’l-kürsî; diğerlerinde Fâtiha + İhlâs/Felak/Nâs. Namazdan sonra hamd, salavat ve hâcet duası.',
  ),
  SpecialPrayer(
    key: 'sukur',
    nameTr: 'Şükür Namazı',
    nameEn: 'Prayer of Gratitude',
    icon: Icons.volunteer_activism_rounded,
    rakats: '2 rekât',
    whenTr: 'Beklenen bir nimete, hayra veya bir sıkıntıdan kurtuluşa kavuşulduğunda kılınır. Belirli bir vakti yoktur; mekruh vakitler dışında istenilen zaman kılınabilir.',
    whenEn: 'When one attains a blessing, good outcome, or relief from hardship. No fixed time, avoiding the three disliked times.',
    howTr: 'Diğer nafileler gibi 2 rekât kılınır. Her rekâtta Fâtiha’dan sonra bir sûre okunur; rükû ve secdelerle iki rekât tamamlanır, oturuşta tahiyyat-salli-bârik ve dua okunup selâm verilir. Namazdan sonra Allah’a hamd edilir, şükür duaları yapılır.',
    howEn: 'Prayed as 2 rakats like any voluntary prayer. Afterward, praise Allah and offer prayers of thanks.',
    niyetTr: '“Niyet ettim Allah rızası için şükür namazı kılmaya.”',
    reciteTr: 'Belirli bir sûre yoktur; kısa sûreler (İhlâs, Kevser) okunabilir. Namaz sonrası hamd ve şükür (Elhamdülillah, şükür duaları) tavsiye edilir.',
  ),
  SpecialPrayer(
    key: 'istihare',
    nameTr: 'İstihâre Namazı',
    nameEn: 'Istikhara (Guidance) Prayer',
    icon: Icons.explore_rounded,
    rakats: '2 rekât',
    whenTr: 'Yapmaya niyetlenilen bir iş/karar (evlilik, yolculuk, iş vb.) hakkında “hayırlı mı” diye Allah’tan hayır dilemek için kılınır. Mekruh vakitler dışında her zaman; özellikle yatsıdan sonra, uyumadan önce tavsiye edilir. Bir karara varılana kadar (genelde birkaç gün) tekrarlanabilir.',
    whenEn: 'When undecided about a permissible matter, to ask Allah for guidance. Any time except forbidden times, especially after Isha before sleeping; may be repeated for several days.',
    howTr: 'Normal nafile gibi 2 rekât kılınır. 1. rekâtta Fâtiha’dan sonra (tavsiyeye göre) Kâfirûn, 2. rekâtta İhlâs okunur. Selâmdan sonra eller açılarak salavat getirilir, ardından meşhur istihâre duası okunur ve niyet edilen iş Allah’a arz edilerek hayırlısı istenir. Sonuç çoğu kez içe doğan ferahlık/sıkıntı veya şartların oluşmasıyla anlaşılır (mutlaka rüya şart değildir).',
    howEn: 'Pray two rakats. First rakat Fatiha + al-Kafirun (recommended), second Fatiha + al-Ikhlas. After salam, send salawat, recite the well-known istikhara supplication, naming the matter and asking Allah for what is good.',
    niyetTr: '“Niyet ettim Allah rızası için istihâre namazı kılmaya.”',
    reciteTr: '1. rekât Fâtiha + Kâfirûn, 2. rekât Fâtiha + İhlâs (tavsiye). Selâmdan sonra salavat ve istihâre duası (“Allâhümme innî estehîruke bi-ilmik…”).',
  ),
  SpecialPrayer(
    key: 'tovbe',
    nameTr: 'Tövbe Namazı',
    nameEn: 'Prayer of Repentance',
    icon: Icons.spa_rounded,
    rakats: '2 rekât (bazı kaynaklarda 4’e kadar)',
    whenTr: 'Bir günah işledikten sonra, pişmanlık duyup tövbe etmek niyetiyle kılınır. Belirli bir vakti yoktur; mekruh vakitler dışında her zaman; günahtan hemen sonra kılınması müstehaptır.',
    whenEn: 'After committing a sin, with sincere regret and the intention to repent. Any time except the forbidden times; soon after the sin is recommended.',
    howTr: 'Güzelce abdest alınır, 2 rekât nafile kılınır. Her rekâtta Fâtiha ve bir sûre okunur; normal namaz gibi rükû ve secdeler yapılır, son oturuşta tahiyyat-salli-bârik-dua ile selâm verilir. Selâmdan sonra eller açılıp samimiyetle Allah’tan af dilenir, istiğfar edilir ve günaha bir daha dönmemeye azmedilir.',
    howEn: 'After wudu, pray 2 rakats like any prayer. Afterward, raise the hands, sincerely seek Allah’s forgiveness (istighfar), and resolve never to return to the sin.',
    niyetTr: '“Niyet ettim Allah rızası için tövbe (istiğfar) namazı kılmaya.”',
    reciteTr: 'Belirli bir sûre yoktur. Namaz sonrası bolca istiğfar (Estağfirullâhe’l-azîm) ve “Seyyidü’l-İstiğfar” duası tavsiye edilir.',
  ),
  SpecialPrayer(
    key: 'kusuf',
    nameTr: 'Küsûf ve Husûf (Tutulma) Namazı',
    nameEn: 'Solar / Lunar Eclipse Prayer',
    icon: Icons.dark_mode_rounded,
    rakats: '2 rekât',
    whenTr: 'Küsûf (güneş tutulması) namazı, güneş tutulmaya başladığı andan açılıncaya kadar; husûf (ay tutulması) namazı ise gece ay tutulduğunda açılıncaya kadar kılınır. Hanefî’de güneş tutulması namazı camide cemaatle, ay tutulması namazı evlerde tek tek kılınır. Kerâhet vakitleri hariçtir.',
    whenEn: 'From the moment the eclipse begins until it ends. In the Hanafi school, the solar eclipse prayer is in congregation at the mosque, the lunar one individually at home.',
    howTr: 'Hanefî’ye göre 2 rekât kılınır ve şeklen normal nafileye benzer: her rekâtta bir kıyam, bir rükû ve iki secde vardır. Her iki rekâtta Fâtiha ve uzunca bir sûre okunur; kıraat, rükû ve secdeler normalden uzun tutulur (Hanefî’de kıraat gizli yapılır). Selâmdan sonra tutulma açılıncaya kadar tövbe, istiğfar, dua ve zikirle meşgul olunur.',
    howEn: 'In the Hanafi school, 2 rakats with one ruku and two prostrations per rakat (unlike the Shafi‘i two-ruku form). Recitation and postures are prolonged. After the prayer, engage in supplication and remembrance until the eclipse passes.',
    niyetTr: '“Niyet ettim Allah rızası için küsûf (güneş tutulması) namazını kılmaya.” (Ay tutulmasında: “…husûf namazını…”.)',
    reciteTr: 'Fâtiha’dan sonra uzun sûreler okunması tavsiye edilir; belirli bir sûre şartı yoktur, kıraatin uzun tutulması esastır. Namaz sonrası tövbe-istiğfar, dua, tekbir, sadaka ve zikir müstehaptır.',
  ),
  SpecialPrayer(
    key: 'istiska',
    nameTr: 'Yağmur Duası (İstiskâ) Namazı',
    nameEn: 'Rain Prayer (Salat al-Istisqa)',
    icon: Icons.water_drop_rounded,
    rakats: '2 rekât (cemaatle)',
    whenTr: 'Kuraklık ve su kıtlığı zamanlarında, yağmur için topluca kılınır. Genellikle yerleşim yeri dışında açık bir alana çıkılarak, kerâhet vakitleri dışında kılınır. Üç gün peş peşe çıkıp dua etmek müstehaptır.',
    whenEn: 'In times of drought, prayed congregationally to ask Allah for rain, typically in an open area outside town. It is recommended to go out three days in a row.',
    howTr: 'Ezan ve kamet okunmadan, cemaatle 2 rekât kılınır (sesli okunur). Diğer iki rekâtlık namazlar gibi kılınır. Namazdan sonra imam ayağa kalkıp hutbe okur, kıbleye dönüp ellerini kaldırarak dua eder; cemaat de elleri açık “âmin” der. Bol istiğfar ve tövbe edilir. (İmam Ebû Hanîfe’ye göre asıl olan dua ve istiğfardır; Diyanet İlmihali uygulamada 2 rekât olarak bildirir.)',
    howEn: 'Prayed as 2 rakats in congregation, aloud, without adhan or iqamah. Afterwards the imam delivers a sermon, then faces the qibla and supplicates while the congregation says “amin.” Much istighfar and repentance is made.',
    niyetTr: '“Niyet ettim Allah rızası için yağmur duası (istiskâ) namazını kılmaya.”',
    reciteTr: 'Belirli zorunlu bir sûre yoktur; Fâtiha’dan sonra bilinen sûreler okunur. Namaz sonrası bol istiğfar ve tövbe esastır; açık alanda kıbleye dönülüp topluca yağmur duası yapılır.',
  ),
  SpecialPrayer(
    key: 'teveccuh',
    nameTr: 'Teveccüh Namazı',
    nameEn: 'Tawajjuh (note)',
    icon: Icons.info_outline_rounded,
    rakats: 'Ana akımda sabit bir rekât sayısı YOKTUR',
    whenTr: 'Diyanet/Hanefî ilmihalinde “Teveccüh Namazı” diye belirli vakti olan müstakil bir namaz tanımlanmamıştır.',
    whenEn: 'Mainstream Hanafi/Diyanet jurisprudence does not define a distinct prayer called “Tawajjuh Prayer.”',
    howTr: 'Ana akımda bu isimle standart bir kılınış tarifi bulunmaz; bu yüzden sabit bir rekât/okuyuş şeması verilemez. Allah’a yönelmek isteyen kişi, yeri kesin olan nafilelere yönelmelidir: Hâcet Namazı (2 veya 4 rekât) ya da Teheccüd (gece, 2-8 rekât). Bu nafilelerde her rekâtta Fâtiha + bir sûre okunur, ardından dua edilir.',
    howEn: 'No standard ritual format exists under this name. Those seeking to turn to Allah should instead perform recognized voluntary prayers: Hajah (2 or 4 rakats) or Tahajjud (night, 2-8 rakats).',
    niyetTr: 'Ana akımda “teveccüh namazı” niyeti yoktur. Yerine: “Niyet ettim Allah rızası için hâcet namazı kılmaya” veya “…teheccüd namazı…” denir.',
    reciteTr: 'Bu isimle tavsiye edilen sabit bir sûre/tesbih yoktur. Yerine kılınacak hâcet/teheccüd namazında Fâtiha ardından kısa bir sûre okunur; selâmdan sonra salavat ve serbest dua edilir.',
    mainstream: false,
    warningTr: 'DİKKAT: “Teveccüh Namazı” Diyanet İlmihali / ana akım Hanefî fıkhında müstakil bir namaz olarak YER ALMAZ. “Teveccüh” terimi esas olarak tasavvufta (özellikle Nakşibendî-Hâlidî geleneğinde) müridin şeyhe yönelmesi/rabıta uygulamasının adıdır ve bir namaz değildir. İnternette çoğu kez “teheccüd namazı” ile karıştırılır. Allah’a yönelme amacı taşıyana, yeri kesin olan Hâcet veya Teheccüd namazı tavsiye edilir.',
  ),
];
