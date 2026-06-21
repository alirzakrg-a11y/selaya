// Zekât & fitre özet rehberi — Diyanet İşleri Başkanlığı İlmihali çizgisinde.

class ZakatInfoItem {
  final String titleTr, titleEn;
  final String descTr, descEn;
  const ZakatInfoItem(this.titleTr, this.titleEn, this.descTr, this.descEn);
  String title(String l) => l == 'tr' ? titleTr : titleEn;
  String desc(String l) => l == 'tr' ? descTr : descEn;
}

const zakatInfo = <ZakatInfoItem>[
  ZakatInfoItem(
    'Kimlere farzdır?',
    'Who must pay?',
    'Akıllı, ergin, hür ve Müslüman olup, temel ihtiyaçları dışında nisap miktarı (80,18 gr altın veya 561 gr gümüş değeri) mala sahip olan ve bu malın üzerinden bir kamerî yıl geçen kişiye farzdır.',
    'A sane, adult, free Muslim who owns, beyond basic needs, the nisab (about 80.18g of gold) and has held it for one lunar year.',
  ),
  ZakatInfoItem(
    'Hangi mallardan?',
    'On which wealth?',
    'Altın, gümüş ve para; ticaret malları; toprak ürünleri (öşür) ve belli sayıya ulaşan hayvanlar (deve, sığır, koyun) zekâta tâbidir.',
    'Gold, silver and money; trade goods; agricultural produce (ushr); and livestock above set counts.',
  ),
  ZakatInfoItem(
    'Oran nedir?',
    'How much?',
    'Altın, gümüş, para ve ticaret mallarında kırkta bir, yani yüzde iki buçuktur (%2,5).',
    'On gold, silver, money and trade goods it is one-fortieth, i.e. 2.5%.',
  ),
  ZakatInfoItem(
    'Kimlere verilir?',
    'Who receives it?',
    'Kur’an’da sayılan sekiz sınıfa: fakirler, düşkünler, borçlular, yolda kalmışlar ve diğerleri. Bir fakire verilebileceği gibi birçok fakire de dağıtılabilir.',
    'The eight categories named in the Qur’an: the poor, the needy, debtors, the stranded, and others.',
  ),
  ZakatInfoItem(
    'Kimlere verilmez?',
    'Who cannot receive it?',
    'Kişinin ana-babası, çocuk ve torunları ile eşine; zengine ve gayrimüslime zekât verilmez.',
    'One’s parents, children/grandchildren and spouse; the wealthy; and non-Muslims cannot be given one’s zakat.',
  ),
  ZakatInfoItem(
    'Fitre (fıtır sadakası)',
    'Fitra',
    'Ramazan Bayramı’ndan önce, nisaba sahip her Müslümanın kendisi ve bakmakla yükümlü olduğu kişiler için verdiği sadakadır. Bayram namazından önce verilmesi efdaldir.',
    'Charity given before Eid al-Fitr by every Muslim who owns the nisab, for themselves and dependents; best given before the Eid prayer.',
  ),
];
