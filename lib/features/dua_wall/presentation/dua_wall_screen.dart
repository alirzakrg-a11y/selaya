import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _loading = true;
  bool _loadingMore = false;
  bool _end = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
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
          ..addAll(list);
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
        _duas.addAll(list);
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
        return tr
            ? 'Duanız uygunsuz ifade içeriyor gibi görünüyor. Lütfen düzenleyin.'
            : 'Your prayer seems to contain inappropriate language. Please edit it.';
      case 'too_soon':
        return tr
            ? 'Çok sık gönderiyorsunuz. Lütfen biraz bekleyin.'
            : 'You are posting too often. Please wait a moment.';
      case 'too_many_pending':
        return tr
            ? 'Onay bekleyen çok sayıda duanız var. Önce onlar değerlendirilsin.'
            : 'You have too many prayers awaiting approval.';
      case 'too_short':
        return tr ? 'Dua çok kısa.' : 'Prayer is too short.';
      case 'too_long':
        return tr ? 'Dua çok uzun (en fazla 280 karakter).' : 'Too long (max 280).';
      case 'rumuz_required':
        return tr ? 'Önce bir rumuz belirleyin.' : 'Set a nickname first.';
      case 'rumuz_profanity':
        return tr
            ? 'Rumuz uygunsuz ifade içeriyor.'
            : 'Nickname contains inappropriate language.';
      case 'rumuz_length':
        return tr ? 'Rumuz 2–24 karakter olmalı.' : 'Nickname must be 2–24 chars.';
      case 'rumuz_chars':
        return tr
            ? 'Rumuz yalnızca harf, rakam, boşluk, nokta ve _ içerebilir.'
            : 'Nickname may contain only letters, numbers, space, dot and _.';
      case 'rumuz_sacred':
        return tr
            ? 'Allah\'ın isimleri veya kutsal değerler rumuz olarak kullanılamaz.'
            : 'Sacred names cannot be used as a nickname.';
      case 'unauthorized':
        return tr ? 'Oturum süresi doldu, tekrar giriş yapın.' : 'Session expired.';
      case 'network':
        return tr ? 'Bağlantı hatası.' : 'Connection error.';
      default:
        return tr ? 'Bir hata oluştu.' : 'Something went wrong.';
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
      _toast(tr
          ? 'Dua paylaşmak için giriş yapın.'
          : 'Please sign in to share a prayer.');
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
            title: Text(tr ? 'Rumuz belirle' : 'Choose a nickname'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr
                      ? 'Dua Duvarında adının yerine bu rumuz görünecek.'
                      : 'This nickname will be shown instead of your name.',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const Gap.sm(),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 24,
                  decoration: InputDecoration(
                    hintText: tr ? 'örn. Mümin Kul' : 'e.g. Faithful Servant',
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
                child: Text(tr ? 'Kaydet' : 'Save'),
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
                      tr ? 'Dua Paylaş' : 'Share a Prayer',
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
                  hintText: tr
                      ? 'Duanı yaz… (örn. Tüm hastalara şifa olsun)'
                      : 'Write your prayer…',
                  filled: true,
                  fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              Text(
                tr
                    ? 'Duan onaylandıktan sonra duvarda görünür.'
                    : 'Your prayer appears after approval.',
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
                            _toast(tr
                                ? 'Duan onaya gönderildi 🤲'
                                : 'Sent for approval 🤲');
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
                      : Text(tr ? 'Gönder' : 'Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAmin(DuaPost post) async {
    final tr = context.langCode == 'tr';
    if (_amined.contains(post.id)) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn) {
      _toast(tr ? 'Âmin demek için giriş yapın.' : 'Sign in to say Amin.');
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
                  tr
                      ? 'Dileğini paylaş, kardeşlerine âmin aldır…'
                      : 'Share your prayer, gather Amins…',
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
                    Text(tr ? 'Paylaş' : 'Share',
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
          tooltip: tr ? 'Dua Paylaş' : 'Share',
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
                              message: tr
                                  ? 'Henüz onaylı dua yok.\nİlk duayı sen paylaş — yukarıdaki kutuya dokun.'
                                  : 'No approved prayers yet.\nBe the first — tap the box above.',
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
  final bool tr;
  const _DuaCard({
    required this.post,
    required this.amined,
    required this.onAmin,
    required this.tr,
  });

  String _ago() {
    final ms = DateTime.now().millisecondsSinceEpoch - post.createdAt;
    final m = ms ~/ 60000;
    if (m < 1) return tr ? 'az önce' : 'just now';
    if (m < 60) return tr ? '$m dk önce' : '${m}m ago';
    final h = m ~/ 60;
    if (h < 24) return tr ? '$h sa önce' : '${h}h ago';
    final d = h ~/ 24;
    return tr ? '$d gün önce' : '${d}d ago';
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
