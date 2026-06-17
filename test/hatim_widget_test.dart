import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selaya/core/di/providers.dart';
import 'package:selaya/features/audio_stories/data/audio_handler.dart';
import 'package:selaya/features/hatim/domain/hatim_session.dart';
import 'package:selaya/features/hatim/presentation/hatim_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(SharedPreferences prefs) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Ses katmanına dokunan provider'lar için güvenli varsayılan. (Mini
        // çalarlar artık SelayaScaffold'da değil, app.dart'taki global
        // overlay'de — bu test ağacında hiç mount edilmezler.)
        audioHandlerProvider.overrideWithValue(AppAudioHandler()),
      ],
      child: MaterialApp(
        // 'en' → DefaultMaterialLocalizations destekler (AppBar gereği).
        // easy_localization asset yüklü olmadığından .tr() anahtarı döndürür
        // (çökmez); yapısal kontroller (ikon/düğme/ilerleme) bundan bağımsız.
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        home: const HatimScreen(),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    // Gerçek uygulamada main() başlatır; ilerleme ekranı formatGregorian (intl)
    // kullandığından testte de gerekli.
    await initializeDateFormatting('en');
  });

  testWidgets('Boş durum ekranı ÇÖKMEDEN çizilir + başlat düğmesi var',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_app(prefs));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull); // render hatası YOK
    // Boş durumun büyük kitap ikonu + bir FilledButton (Hatim Başlat).
    expect(find.byIcon(Icons.auto_stories_rounded), findsWidgets);
    expect(find.byType(FilledButton), findsWidgets);
  });

  testWidgets('Aktif hatim → ilerleme ekranı (dairesel + günlük çubuk) çizilir',
      (tester) async {
    final session = HatimSession(
      id: 'h1',
      startDate: DateTime.now(),
      startPage: 1,
      dailyTarget: 20,
      currentPage: 150,
      readPagesByDay: {
        hatimDateKey(DateTime.now()): [148, 149, 150],
      },
    );
    final data = HatimData(active: session);
    SharedPreferences.setMockInitialValues(
        {PrefKeys.hatimState: data.encode()});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // Büyük dairesel ilerleme + bugünkü hedef çubuğu.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // "Okumaya Devam Et" + "Sayfa Ekle" + "Vazgeç" düğmeleri.
    expect(find.byType(FilledButton), findsWidgets);
    expect(find.byType(OutlinedButton), findsWidgets);
  });

  testWidgets('Başlat akışı: düğmeye basınca başlatma sheet açılır',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_app(prefs));
    await tester.pump(const Duration(milliseconds: 300));

    // Boş durumdaki başlat düğmesine bas.
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump(); // sheet animasyonu başlasın
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // Sheet'te mod seçimi (SegmentedButton) + günlük hedef çipleri (ChoiceChip).
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('Tamamlanan hatim → kutlama görünümü çizilir (çökmeden)',
      (tester) async {
    final session = HatimSession(
      id: 'hC',
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      startPage: 1,
      dailyTarget: 20,
      currentPage: 604,
      completedDate: DateTime.now(),
      status: HatimStatus.completed,
    );
    SharedPreferences.setMockInitialValues(
        {PrefKeys.hatimState: HatimData(active: session).encode()});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // Kutlama: doğrulama ikonu + paylaş düğmesi.
    expect(find.byIcon(Icons.verified_rounded), findsWidgets);
  });
}
