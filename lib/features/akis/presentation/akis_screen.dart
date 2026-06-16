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

/// "Akış" (#19) — a single daily stream that gathers the verse & hadith of the
/// day, today's task progress, a short tip, a greeting-card shortcut and
/// announcements. (Distinct from the video "Reels" feed in More.) Built to be a
/// future admin-driven hub; the announcement block is the placeholder for that.
class AkisScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.langCode;
    final ayahs = ref.watch(inspirationProvider).value ?? const [];
    final hadiths = ref.watch(hadithsProvider).value ?? const [];
    final duas = ref.watch(duasProvider).value ?? const [];
    final dayIdx = DateTime.now().day;

    // #7 — akışı zenginleştir: tek "günün" içeriği yerine birkaç ayet/hadis/dua/
    // bilgi (güne göre SABİT, farklı offset'lerle çeşitli).
    List<T> pick<T>(List<T> src, int n) => src.isEmpty
        ? <T>[]
        : [
            for (var k = 0; k < n && k < src.length; k++)
              src[(dayIdx + k) % src.length]
          ];
    final vs = pick(ayahs, 3);
    final hs = pick(hadiths, 3);
    final ds = pick(duas, 2);
    final tips = [for (var k = 0; k < 3; k++) _tips[(dayIdx + k) % _tips.length]];

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
          const Gap.md(),
          // Instagram-style story rail (Günün Ayeti, Hadisi, "Bunu biliyor
          // muydun"…) at the very top of the stream.
          const StoryRail(),
          const Gap.lg(),
          for (var k = 0; k < 3; k++) ...[
            if (k < vs.length) ...[
              _ContentCard(
                label: k == 0 ? 'akis.verseOfDay'.tr() : 'more.verses'.tr(),
                icon: Icons.menu_book_rounded,
                body: vs[k].text(lang),
                footer: vs[k].reference,
                likeKey: 'verse:${vs[k].id}',
              ),
              const Gap.md(),
            ],
            if (k < hs.length) ...[
              _ContentCard(
                label: k == 0 ? 'akis.hadithOfDay'.tr() : 'more.hadiths'.tr(),
                icon: Icons.format_quote_rounded,
                body: hs[k].text(lang),
                footer: hs[k].collection,
                likeKey: 'hadith:${hs[k].id}',
              ),
              const Gap.md(),
            ],
            if (k < ds.length) ...[
              _ContentCard(
                label: k == 0 ? 'akis.duaOfDay'.tr() : 'duas.title'.tr(),
                icon: Icons.volunteer_activism_rounded,
                body: ds[k].text(lang),
                footer: ds[k].source.isNotEmpty ? ds[k].source : null,
                likeKey: 'dua:${ds[k].id}',
              ),
              const Gap.md(),
            ],
            _ContentCard(
              label: 'akis.didYouKnow'.tr(),
              icon: Icons.lightbulb_outline_rounded,
              body: lang == 'tr' ? tips[k].$1 : tips[k].$2,
              share: false, // ⑱ "Bunu biliyor muydun"da paylaş butonu yok
            ),
            const Gap.md(),
          ],
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
