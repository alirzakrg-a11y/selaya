import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'app.dart';
import 'core/di/providers.dart';
import 'features/notifications/domain/prayer_notification_settings.dart';
import 'features/audio_stories/data/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting();
  // Load the IANA timezone database up front so prayer-time computation can
  // resolve each city's own UTC offset (otherwise times would fall back to the
  // device timezone — wrong for any city in a different zone).
  tzdata.initializeTimeZones();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Attribution for the bundled CC BY-SA 4.0 adhan (shown on the app's licence
  // page, satisfying the licence's attribution requirement).
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — audio'],
      'The Adhan – Muslim Call to Prayer (file: adhan_commons).\n'
      'Reciter: Aaqib Azeez. Uploaded by: Atcovi. Source: Wikimedia Commons '
      '(commons.wikimedia.org/wiki/File:The_Adhan_-_Muslim_Call_to_Prayer.mp3).\n'
      'Licence: Creative Commons Attribution-ShareAlike 4.0 International '
      '(CC BY-SA 4.0) — creativecommons.org/licenses/by-sa/4.0/. Used unmodified.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — audio'],
      'Adhan, Great Mosque of Mecca - Jan 21, 2013 (file: adhan_mecca_full).\n'
      'Source: Wikimedia Commons (commons.wikimedia.org/wiki/'
      'File:Adhan,_Great_Mosque_of_Mecca_-_Jan_21,_2013.webm).\n'
      'Licence: Creative Commons Attribution 3.0 (CC BY 3.0) — '
      'creativecommons.org/licenses/by/3.0/. '
      'Modified: audio extracted, converted to MP3, loudness-normalised.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — audio'],
      'Maghrib Adhan at the Masjid al Haram, Mecca - 25 Feb, 2012 '
      '(file: adhan_mecca_maghrib).\n'
      'Source: Wikimedia Commons (commons.wikimedia.org/wiki/'
      'File:Maghrib_Adhan_at_the_Masjid_al_Haram,_Mecca_-_25_Feb,_2012.webm).\n'
      'Licence: Creative Commons Attribution 3.0 (CC BY 3.0) — '
      'creativecommons.org/licenses/by/3.0/. '
      'Modified: audio extracted, converted to MP3, loudness-normalised.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — audio'],
      'Adhan, Great Mosque of Mecca — short 25 s excerpt (file: adhan_mecca_short).\n'
      'Trimmed from adhan_mecca_full (same Wikimedia Commons source).\n'
      'Licence: Creative Commons Attribution 3.0 (CC BY 3.0) — '
      'creativecommons.org/licenses/by/3.0/. '
      'Modified: trimmed to 25 s, fade-out, loudness-normalised.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — images'],
      'Quran page images — Madani Mushaf script by King Fahd Glorious Quran '
      'Printing Complex (KFGQPC).\n'
      'Page image set: Five-Prayers/quran-pages (github.com/Five-Prayers/'
      'quran-pages), served via jsDelivr CDN. Used unmodified, page by page.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — audio'],
      'Llamada a oración Mezquita Hassan II (file: adhan_hassan2_full).\n'
      'Source: Wikimedia Commons (commons.wikimedia.org/wiki/'
      'File:Llamada_a_oracion_Mezquita_Hassan_II.wav).\n'
      'Licence: Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0) — '
      'creativecommons.org/licenses/by-sa/4.0/. '
      'Modified: converted to MP3, loudness-normalised.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['SELAYA — Quran translations'],
      'Quran translations (meal) sourced from Tanzil.net via the AlQuran.cloud '
      'API, used unmodified:\n'
      '• German — Bubenheim & Elyas\n'
      '• French — Muhammad Hamidullah\n'
      '• Indonesian — Ministry of Religious Affairs (Kemenag)\n'
      '• Urdu — Fateh Muhammad Jalandhry\n'
      '• Bengali — Muhiuddin Khan\n'
      '• Persian — Makarem Shirazi\n'
      '• Russian — Elmir Kuliev\n'
      'Sources: tanzil.net, alquran.cloud.',
    );
  });

  final prefs = await SharedPreferences.getInstance();
  // Bildirim titreşim tercihini kanallar kurulmadan ÖNCE yükle (kanal id'sine
  // yansıdığından doğru kanalın oluşması için gerekli).
  prayerVibration = prefs.getBool(PrefKeys.notifVibration) ?? true;

  // Arka plan ses oynatma + medya bildirimi (audio_service) — sesli hikâyeler
  // için. Init başarısız olursa app açılışı bloke olmasın diye sarıldı; o durumda
  // yalnızca arka plan bildirimi gider, oynatma değil.
  AppAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => AppAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.selaya.app.media',
        androidNotificationChannelName: 'SELAYA Medya',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e, s) {
    audioServiceError = '$e\n$s'.split('\n').take(4).join('\n');
    audioHandler = AppAudioHandler();
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: EasyLocalization(
        // 10 dil. RTL: ar/ur/fa (Flutter otomatik Directionality uygular,
        // emülatörde Arapça doğrulandı). LTR: tr/en/de/id/fr/bn/ru.
        supportedLocales: const [
          Locale('tr'), Locale('en'), Locale('ar'),
          Locale('de'), Locale('id'), Locale('fr'),
          Locale('ur'), Locale('bn'), Locale('fa'), Locale('ru'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr'),
        startLocale: const Locale('tr'),
        useOnlyLangCode: true,
        child: const SelayaApp(),
      ),
    ),
  );
}
