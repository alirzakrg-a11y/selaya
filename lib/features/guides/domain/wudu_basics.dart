import 'basic_item.dart';

/// Abdestin temelleri — farzları, sünnetleri, bozan şeyler. İçerik Diyanet
/// İlmihali (Hanefî) esas alınarak hazırlanmıştır; ayrıntı için yetkili
/// kaynaklara başvurulmalıdır.

/// Abdestin farzları (4) — Mâide sûresi 6. âyete dayanır.
const abdestFarzlari = <BasicItem>[
  BasicItem(
      'Yüzü yıkamak',
      'Washing the face',
      'Alın saç bitiminden çene altına, iki kulak yumuşağı arasını bir kez yıkamak.',
      'Washing the whole face once, from the hairline to under the chin and ear to ear.'),
  BasicItem(
      'Kolları yıkamak',
      'Washing the arms',
      'Parmak uçlarından dirsekler de dâhil olmak üzere yıkamak.',
      'Washing the arms up to and including the elbows.'),
  BasicItem(
      'Başı meshetmek',
      'Wiping the head',
      'Başın en az dörtte birini ıslak elle bir kez meshetmek.',
      'Wiping at least a quarter of the head once with a wet hand.'),
  BasicItem(
      'Ayakları yıkamak',
      'Washing the feet',
      'Parmak aralarıyla birlikte, topuklar da dâhil yıkamak.',
      'Washing the feet including between the toes and the heels.'),
];

/// Abdestin başlıca sünnetleri.
const abdestSunnetleri = <BasicItem>[
  BasicItem('Niyet etmek', 'Making the intention',
      'Abdest almaya kalben niyet etmek.', 'Intending in the heart to perform wudu.'),
  BasicItem('Besmele', 'Saying Bismillah',
      '“Bismillâh” diyerek başlamak.', 'Beginning with “Bismillāh”.'),
  BasicItem('Elleri yıkamak', 'Washing the hands',
      'Bileklere kadar elleri üç kez yıkamak.', 'Washing the hands up to the wrists three times.'),
  BasicItem('Misvak / diş temizliği', 'Using the miswak',
      'Misvak kullanmak veya dişleri temizlemek.', 'Using the miswak or cleaning the teeth.'),
  BasicItem('Mazmaza ve istinşak', 'Rinsing mouth and nose',
      'Ağza üç kez su alıp çalkalamak, buruna üç kez su çekmek.',
      'Rinsing the mouth and drawing water into the nose, three times each.'),
  BasicItem('Üçer kez yıkamak', 'Washing three times',
      'Yıkanan her uzvu üçer kez yıkamak.', 'Washing each washed limb three times.'),
  BasicItem('Hilallemek', 'Running through',
      'El ve ayak parmaklarını, sakalı hilallemek.', 'Running fingers between the toes/fingers and through the beard.'),
  BasicItem('Tertip ve muvâlât', 'Order & continuity',
      'Uzuvları âyetteki sırayla ve ara vermeden yıkamak; başın tamamını, kulakları ve boynu meshetmek.',
      'Washing in the Quranic order without pause; wiping the whole head, ears and neck.'),
];

/// Abdesti bozan başlıca şeyler.
const abdestiBozanlar = <BasicItem>[
  BasicItem('Ön/arkadan çıkanlar', 'Discharge',
      'Önden veya arkadan idrar, gâita ya da yel çıkması.', 'Urine, stool or wind passing from the front or back.'),
  BasicItem('Kan, irin akması', 'Flowing blood or pus',
      'Vücuttan kan, irin veya sarı suyun çıktığı yeri aşacak şekilde akması.',
      'Blood, pus or fluid flowing beyond the point of exit.'),
  BasicItem('Ağız dolusu kusmak', 'Mouthful of vomit',
      'Ağız dolusu kusmak.', 'Vomiting a mouthful.'),
  BasicItem('Aklın gitmesi', 'Loss of consciousness',
      'Bayılma, sarhoşluk veya aklı örten bir hâl.', 'Fainting, intoxication or anything that veils the mind.'),
  BasicItem('Uyumak', 'Sleeping',
      'Yatarak veya bir yere dayanarak uyumak.', 'Sleeping lying down or leaning against something.'),
  BasicItem('Namazda kahkaha', 'Laughing in prayer',
      'Namaz içinde sesli (kahkaha) gülmek; hem namazı hem abdesti bozar.',
      'Laughing aloud during prayer breaks both the prayer and the wudu.'),
];
