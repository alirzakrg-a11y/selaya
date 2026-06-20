/// Rehberlerdeki "temel" maddeler için ortak veri tipi (başlık + kısa açıklama,
/// çift dilli). Namaz/Abdest gibi rehberlerin açılır bölümlerinde kullanılır.
class BasicItem {
  final String titleTr, titleEn;
  final String descTr, descEn;
  const BasicItem(this.titleTr, this.titleEn, this.descTr, this.descEn);
  String title(String l) => l == 'tr' ? titleTr : titleEn;
  String desc(String l) => l == 'tr' ? descTr : descEn;
}
