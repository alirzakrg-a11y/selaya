/// All route paths in one place.
abstract final class Routes {
  static const splash = '/splash';
  static const intro = '/intro';
  static const onboarding = '/onboarding';

  // Shell branches
  static const home = '/home';
  static const times = '/times';
  static const quran = '/quran';
  static const qibla = '/qibla';
  static const more = '/more';

  // Üyelik (auth)
  static const auth = '/auth'; // giriş + üye ol (tek ekran, mod geçişli)
  static const account = '/account'; // Hesabım
  static const liked = '/liked'; // Beğendiklerim (beğenilen içerikler)

  // Pushed above the shell (full screen)
  static const quranReader = '/quran-reader'; // /:surah
  static const mushaf = '/mushaf'; // sayfa sayfa gerçek mushaf (extra: int? başlangıç sayfası)
  static const story = '/story'; // /:index
  static const dhikr = '/dhikr';
  static const asma = '/asma';
  static const verses = '/verses';
  static const hadiths = '/hadiths';
  static const duas = '/duas';
  static const calendar = '/calendar';
  static const tracking = '/tracking';
  static const wallpapers = '/wallpapers';
  static const ai = '/ai';
  static const mosques = '/mosques';
  static const feed = '/feed'; // reels (video) — reached from Akış & More
  static const akis = '/akis'; // content stream tab (#19)
  static const settings = '/settings';
  static const premium = '/premium';
  static const citySelect = '/city-select';
  static const notificationSettings = '/notification-settings';
  static const audioStories = '/audio-stories';
  static const fasting = '/fasting';
  static const ramadan = '/ramadan'; // Ramazan Modu (sahur/iftar + mukabele)
  static const greetings = '/greetings';
  static const yasin = '/yasin';
  static const kaza = '/kaza';
  static const tesbihat = '/tesbihat'; // namaz sonrası tesbihat sayacı
  static const zakat = '/zakat'; // zekât & fitre hesaplayıcı
  static const babyNames = '/baby-names'; // İslami bebek isimleri
  static const quranSearch = '/quran-search'; // Kur'an'da arama
  static const ilmihal = '/ilmihal'; // ilmihal / sık sorulan dini sorular
  static const hajj = '/hajj'; // Hac & Umre rehberi
  static const streak = '/streak'; // İbadet serisi & rozetler
  static const reminders = '/reminders'; // özel hatırlatıcılar
  static const travel = '/travel'; // seferî (seyahat) modu
  static const readingPlan = '/reading-plan'; // Kur'an okuma planı (şablonlar)
  static const duaWall = '/dua-wall'; // Dua duvarı (üye + rumuz + moderasyon)
  static const tasks = '/tasks'; // günlük görevler (#18)
  static const abdestGuide = '/abdest'; // abdest & taharet rehberi HUB
  static const guideDetail = '/guide-detail'; // tekil rehber (extra: guide+collection)
  static const namazGuide = '/namaz-guide'; // namaz rehberi hub (#17)
  static const namazHowTo = '/namaz-howto'; // adım adım namaz rehberi
  static const imsakiye = '/imsakiye'; // 2 aylık imsakiye (imsak/iftar)
  static const hatim = '/hatim'; // Hatim Takibi (kişisel)
  static const communityHatim = '/community-hatim'; // Topluluk Hatmi
  static const quiz = '/quiz'; // İslami Bilgi Yarışması
  static const quizLeaderboard = '/quiz-leaderboard'; // Haftalık sıralama
  static const widgetsGallery = '/widgets';
  static const homeLayout = '/home-layout'; // ana ekranı düzenle
  static const featuredEdit = '/featured-edit'; // öne çıkanlar içeriği
  static const adhanAlarm = '/adhan-alarm'; // /:slot — full-screen adhan alarm
}
