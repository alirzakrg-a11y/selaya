/// Dini gün/gece bilgileri — anlamı + tavsiye edilen ibadetler. İçerik Diyanet
/// İşleri Başkanlığı çizgisinde, Sünnî anlayışa göre hazırlanmıştır. Kandil
/// gecelerine bağlanan belirli ibadet biçimleri Hz. Peygamber'den nakledilen
/// kesin uygulamalar değil; bu mübarek vakitleri ibadetle değerlendirme
/// tavsiyesidir.
class DayInfo {
  final String significanceTr, significanceEn;
  final String amelTr, amelEn; // tavsiye edilen ibadetler
  const DayInfo(
      this.significanceTr, this.significanceEn, this.amelTr, this.amelEn);
  String significance(String l) => l == 'tr' ? significanceTr : significanceEn;
  String amel(String l) => l == 'tr' ? amelTr : amelEn;
}

/// CalendarDay.id → bilgi anahtarı (slug). religious_days.dart kimlik biçimi
/// ("kandil_7_27_1448", "kandil_regaib_1448" vb.).
String religiousDaySlug(String id) {
  if (id.startsWith('new_year_')) return 'new_year';
  if (id.startsWith('fast_1_10_')) return 'asure';
  if (id.startsWith('kandil_3_12_')) return 'mevlid';
  if (id.startsWith('kandil_regaib_')) return 'regaib';
  if (id.startsWith('kandil_7_27_')) return 'mirac';
  if (id.startsWith('kandil_8_15_')) return 'berat';
  if (id.startsWith('fast_9_1_')) return 'ramazan_start';
  if (id.startsWith('kandil_9_27_')) return 'kadir';
  if (id.startsWith('holiday_10_')) return 'fitr';
  if (id.startsWith('fast_fitr_eve_')) return 'fitr_eve';
  if (id.startsWith('fast_12_9_')) return 'arefe';
  if (id.startsWith('holiday_12_')) return 'adha';
  return '';
}

const Map<String, DayInfo> religiousDayInfo = {
  'new_year': DayInfo(
    'Hicrî takvimin ilk günüdür (1 Muharrem). Takvim, Hz. Peygamber\'in Mekke\'den Medine\'ye hicretini başlangıç kabul eder.',
    'The first day of the Hijri calendar (1 Muharram), which begins with the Prophet\'s migration (hijrah) from Mecca to Medina.',
    'Geçen yılın muhasebesi yapılır; yeni yıl için dua ve hayırlı niyetlerde bulunulur, nâfile ibadet ve sadaka tavsiye edilir.',
    'Reflect on the past year; make du\'a and good intentions for the new one, with extra voluntary worship and charity.',
  ),
  'asure': DayInfo(
    'Muharrem ayının 10. günüdür. Hz. Peygamber bu günde oruç tutmuş ve tutulmasını tavsiye etmiştir; tarihte birçok önemli olayın bu güne denk geldiği rivayet edilir.',
    'The 10th day of Muharram. The Prophet fasted on this day and recommended fasting it; many significant events are reported to have occurred on it.',
    'Âşûre günü oruç tutmak müstehaptır; sırf bu güne mahsus kalmaması için bir gün öncesi (Tâsûâ) veya sonrasıyla birlikte tutulması tavsiye edilir. Sadaka ve ikram güzeldir.',
    'Fasting on Ashura is recommended; pairing it with the day before (Tasua) or after is encouraged. Giving charity and sharing food are praiseworthy.',
  ),
  'mevlid': DayInfo(
    'Hz. Muhammed (s.a.v.)\'in dünyaya teşrif ettiği gecedir (12 Rebîülevvel).',
    'The night of the birth of the Prophet Muhammad (peace be upon him), on 12 Rabi\' al-Awwal.',
    'Bol bol salavât getirilir, Peygamberimizin hayatı (siyer) ve ahlâkı okunur; Kur\'an, dua ve şükürle gece değerlendirilir.',
    'Send abundant salawat, read about the Prophet\'s life and character, and spend the night in Qur\'an, du\'a and gratitude.',
  ),
  'regaib': DayInfo(
    'Üç ayların (Recep-Şâban-Ramazan) ilk kandilidir; Recep ayının ilk Cuma gecesidir. Rahmet ve rağbet gecesi olarak değerlendirilir.',
    'The first of the holy nights of the three sacred months (Rajab–Sha\'ban–Ramadan), on the first Friday eve of Rajab.',
    'Tövbe-istiğfar, kazâ ve nâfile namaz, Kur\'an tilâveti ve dua ile gece ihyâ edilir.',
    'Spend the night in repentance, making up or voluntary prayers, recitation of the Qur\'an and supplication.',
  ),
  'mirac': DayInfo(
    'Hz. Peygamber\'in Mescid-i Harâm\'dan Mescid-i Aksâ\'ya (İsrâ), oradan göklere yükseltildiği (Mîrâc) gecedir (27 Recep). Beş vakit namaz bu gecede farz kılınmıştır.',
    'The night of the Prophet\'s journey from the Sacred Mosque to al-Aqsa (Isra) and his ascension (Mi\'raj), on 27 Rajab. The five daily prayers were made obligatory on this night.',
    'Namaz, Kur\'an, dua ve tövbe ile gece değerlendirilir; bol salavât getirilir. Namazın kıymeti hatırlanır.',
    'Spend the night in prayer, Qur\'an, du\'a and repentance; send abundant salawat and reflect on the value of salah.',
  ),
  'berat': DayInfo(
    'Şâban ayının 15. gecesidir; af, mağfiret ve berât (kurtuluş) gecesi olarak bilinir.',
    'The 15th night of Sha\'ban, known as the night of forgiveness and acquittal (bara\'at).',
    'Tövbe-istiğfar, dua, Kur\'an ve nâfile namazla gece ihyâ edilir; helalleşmek, küslükleri gidermek ve sadaka tavsiye edilir.',
    'Spend it in repentance, du\'a, Qur\'an and voluntary prayer; reconcile with others, mend ties, and give charity.',
  ),
  'ramazan_start': DayInfo(
    'On bir ayın sultanı Ramazan\'ın ilk günüdür; Kur\'an bu ayda indirilmeye başlanmış, oruç bu ayda farz kılınmıştır.',
    'The first day of Ramadan, the month in which the Qur\'an began to be revealed and fasting was made obligatory.',
    'Oruç tutulur (farz), terâvih namazı kılınır, Kur\'an okumaya ağırlık verilir; sadaka, infak ve iftar ikramı artırılır.',
    'Keep the obligatory fast, pray Tarawih, increase Qur\'an recitation, and give generously in charity and iftar.',
  ),
  'kadir': DayInfo(
    'Kur\'an-ı Kerîm\'in indirilmeye başlandığı, bin aydan hayırlı gecedir (Kadir sûresi). Çoğunlukla Ramazan\'ın 27. gecesi idrak edilir; ancak Hz. Peygamber bu geceyi Ramazan\'ın son on gününün tek gecelerinde aramayı tavsiye etmiştir.',
    'The Night of Decree, better than a thousand months, on which the Qur\'an began to be revealed. It is commonly observed on the 27th night of Ramadan, though the Prophet advised seeking it in the odd nights of the last ten days.',
    'Namaz, Kur\'an, zikir, dua ve tövbe ile gece ihyâ edilir. "Allâhümme inneke afüvvün tühibbü\'l-afve fa\'fü annî" duası çokça okunur.',
    'Spend the night in prayer, Qur\'an, dhikr, du\'a and repentance; recite often: "O Allah, You are Most Forgiving and love forgiveness, so forgive me."',
  ),
  'fitr': DayInfo(
    'Bir aylık orucun ardından gelen şükür ve sevinç bayramıdır (1 Şevval).',
    'The festival of gratitude and joy after a month of fasting, on 1 Shawwal.',
    'Bayram namazı kılınır; fıtır sadakası (fitre) bayram namazından önce verilir; akraba ve dostlar ziyaret edilir, küskünler barıştırılır.',
    'Pray the Eid prayer; give the fitrah charity before it; visit family and friends and reconcile with others.',
  ),
  'fitr_eve': DayInfo(
    'Ramazan ayının son günü ve Ramazan Bayramı\'nın arifesidir.',
    'The last day of Ramadan and the eve of Eid al-Fitr.',
    'Orucun son günü değerlendirilir; fıtır sadakası (fitre) hazırlanıp bayram namazından önce verilmesi sağlanır; bayram hazırlığı yapılır.',
    'Make the most of the final fast; prepare the fitrah charity to be given before the Eid prayer.',
  ),
  'arefe': DayInfo(
    'Kurban Bayramı\'ndan bir önceki gündür (9 Zilhicce); hacıların Arafat\'ta vakfeye durduğu, duaların kabul olduğu mübarek gündür.',
    'The day before Eid al-Adha (9 Dhul-Hijjah), when pilgrims stand at Arafat; a blessed day on which prayers are answered.',
    'Hacı olmayanların oruç tutması müstehaptır; teşrik tekbirleri Arefe günü sabah namazından itibaren getirilir; dua ve istiğfar çoğaltılır.',
    'Fasting is recommended for non-pilgrims; the takbir at-tashriq begins from the Fajr of Arafah; increase du\'a and seeking forgiveness.',
  ),
  'adha': DayInfo(
    'Hz. İbrahim\'in teslimiyetini anan, kurban ibadetinin yerine getirildiği bayramdır (10 Zilhicce; dört gün sürer).',
    'The festival commemorating Prophet Ibrahim\'s submission, when the qurbani (sacrifice) is offered (10 Dhul-Hijjah; lasts four days).',
    'Bayram namazı kılınır, kurban kesilir, teşrik tekbirleri getirilir; et üç parçaya bölünüp ihtiyaç sahipleriyle paylaşılır, akrabalar ziyaret edilir.',
    'Pray the Eid prayer, offer the sacrifice, recite the takbir at-tashriq; share the meat with those in need and visit relatives.',
  ),
};
