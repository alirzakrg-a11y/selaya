import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../auth/data/auth_controller.dart';
import '../data/dua_wall_api.dart';

/// 🤲 DUA DUVARI (#10) — üyeler dua/istek paylaşır; panelde onaylananlar
/// herkese görünür. Okuma herkese açık; paylaşım giriş + rumuz ister. Çok
/// katmanlı koruma (üye + rumuz + küfür filtresi + panel onayı) sunucudadır.
class DuaWallScreen extends ConsumerStatefulWidget {
  const DuaWallScreen({super.key});
  @override
  ConsumerState<DuaWallScreen> createState() => _DuaWallScreenState();
}

class _DuaWallScreenState extends ConsumerState<DuaWallScreen> {
  final List<DuaPost> _duas = [];
  final Set<String> _amined = {};
  final Set<String> _blocked = {}; // engellenen rumuzlar (cihaz-yerel, UGC)
  bool _loading = true;
  bool _loadingMore = false;
  bool _end = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _blocked.addAll(
        ref.read(sharedPreferencesProvider).getStringList('dua_blocked') ??
            const <String>[]);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await DuaWallApi.list();
      if (!mounted) return;
      setState(() {
        _duas
          ..clear()
          ..addAll(list.where((d) => !_blocked.contains(d.rumuz)));
        _loading = false;
        _end = list.length < 30;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _end || _duas.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final list = await DuaWallApi.list(before: _duas.last.createdAt);
      if (!mounted) return;
      setState(() {
        _duas.addAll(list.where((d) => !_blocked.contains(d.rumuz)));
        _end = list.length < 30;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _msg(bool tr, String code) {
    switch (code) {
      case 'contains_profanity':
        return 'xt.dwErrProfanity'.tr();
      case 'too_soon':
        return 'xt.dwErrTooSoon'.tr();
      case 'too_many_pending':
        return 'xt.dwErrTooManyPending'.tr();
      case 'too_short':
        return 'xt.dwErrTooShort'.tr();
      case 'too_long':
        return 'xt.dwErrTooLong'.tr();
      case 'rumuz_required':
        return 'xt.dwErrRumuzRequired'.tr();
      case 'rumuz_profanity':
        return 'xt.dwErrRumuzProfanity'.tr();
      case 'rumuz_length':
        return 'xt.dwErrRumuzLength'.tr();
      case 'rumuz_chars':
        return 'xt.dwErrRumuzChars'.tr();
      case 'rumuz_sacred':
        return 'xt.dwErrRumuzSacred'.tr();
      case 'rumuz_taken':
        return 'xt.dwErrRumuzTaken'.tr();
      case 'unauthorized':
        return 'xt.dwErrUnauthorized'.tr();
      case 'network':
        return 'xt.dwErrNetwork'.tr();
      default:
        return 'xt.dwErrGeneric'.tr();
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _onCompose() async {
    final tr = context.langCode == 'tr';
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn) {
      _toast('xt.dwSignInToShare'.tr());
      context.push(Routes.auth);
      return;
    }
    var rumuz = auth.user?.rumuz ?? '';
    if (rumuz.trim().isEmpty) {
      final set = await _askRumuz(tr);
      if (set == null) return; // iptal
      rumuz = set;
    }
    if (!mounted) return;
    _showCompose(tr, rumuz);
  }

  /// Rumuz iste + sunucuya kaydet. Başarılıysa rumuzu döner, iptalde null.
  Future<String?> _askRumuz(bool tr) async {
    final ctrl = TextEditingController();
    final c = context.colors;
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? err;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Text('xt.dwRumuzDialogTitle'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'xt.dwRumuzDialogDesc'.tr(),
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const Gap.sm(),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 24,
                  decoration: InputDecoration(
                    hintText: 'xt.dwRumuzHint'.tr(),
                    errorText: err,
                    filled: true,
                    fillColor: c.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.rLg,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.gold),
                onPressed: () async {
                  final v = ctrl.text.trim();
                  if (v.length < 2) {
                    setSt(() => err = _msg(tr, 'rumuz_length'));
                    return;
                  }
                  final token = ref.read(authControllerProvider).token;
                  if (token == null) return;
                  try {
                    final saved = await DuaWallApi.setRumuz(token, v);
                    final user = ref.read(authControllerProvider).user;
                    if (user != null) {
                      await ref
                          .read(authControllerProvider.notifier)
                          .updateUser(user.copyWith(rumuz: saved));
                    }
                    if (ctx.mounted) Navigator.pop(ctx, saved);
                  } on DuaWallException catch (e) {
                    setSt(() => err = _msg(tr, e.code));
                  }
                },
                child: Text('xt.dwSave'.tr()),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCompose(bool tr, String rumuz) {
    final c = context.colors;
    final ctrl = TextEditingController();
    bool sending = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.front_hand_rounded, color: c.gold, size: 20),
                  const Gap.sm(),
                  Expanded(
                    child: Text(
                      'xt.dwComposeTitle'.tr(),
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('@$rumuz',
                      style: TextStyle(color: c.gold, fontWeight: FontWeight.w700)),
                ],
              ),
              const Gap.md(),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 280,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'xt.dwComposeHint'.tr(),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              Text(
                'xt.dwComposeApprovalNote'.tr(),
                style: TextStyle(color: c.textTertiary, fontSize: 12),
              ),
              const Gap.md(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.onGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: sending
                      ? null
                      : () async {
                          final text = ctrl.text.trim();
                          if (text.length < 3) return;
                          setSt(() => sending = true);
                          final token = ref.read(authControllerProvider).token;
                          if (token == null) return;
                          try {
                            await DuaWallApi.submit(token, text);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _toast('xt.dwSentForApproval'.tr());
                          } on DuaWallException catch (e) {
                            setSt(() => sending = false);
                            _toast(_msg(tr, e.code));
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('xt.dwSend'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAmin(DuaPost post) async {
    if (_amined.contains(post.id)) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn) {
      _toast('xt.dwSignInToAmin'.tr());
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _amined.add(post.id)); // iyimser
    try {
      final n = await DuaWallApi.amin(auth.token!, post.id);
      if (!mounted) return;
      final i = _duas.indexWhere((d) => d.id == post.id);
      if (i >= 0) {
        setState(() => _duas[i] = DuaPost(
              id: post.id,
              rumuz: post.rumuz,
              text: post.text,
              amins: n,
              createdAt: post.createdAt,
            ));
      }
    } catch (_) {
      if (mounted) setState(() => _amined.remove(post.id));
    }
  }

  /// Bir duayı şikayet et (UGC moderasyonu). Onaylı bir sorgu sonra API'ye gider.
  Future<void> _report(DuaPost post) async {
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn) {
      _toast('xt.dwSignInToReport'.tr());
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('xt.dwReport'.tr()),
        content: Text('xt.dwReportConfirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('xt.dwCancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('xt.dwReport'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DuaWallApi.report(auth.token!, post.id);
      if (mounted) {
        _toast('xt.dwReportReceived'.tr());
      }
    } catch (_) {
      if (mounted) _toast('xt.dwReportFailed'.tr());
    }
  }

  /// Bir kullanıcıyı (rumuz) engelle — duaları bu cihazda gizlenir (yerel).
  Future<void> _block(DuaPost post) async {
    final rumuz = post.rumuz;
    _blocked.add(rumuz);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('dua_blocked', _blocked.toList());
    setState(() => _duas.removeWhere((d) => d.rumuz == rumuz));
    if (mounted) {
      _toast('xt.dwBlocked'.tr(args: [rumuz]));
    }
  }

  /// Üstte duran "dua paylaş" davet kutusu — dokununca compose akışı (giriş +
  /// rumuz kontrolü _onCompose'da). Listeyle birlikte kayar.
  Widget _composePrompt(bool tr) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: InkWell(
        onTap: _onCompose,
        borderRadius: AppRadius.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.gold.withValues(alpha: 0.16), c.surfaceAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.rLg,
            border: Border.all(color: c.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.gold.withValues(alpha: 0.16),
                child: Icon(Icons.front_hand_rounded, color: c.gold, size: 18),
              ),
              const Gap.md(),
              Expanded(
                child: Text(
                  'xt.dwComposePromptText'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary),
                ),
              ),
              const Gap.sm(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: c.gold,
                    borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, color: c.onGold, size: 15),
                    const Gap.xs(),
                    Text('xt.dwShare'.tr(),
                        style: TextStyle(
                            color: c.onGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    final c = context.colors;
    return SelayaScaffold(
      title: 'duaWall.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'xt.dwShareTooltip'.tr(),
          icon: Icon(Icons.add_rounded, color: c.gold),
          onPressed: _onCompose,
        ),
      ],
      body: _loading
          ? const SelayaLoading()
          : _error != null
              ? SelayaError(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _duas.isEmpty
                      ? ListView(
                          children: [
                            _composePrompt(tr),
                            const SizedBox(height: 80),
                            SelayaEmpty(
                              icon: Icons.front_hand_rounded,
                              message: 'xt.dwEmpty'.tr(),
                            ),
                          ],
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >
                                n.metrics.maxScrollExtent - 400) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.base,
                                AppSpacing.sm,
                                AppSpacing.base,
                                AppSpacing.xxxl),
                            itemCount: _duas.length + 2,
                            separatorBuilder: (_, _) => const Gap.sm(),
                            itemBuilder: (_, i) {
                              if (i == 0) return _composePrompt(tr);
                              if (i == _duas.length + 1) {
                                return _end
                                    ? const SizedBox(height: 8)
                                    : const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      );
                              }
                              final d = _duas[i - 1];
                              return _DuaCard(
                                post: d,
                                amined: _amined.contains(d.id),
                                onAmin: () => _onAmin(d),
                                onReport: () => _report(d),
                                onBlock: () => _block(d),
                                tr: tr,
                              );
                            },
                          ),
                        ),
                ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  final DuaPost post;
  final bool amined;
  final VoidCallback onAmin;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final bool tr;
  const _DuaCard({
    required this.post,
    required this.amined,
    required this.onAmin,
    required this.onReport,
    required this.onBlock,
    required this.tr,
  });

  String _ago() {
    final ms = DateTime.now().millisecondsSinceEpoch - post.createdAt;
    final m = ms ~/ 60000;
    if (m < 1) return 'xt.dwAgoJustNow'.tr();
    if (m < 60) return 'xt.dwAgoMinutes'.tr(args: [m.toString()]);
    final h = m ~/ 60;
    if (h < 24) return 'xt.dwAgoHours'.tr(args: [h.toString()]);
    final d = h ~/ 24;
    return 'xt.dwAgoDays'.tr(args: [d.toString()]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: c.gold.withValues(alpha: 0.16),
                child: Text(
                  post.rumuz.isNotEmpty ? post.rumuz[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: c.gold, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const Gap.sm(),
              Expanded(
                child: Text(
                  post.rumuz,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(_ago(),
                  style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: c.textTertiary),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                onSelected: (v) {
                  if (v == 'report') {
                    onReport();
                  } else if (v == 'block') {
                    onBlock();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'report',
                      child: Row(children: [
                        const Icon(Icons.flag_outlined, size: 18),
                        const Gap.sm(),
                        Text('xt.dwReport'.tr()),
                      ])),
                  PopupMenuItem(
                      value: 'block',
                      child: Row(children: [
                        const Icon(Icons.block_rounded, size: 18),
                        const Gap.sm(),
                        Text('xt.dwBlockUser'.tr()),
                      ])),
                ],
              ),
            ],
          ),
          const Gap.sm(),
          Text(post.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5, color: c.textPrimary)),
          const Gap.sm(),
          Row(
            children: [
              InkWell(
                onTap: () => SharePlus.instance.share(ShareParams(
                    text: '${post.text}\n\n— @${post.rumuz} · SELAYA')),
                borderRadius: AppRadius.rMd,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.ios_share_rounded,
                      size: 18, color: c.textTertiary),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onAmin,
                borderRadius: AppRadius.rMd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        amined ? c.gold.withValues(alpha: 0.16) : c.surfaceAlt,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                        color:
                            amined ? c.gold.withValues(alpha: 0.4) : c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🤲', style: TextStyle(fontSize: amined ? 15 : 14)),
                      const SizedBox(width: 6),
                      Text(
                        post.amins > 0 ? 'Âmin · ${post.amins}' : 'Âmin',
                        style: TextStyle(
                          color: amined ? c.gold : c.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
