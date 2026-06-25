import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../auth/data/auth_controller.dart';
import '../data/hatim_api.dart';

/// Topluluk Hatmi — üyeler cüz alır, okur, "okudum" der; 30 cüz dolunca hatim
/// tamamlanır ve yenisi otomatik açılır. Niyetli (merhum/şifa) hatim de açılır.
class CommunityHatimScreen extends ConsumerWidget {
  const CommunityHatimScreen({super.key});

  bool _tr(BuildContext c) => c.langCode == 'tr';

  void _snack(BuildContext c, String m) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  String _err(String code, bool tr) {
    const m = {
      'taken': 'Bu cüz az önce başkası tarafından alındı',
      'rumuz_required': 'Önce bir rumuz belirle (Dua Duvarı / Hesap)',
      'unauthorized': 'Katılmak için giriş yap',
      'banned': 'Hesabın engellenmiş',
      'network': 'Bağlantı hatası',
      'too_many': 'Çok fazla aktif hatim başlattın',
    };
    return m[code] ?? 'xt.chErrorGeneric'.tr();
  }

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<HatimCampaign> Function(String token) fn,
      {String? ok}) async {
    final auth = ref.read(authControllerProvider);
    final tr = _tr(context);
    if (auth.token == null || auth.user == null) {
      _snack(context, 'xt.chSignInToJoin'.tr());
      return;
    }
    try {
      final res = await fn(auth.token!);
      ref.invalidate(communityHatimProvider);
      if (!context.mounted) return;
      if (res.status == 'completed') {
        _snack(context, 'xt.chKhatmCompleted'.tr());
      } else if (ok != null) {
        _snack(context, ok);
      }
    } on HatimException catch (e) {
      if (context.mounted) _snack(context, _err(e.code, tr));
    } catch (_) {
      if (context.mounted) _snack(context, 'xt.chErrorShort'.tr());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = _tr(context);
    final c = context.colors;
    final async = ref.watch(communityHatimProvider);
    final loggedIn = ref.watch(authControllerProvider).user != null;

    return SelayaScaffold(
      title: 'xt.chTitle'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'xt.chRefresh'.tr(),
          icon: Icon(Icons.refresh_rounded, color: c.gold),
          onPressed: () => ref.invalidate(communityHatimProvider),
        ),
      ],
      body: async.when(
        loading: () => const SelayaLoading(),
        error: (e, _) => SelayaError(error: e),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md,
              AppSpacing.base, AppSpacing.xxxl),
          children: [
            // Tanıtım
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.08),
                borderRadius: AppRadius.rLg,
                border: Border.all(color: c.gold.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(Icons.menu_book_rounded, color: c.gold, size: 22),
                const Gap.md(),
                Expanded(
                  child: Text(
                    'xt.chIntro'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textSecondary, height: 1.4),
                  ),
                ),
              ]),
            ),
            const Gap.md(),
            if (!loggedIn) ...[
              SelayaCard(
                onTap: () => context.push(Routes.auth),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: [
                  Icon(Icons.login_rounded, color: c.gold),
                  const Gap.md(),
                  Expanded(
                    child: Text(
                        'xt.chSignInToClaim'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                ]),
              ),
              const Gap.md(),
            ],
            for (final camp in data.campaigns) ...[
              _campaignCard(context, ref, camp, tr, c),
              const Gap.md(),
            ],
            // Yeni hatim başlat
            OutlinedButton.icon(
              onPressed: () => _showCreate(context, ref, tr),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('xt.chStartIntentionKhatm'.tr()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: c.gold,
                side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                shape:
                    const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
              ),
            ),
            if (data.completed.isNotEmpty) ...[
              const Gap.lg(),
              Text('xt.chCompletedKhatms'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
              const Gap.sm(),
              for (final cc in data.completed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: c.success),
                    const Gap.sm(),
                    Expanded(
                      child: Text(
                        '${cc['title'] ?? ''}${(cc['intention'] ?? '').toString().isNotEmpty ? ' · ${cc['intention']}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _campaignCard(BuildContext context, WidgetRef ref, HatimCampaign camp,
      bool tr, dynamic c) {
    final progress = camp.total > 0 ? camp.done / camp.total : 0.0;
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(camp.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if ((camp.intention ?? '').isNotEmpty)
                    Text(camp.intention!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('${camp.done}/${camp.total}',
                  style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ]),
          const Gap.sm(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(c.gold),
            ),
          ),
          const Gap.md(),
          // 30 cüz ızgarası
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 1,
            ),
            itemCount: camp.juz.length,
            itemBuilder: (context, i) =>
                _juzCell(context, ref, camp, camp.juz[i], tr, c),
          ),
          // Senin aldığın, henüz okumadığın cüzler — net "Okudum" butonu
          // (kullanıcı kareye tekrar dokunmayı akıl edemeyebilir).
          ..._myJuzSection(context, ref, camp, tr, c),
        ],
      ),
    );
  }

  List<Widget> _myJuzSection(BuildContext context, WidgetRef ref,
      HatimCampaign camp, bool tr, dynamic c) {
    final myOpen =
        camp.juz.where((j) => j.mine && j.status != 'done').toList();
    if (myOpen.isEmpty) return const [];
    return [
      const Gap.md(),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.gold.withValues(alpha: 0.08),
          borderRadius: AppRadius.rMd,
          border: Border.all(color: c.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bookmark_added_rounded, size: 17, color: c.gold),
              const Gap.xs(),
              Expanded(
                child: Text('xt.chYourJuz'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: c.gold)),
              ),
              Text('xt.chMarkWhenRead'.tr(),
                  style: TextStyle(color: c.textTertiary, fontSize: 11)),
            ]),
            const Gap.sm(),
            for (final j in myOpen) _myJuzRow(context, ref, camp, j, tr, c),
          ],
        ),
      ),
    ];
  }

  Widget _myJuzRow(BuildContext context, WidgetRef ref, HatimCampaign camp,
      HatimJuz j, bool tr, dynamic c) {
    final page = ((j.juzNo - 1) * 20 + 1).clamp(1, 604);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.gold.withValues(alpha: 0.16),
            borderRadius: AppRadius.rSm,
          ),
          child: Text('${j.juzNo}',
              style: TextStyle(
                  color: c.gold, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        const Gap.sm(),
        Expanded(
          child: Text('xt.chJuzLabel'.tr(args: [j.juzNo.toString()]),
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton.icon(
          onPressed: () => context.push(Routes.mushaf, extra: page),
          icon: const Icon(Icons.menu_book_rounded, size: 16),
          label: Text('xt.chRead'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: c.textSecondary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const Gap.xs(),
        FilledButton.icon(
          onPressed: () => _run(
              context, ref, (t) => HatimApi.markDone(t, camp.id, j.juzNo),
              ok: 'xt.chJuzDone'.tr(args: [j.juzNo.toString()])),
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text('xt.chDone'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: c.success,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ]),
    );
  }

  Widget _juzCell(BuildContext context, WidgetRef ref, HatimCampaign camp,
      HatimJuz j, bool tr, dynamic c) {
    Color bg, fg, border;
    Widget? mark;
    if (j.status == 'done') {
      bg = c.success.withValues(alpha: 0.18);
      fg = c.success;
      border = c.success.withValues(alpha: 0.5);
      mark = Icon(Icons.check_rounded, size: 13, color: c.success);
    } else if (j.mine) {
      bg = c.gold;
      fg = c.onGold;
      border = c.gold;
    } else if (j.status == 'claimed') {
      bg = c.surface;
      fg = c.textTertiary;
      border = c.border;
    } else {
      bg = c.surfaceAlt;
      fg = c.textSecondary;
      border = c.gold.withValues(alpha: 0.35);
    }
    return GestureDetector(
      onTap: () => _onCellTap(context, ref, camp, j, tr),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: border, width: j.mine ? 0 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${j.juzNo}',
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
            ?mark,
            if (j.mine && j.status != 'done')
              Text('xt.chDoneQuestion'.tr(),
                  style: TextStyle(color: fg, fontSize: 8.5)),
          ],
        ),
      ),
    );
  }

  void _onCellTap(BuildContext context, WidgetRef ref, HatimCampaign camp,
      HatimJuz j, bool tr) {
    if (j.status == 'done') {
      _snack(context, 'xt.chJuzAlreadyDone'.tr());
      return;
    }
    if (j.mine) {
      _showJuzActions(context, ref, camp, j, tr);
      return;
    }
    if (j.status == 'claimed') {
      _snack(context,
          'xt.chJuzReadingBy'.tr(args: [j.rumuz ?? '?']));
      return;
    }
    // open → al
    _run(context, ref, (t) => HatimApi.claim(t, camp.id, j.juzNo),
        ok: 'xt.chJuzClaimed'.tr(args: [j.juzNo.toString()]));
  }

  void _showJuzActions(BuildContext context, WidgetRef ref, HatimCampaign camp,
      HatimJuz j, bool tr) {
    final cc = context.colors;
    final page = ((j.juzNo - 1) * 20 + 1).clamp(1, 604);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('xt.chJuzLabel'.tr(args: [j.juzNo.toString()]),
                    style: TextStyle(
                        color: cc.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.check_circle_rounded, color: cc.success),
              title: Text('xt.chMarkRead'.tr()),
              onTap: () {
                Navigator.pop(context);
                _run(context, ref,
                    (t) => HatimApi.markDone(t, camp.id, j.juzNo),
                    ok: 'xt.chMarkedDone'.tr());
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book_rounded, color: cc.gold),
              title: Text('xt.chReadInMushaf'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.mushaf, extra: page);
              },
            ),
            ListTile(
              leading: Icon(Icons.undo_rounded, color: cc.textTertiary),
              title: Text('xt.chRelease'.tr()),
              onTap: () {
                Navigator.pop(context);
                _run(context, ref,
                    (t) => HatimApi.release(t, camp.id, j.juzNo),
                    ok: 'xt.chReleased'.tr());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref, bool tr) {
    final auth = ref.read(authControllerProvider);
    if (auth.token == null || auth.user == null) {
      _snack(context, 'xt.chSignInToStart'.tr());
      return;
    }
    final titleC = TextEditingController();
    final intentC = TextEditingController();
    final cc = context.colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
            AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('xt.chCreateTitle'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Gap.md(),
            TextField(
              controller: titleC,
              maxLength: 120,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'xt.chTitleLabel'.tr(),
                hintText: 'xt.chTitleHint'.tr(),
                filled: true,
                fillColor: cc.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg, borderSide: BorderSide.none),
              ),
            ),
            TextField(
              controller: intentC,
              maxLength: 160,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'xt.chIntentionLabel'.tr(),
                hintText: 'xt.chIntentionHint'.tr(),
                filled: true,
                fillColor: cc.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg, borderSide: BorderSide.none),
              ),
            ),
            const Gap.md(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final t = titleC.text.trim();
                  if (t.length < 2) {
                    _snack(context, 'xt.chTitleRequired'.tr());
                    return;
                  }
                  Navigator.pop(context);
                  _run(
                      context,
                      ref,
                      (tok) => HatimApi.create(tok, t, intentC.text.trim()),
                      ok: 'xt.chKhatmStarted'.tr());
                },
                style: FilledButton.styleFrom(
                    backgroundColor: cc.gold,
                    foregroundColor: cc.onGold,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('xt.chStart'.tr()),
              ),
            ),
            const Gap.sm(),
          ],
        ),
      ),
    );
  }
}
