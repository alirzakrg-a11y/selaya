import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/prayer_times/data/prayer_repository.dart';
import '../../features/prayer_times/domain/prayer.dart';
import '../../features/settings/presentation/settings_controller.dart';
import '../data/content_providers.dart';
import '../utils/formatters.dart';
import 'widget_service.dart';

/// Famous standalone verses shown by the home-screen ayah widget (tap = next).
const _widgetAyahs = <Map<String, String>>[
  {
    'ar': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    'tr': "Rahmân ve Rahîm olan Allah'ın adıyla.",
    'en': 'In the name of Allah, the Most Gracious, the Most Merciful.',
    'rf_tr': 'Fâtiha 1',
    'rf_en': 'Al-Fatiha 1',
  },
  {
    'ar': 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'tr': 'Muhakkak ki, zorlukla beraber bir kolaylık vardır.',
    'en': 'Indeed, with hardship comes ease.',
    'rf_tr': 'İnşirah 6',
    'rf_en': 'Ash-Sharh 6',
  },
  {
    'ar': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    'tr': 'Bilesiniz ki kalpler ancak Allah’ı anmakla huzur bulur.',
    'en': 'Verily, in the remembrance of Allah do hearts find rest.',
    'rf_tr': 'Ra’d 28',
    'rf_en': "Ar-Ra'd 28",
  },
  {
    'ar': 'فَاذْكُرُونِي أَذْكُرْكُمْ',
    'tr': 'Öyleyse yalnız beni anın ki ben de sizi anayım.',
    'en': 'So remember Me; I will remember you.',
    'rf_tr': 'Bakara 152',
    'rf_en': 'Al-Baqara 152',
  },
  {
    'ar': 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    'tr': 'Kim Allah’a tevekkül ederse, O ona yeter.',
    'en': 'And whoever relies upon Allah — then He is sufficient for him.',
    'rf_tr': 'Talâk 3',
    'rf_en': 'At-Talaq 3',
  },
  {
    'ar': 'ادْعُونِي أَسْتَجِبْ لَكُمْ',
    'tr': 'Bana dua edin, size karşılık vereyim.',
    'en': 'Call upon Me; I will respond to you.',
    'rf_tr': 'Mü’min 60',
    'rf_en': 'Ghafir 60',
  },
  {
    'ar': 'قُلْ هُوَ اللَّهُ أَحَدٌ',
    'tr': 'De ki: O, Allah’tır, bir tektir.',
    'en': 'Say: He is Allah, the One.',
    'rf_tr': 'İhlâs 1',
    'rf_en': 'Al-Ikhlas 1',
  },
  {
    'ar': 'وَلَلْآخِرَةُ خَيْرٌ لَّكَ مِنَ الْأُولَىٰ',
    'tr': 'Elbette ahiret senin için dünyadan daha hayırlıdır.',
    'en': 'And the Hereafter is better for you than the first life.',
    'rf_tr': 'Duhâ 4',
    'rf_en': 'Ad-Duha 4',
  },
];

/// Builds and pushes data for every SELAYA home-screen widget in one call.
/// Safe to call on launch/resume; individual sections fail silently.
Future<void> pushHomeWidgets(WidgetRef ref, String lang) async {
  final data = <String, String>{};
  final en = lang == 'en';

  // Prayer times widget.
  try {
    final v = await ref.read(prayerViewProvider.future);
    final city = await ref.read(selectedCityProvider.future);
    final nextName = v.nextSlot.labelKey.tr();
    data['prayer_city'] = city.name(lang);
    data['prayer_next'] = '$nextName ${formatClock(v.nextTime)}';
    data['prayer_next_name'] = nextName;
    // Epoch (ms) of the next prayer — drives the prayer clock widget's live
    // count-down Chronometer (#15). Labels are pre-localized here (native side
    // has no i18n).
    data['prayer_next_epoch'] = v.nextTime.millisecondsSinceEpoch.toString();
    data['prayer_next_label'] =
        '${en ? 'Next' : 'Sıradaki'}: $nextName ${formatClock(v.nextTime)}';
    data['prayer_remaining_label'] = en ? 'Left ' : 'Kalan ';
    data['prayer_times'] = jsonEncode([
      for (final s in PrayerSlot.values)
        {'n': s.labelKey.tr(), 't': formatClock(v.today.timeOf(s))}
    ]);
  } catch (_) {}

  // Daily-ayah widget (curated rotation).
  data['ayah_list'] = jsonEncode([
    for (final a in _widgetAyahs)
      {'ar': a['ar'], 'mn': en ? a['en'] : a['tr'], 'rf': en ? a['rf_en'] : a['rf_tr']}
  ]);

  // Esmaül Hüsna widget (full list rotation).
  try {
    final asma = await ref.read(asmaProvider.future);
    if (asma.isNotEmpty) {
      data['esma_list'] = jsonEncode([
        for (final a in asma)
          {'ar': a.arabic, 'tr': a.transliteration, 'mn': a.meaning(lang)}
      ]);
    }
  } catch (_) {}

  // Hijri-date widget.
  try {
    final now = DateTime.now();
    final s = ref.read(settingsProvider);
    data['hijri_date'] = formatHijri(now, lang, offsetDays: s.hijriOffsetDays);
    data['hijri_greg'] = formatGregorian(now, lang);
  } catch (_) {}

  if (data.isNotEmpty) await ref.read(widgetServiceProvider).update(data);
}
