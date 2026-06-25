import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/share/share_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/like_button.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_logo.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../stories/presentation/story_rail.dart';
import '../../prayer_times/data/prayer_repository.dart';
import '../../baby_names/presentation/baby_names_screen.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';

/// "Akış" (#19) — a single daily stream that gathers the verse & hadith of the
/// day, today's task progress, a short tip, a greeting-card shortcut and
/// announcements. (Distinct from the video "Reels" feed in More.) Built to be a
/// future admin-driven hub; the announcement block is the placeholder for that.
class AkisScreen extends ConsumerStatefulWidget {
  const AkisScreen({super.key});

  // Short "did you know" facts (kısa dini bilgiler) — rotate daily. Bilingual
  // inline, the established pattern for small curated content.
  static const _tips = <(String, String)>[
    (
      'Abdest alırken besmele çekmek sünnettir ve ibadete niyetin başlangıcıdır.',
      'Saying Bismillah when making wudu is a sunnah and the start of your intention.'
    ),
    (
      'Güne "Elhamdülillah" diyerek başlamak, şükrün en güzel anahtarıdır.',
      'Beginning the day with "Alhamdulillah" is the finest key to gratitude.'
    ),
    (
      'Ezan okunurken müezzinin sözlerini tekrar etmek müstehaptır.',
      'Repeating the muezzin\'s words during the adhan is recommended.'
    ),
    (
      'Sabah ve akşam zikirleri, günü manevi bir korumayla çevreler.',
      'The morning and evening adhkar surround the day with spiritual protection.'
    ),
    (
      'Bir âyet bile olsa her gün Kur\'an okumak kalbi diri tutar.',
      'Reading even a single verse of the Quran daily keeps the heart alive.'
    ),
    (
      'Tebessüm sadakadır; küçük iyilikler büyük sevaplara vesiledir.',
      'A smile is charity; small kindnesses are a means to great rewards.'
    ),
    (
      'Salavat getirmek, duaların kabulüne vesile olan bir ibadettir.',
      'Sending salawat upon the Prophet is a worship that helps prayers be accepted.'
    ),
    (
      'Kur\'an\'da 114 sûre ve 6236 âyet bulunur.',
      'The Quran contains 114 surahs and 6236 verses.'
    ),
    (
      'Esmâ-ül Hüsnâ, Allah\'ın 99 güzel ismidir.',
      'Asma al-Husna are the 99 Beautiful Names of Allah.'
    ),
    (
      'Cuma günü, müminlerin haftalık bayramı sayılır.',
      'Friday is regarded as the weekly festival of the believers.'
    ),
    (
      'Misvak kullanmak, Peygamberimizin ağız temizliği sünnetidir.',
      'Using the miswak is the Prophet\'s sunnah for oral cleanliness.'
    ),
    (
      'İlk vahiy "Oku!" emriyle Hira Mağarası\'nda gelmiştir.',
      'The first revelation began with "Read!" in the Cave of Hira.'
    ),
    (
      'Sadaka-i câriye, kişi vefat etse de sevabı süren hayırdır.',
      'A continuous charity keeps rewarding a person even after death.'
    ),
    (
      'Komşu hakkı İslam\'da büyük önem taşır.',
      'The rights of neighbours are greatly emphasised in Islam.'
    ),
    (
      'Tövbe kapısı, güneş batıdan doğana dek açıktır.',
      'The door of repentance stays open until the sun rises from the west.'
    ),
    (
      'Receb, Şaban ve Ramazan birlikte "üç aylar" olarak bilinir.',
      'Rajab, Sha\'ban and Ramadan together are known as the "three holy months".'
    ),
    (
      'Kadir Gecesi, bin aydan daha hayırlı kabul edilir.',
      'Laylat al-Qadr is considered better than a thousand months.'
    ),
    (
      'Oruç, sabrı ve şükrü birlikte öğreten bir ibadettir.',
      'Fasting teaches both patience and gratitude.'
    ),
    (
      'Zekât, malı temizleyen ve bereketlendiren bir ibadettir.',
      'Zakat purifies wealth and brings it blessing.'
    ),
    (
      'Beş vakit namaz, müminlere Miraç gecesinde armağan edilmiştir.',
      'The five daily prayers were gifted to the believers on the night of Mi\'raj.'
    ),
    (
      'Selam vermek, aradaki sevgiyi artıran bir sünnettir.',
      'Greeting with salam is a sunnah that increases mutual love.'
    ),
    (
      'İlim öğrenmek, kadın erkek her Müslümana farzdır.',
      'Seeking knowledge is an obligation upon every Muslim.'
    ),
    (
      'Hayâ, imandan bir şubedir.',
      'Modesty is a branch of faith.'
    ),
    (
      'Su, abdest alırken bile israf edilmemelidir.',
      'Water should not be wasted, even while making wudu.'
    ),
    (
      'Ana babaya "öf" bile dememek Kur\'an\'ın emridir.',
      'The Quran commands not even saying "uff" to one\'s parents.'
    ),
    (
      'Sıla-i rahim (akraba ziyareti) ömrü ve rızkı bereketlendirir.',
      'Maintaining family ties brings blessing to one\'s life and provision.'
    ),
    (
      'Sabah namazını cemaatle kılmak, gece boyu ibadet sevabı kazandırır.',
      'Praying Fajr in congregation carries the reward of a night of worship.'
    ),
  ];

  @override
  ConsumerState<AkisScreen> createState() => _AkisScreenState();
}

class _AkisScreenState extends ConsumerState<AkisScreen> {
  String _filter = 'all'; // all · verse · hadith · dua · tip

  // Günün görevi — eyleme dönük günlük teşvikler (güne göre döner, sünnete uygun).
  static const _tasks = <(String, String)>[
    ('Bugün 33 kere "SübhanAllah" de.', 'Say "SubhanAllah" 33 times today.'),
    ("Bir sayfa Kur'an-ı Kerim oku.", 'Read one page of the Quran.'),
    ('Bir yakınını ara, hatırını sor (sıla-i rahim).',
        'Call a relative and check on them.'),
    ('Bugün birine tebessüm et — tebessüm sadakadır.',
        'Smile at someone today — a smile is charity.'),
    ('Bir miktar sadaka ver.', 'Give a little in charity.'),
    ('100 kere salavat getir.', 'Send 100 salawat upon the Prophet.'),
    ('Sabah ve akşam zikirlerini yap.',
        'Do the morning and evening adhkar.'),
    ('Bir âyetin mealini oku ve üzerine düşün.',
        "Read a verse's meaning and reflect on it."),
    ('Ana babanı ara veya ziyaret et.', 'Call or visit your parents.'),
    ('Bugün bir iyilik yap, kimseye söyleme.',
        'Do a good deed today without telling anyone.'),
    ('70 kere "Estağfirullah" diyerek tövbe et.',
        'Seek forgiveness 70 times saying "Astaghfirullah".'),
    ('Bir komşunun hatırını sor.', 'Check on a neighbour.'),
    ('İsrafı azalt — suyu dikkatli kullan.',
        'Reduce waste — use water carefully.'),
    ('Öğrendiğin bir bilgiyi biriyle paylaş.',
        'Share something you learned with someone.'),
    ('Bir öfkeni yut ve affet.', 'Hold back an anger and forgive.'),
    ('Yemekten önce ve sonra duanı et.',
        'Say the dua before and after eating.'),
  ];

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final tr = lang == 'tr';
    final c = context.colors;
    final ayahs = ref.watch(inspirationProvider).value ?? const [];
    final hadiths = ref.watch(hadithsProvider).value ?? const [];
    final duas = ref.watch(duasProvider).value ?? const [];
    final asmas = ref.watch(asmaProvider).value ?? const <Asma>[];
    final babies = ref.watch(babyNamesProvider).value ?? const <BabyName>[];
    final now = DateTime.now();
    final dayIdx = now.day;

    // Güne göre SABİT seçim; bir tür seçilince ondan DAHA ÇOK gösterilir.
    List<T> pick<T>(List<T> src, int n) => src.isEmpty
        ? <T>[]
        : [
            for (var k = 0; k < n && k < src.length; k++)
              src[(dayIdx + k) % src.length]
          ];
    final vs = pick(ayahs, _filter == 'verse' ? 10 : 3);
    final hs = pick(hadiths, _filter == 'hadith' ? 10 : 3);
    final ds = pick(duas, _filter == 'dua' ? 8 : 2);
    final tipN = _filter == 'tip' ? 8 : 3;
    final tips = [
      for (var k = 0; k < tipN; k++)
        AkisScreen._tips[(dayIdx + k) % AkisScreen._tips.length]
    ];

    Widget verseCard(int i) => _ContentCard(
          label: i == 0 ? 'akis.verseOfDay'.tr() : 'more.verses'.tr(),
          icon: Icons.menu_book_rounded,
          body: vs[i].text(lang),
          footer: vs[i].reference,
          likeKey: 'verse:${vs[i].id}',
        );
    Widget hadithCard(int i) => _ContentCard(
          label: i == 0 ? 'akis.hadithOfDay'.tr() : 'more.hadiths'.tr(),
          icon: Icons.format_quote_rounded,
          body: hs[i].text(lang),
          footer: hs[i].collection,
          likeKey: 'hadith:${hs[i].id}',
        );
    Widget duaCard(int i) => _ContentCard(
          label: i == 0 ? 'akis.duaOfDay'.tr() : 'duas.title'.tr(),
          icon: Icons.volunteer_activism_rounded,
          body: ds[i].text(lang),
          footer: ds[i].source.isNotEmpty ? ds[i].source : null,
          likeKey: 'dua:${ds[i].id}',
        );
    Widget tipCard(int i) => _ContentCard(
          label: 'akis.didYouKnow'.tr(),
          icon: Icons.lightbulb_outline_rounded,
          body: tr ? tips[i].$1 : tips[i].$2,
          share: false,
        );

    // Günün çeşitlilik kartları (yalnızca "Tümü" digest'inde gösterilir).
    final asma = asmas.isEmpty ? null : asmas[dayIdx % asmas.length];
    final males = babies.where((n) => n.gender == 'm').toList();
    final females = babies.where((n) => n.gender != 'm').toList();
    final boy = males.isEmpty ? null : males[dayIdx % males.length];
    final girl = females.isEmpty ? null : females[dayIdx % females.length];
    final task = _tasks[dayIdx % _tasks.length];
    final taskDone =
        ref.read(sharedPreferencesProvider).getString('akis_task_done') ==
            _todayKey;

    final cards = <Widget>[];
    void push(Widget w) {
      cards.add(w);
      cards.add(const Gap.md());
    }

    if (_filter == 'all') {
      // Küratörlü günlük digest — her türden BİR + çeşitlilik (esma/isim/görev),
      // arka arkaya bir sürü ayet/hadis yerine.
      if (vs.isNotEmpty) push(verseCard(0));
      if (hs.isNotEmpty) push(hadithCard(0));
      if (asma != null) push(_EsmaCard(asma: asma, lang: lang));
      if (ds.isNotEmpty) push(duaCard(0));
      if (boy != null || girl != null) {
        push(_NamesCard(boy: boy, girl: girl, tr: tr));
      }
      push(_TaskCard(
        text: tr ? task.$1 : task.$2,
        done: taskDone,
        tr: tr,
        onToggle: () {
          final p = ref.read(sharedPreferencesProvider);
          if (p.getString('akis_task_done') == _todayKey) {
            p.remove('akis_task_done');
          } else {
            p.setString('akis_task_done', _todayKey);
          }
          setState(() {});
        },
      ));
      push(tipCard(0));
    } else if (_filter == 'verse') {
      for (var i = 0; i < vs.length; i++) {
        push(verseCard(i));
      }
    } else if (_filter == 'hadith') {
      for (var i = 0; i < hs.length; i++) {
        push(hadithCard(i));
      }
    } else if (_filter == 'dua') {
      for (var i = 0; i < ds.length; i++) {
        push(duaCard(i));
      }
    } else {
      for (var i = 0; i < tips.length; i++) {
        push(tipCard(i));
      }
    }
    if (cards.isEmpty) {
      cards.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(
          child: Text('xt.akLoading'.tr(),
              style: TextStyle(color: c.textTertiary)),
        ),
      ));
    }
    final offset = ref.watch(hijriOffsetProvider);

    return SelayaScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.xxxl),
        children: [
          Row(
            children: [
              const SelayaLogo(size: 40, showWordmark: false),
              const Gap.md(),
              Text('akis.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const Gap.sm(),
          // Bugünün tarihi — günlük akışa bağlam verir.
          Row(
            children: [
              Icon(Icons.event_rounded, size: 15, color: c.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${formatWeekday(now, lang)} · ${formatGregorian(now, lang)}  ·  ${formatHijri(now, lang, offsetDays: offset)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary),
                ),
              ),
            ],
          ),
          const Gap.md(),
          // Instagram-style story rail at the very top of the stream.
          const StoryRail(),
          const Gap.md(),
          // Tür filtreleri — akışı düzenle (Tümü / Ayet / Hadis / Dua / Bilgi).
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in const <(String, String)>[
                  ('all', 'xt.akFilterAll'),
                  ('verse', 'xt.akFilterVerse'),
                  ('hadith', 'xt.akFilterHadith'),
                  ('dua', 'xt.akFilterDua'),
                  ('tip', 'xt.akFilterTip'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _FilterChip(
                      label: f.$2.tr(),
                      selected: _filter == f.$1,
                      onTap: () => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          const Gap.md(),
          ...cards,
          if (_filter == 'all') ...[
            _ActionCard(
              label: 'akis.sendGreeting'.tr(),
              desc: 'akis.sendGreetingDesc'.tr(),
              icon: Icons.card_giftcard_rounded,
              onTap: () => context.push(Routes.greetings),
            ),
            const Gap.md(),
            _ActionCard(
              label: 'akis.reels'.tr(),
              desc: 'akis.reelsDesc'.tr(),
              icon: Icons.play_circle_outline_rounded,
              onTap: () => context.push(Routes.feed),
            ),
            const Gap.md(),
            _Announcement(text: 'akis.announcementDemo'.tr()),
            const Gap.md(),
          ],
          const _SourceNote(),
        ],
      ),
    );
  }
}

/// Small source disclaimer shown under religious content (ayet/hadis/dua/bilgi).
class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.06),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: c.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.menu_book_rounded, color: c.gold, size: 18),
          const Gap.sm(),
          Expanded(
            child: Text(
              'Kaynak: Diyanet İşleri Başkanlığı İlmihali esas alınmıştır. '
              'Ayrıntı için yetkili kaynaklara başvurun.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textTertiary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only content card: gold label + icon, body text, optional source.
class _ContentCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String body;
  final String? footer;
  final String? likeKey;
  final bool share;
  const _ContentCard(
      {required this.label,
      required this.icon,
      required this.body,
      this.footer,
      this.likeKey,
      this.share = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c.gold),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c.gold,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const Gap.sm(),
          Text(body,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.5, color: c.textPrimary)),
          const Gap.sm(),
          Row(
            children: [
              if (footer != null && footer!.isNotEmpty)
                Expanded(
                  child: Text('— $footer',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                )
              else
                const Spacer(),
              if (likeKey != null) LikeButton(likeKey: likeKey!),
              if (share)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showVerseShareSheet(context,
                      text: body, reference: footer ?? '', label: label),
                  icon: Icon(Icons.ios_share_rounded,
                      size: 18, color: c.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// _TasksCard (günlük görev ilerlemesi) KALDIRILDI — günlük görevler komple
// çıkarıldı (kullanıcı 2026-06-15).

/// A simple "label + desc + chevron" action card.
class _ActionCard extends StatelessWidget {
  final String label;
  final String desc;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.label,
      required this.desc,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.gold.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: c.gold, size: 24),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ],
      ),
    );
  }
}

/// Announcement block — the placeholder for future admin-panel content.
class _Announcement extends StatelessWidget {
  final String text;
  const _Announcement({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.08),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, color: c.gold, size: 22),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('akis.announcements'.tr(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: c.gold, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Akış tür filtresi çipi (Tümü / Ayet / Hadis / Dua / Bilgi).
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          color: selected ? c.gold : c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? c.gold : c.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? c.onGold : c.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

/// Gold bölüm etiketi (ikon + büyük harf) — digest kartlarının başlığı.
class _CardLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool chevron;
  const _CardLabel(this.icon, this.text, {this.chevron = false});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.gold),
        const SizedBox(width: 6),
        Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.gold, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        if (chevron) ...[
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.textTertiary),
        ],
      ],
    );
  }
}

/// Günün Esması — Arapça isim + okunuş + anlam; dokun → Esmâül Hüsna.
class _EsmaCard extends StatelessWidget {
  final Asma asma;
  final String lang;
  const _EsmaCard({required this.asma, required this.lang});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      onTap: () => context.push(Routes.asma),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(Icons.auto_awesome_rounded, 'xt.akEsmaOfDay'.tr(),
              chevron: true),
          const Gap.sm(),
          Center(
            child: Text(asma.arabic,
                style:
                    AppTypography.arabic(fontSize: 30, color: c.textPrimary)),
          ),
          const Gap.xs(),
          Center(
            child: Text(asma.name(lang),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.gold, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(asma.meaning(lang),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Günün İsimleri — 1 erkek + 1 kız; dokun → Bebek İsimleri.
class _NamesCard extends StatelessWidget {
  final BabyName? boy;
  final BabyName? girl;
  final bool tr;
  const _NamesCard({required this.boy, required this.girl, required this.tr});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget nameRow(BabyName n, bool isF) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(isF ? Icons.female_rounded : Icons.male_rounded,
                  size: 18, color: isF ? Colors.pink : c.gold),
              const Gap.sm(),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: n.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.textPrimary, fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: '   ${n.meaning}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textSecondary)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
    return SelayaCard(
      patterned: true,
      onTap: () => context.push(Routes.babyNames),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(Icons.child_care_rounded, 'xt.akNamesOfDay'.tr(),
              chevron: true),
          const Gap.sm(),
          if (boy != null) nameRow(boy!, false),
          if (girl != null) nameRow(girl!, true),
        ],
      ),
    );
  }
}

/// Günün Görevi — eyleme dönük günlük teşvik; dokun → bugün için işaretle.
class _TaskCard extends StatelessWidget {
  final String text;
  final bool done;
  final bool tr;
  final VoidCallback onToggle;
  const _TaskCard(
      {required this.text,
      required this.done,
      required this.tr,
      required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      patterned: true,
      onTap: onToggle,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(Icons.task_alt_rounded, 'xt.akTaskOfDay'.tr()),
          const Gap.sm(),
          Row(
            children: [
              Expanded(
                child: Text(text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                          color: done ? c.textTertiary : c.textPrimary,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: c.textTertiary,
                        )),
              ),
              const Gap.md(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? c.success : Colors.transparent,
                  border: Border.all(
                      color: done ? c.success : c.border, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : null,
              ),
            ],
          ),
          if (done) ...[
            const Gap.xs(),
            Text('xt.akDoneToday'.tr(),
                style: TextStyle(
                    color: c.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
