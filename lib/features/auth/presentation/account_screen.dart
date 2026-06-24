import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/auth_api.dart';
import '../data/auth_controller.dart';
import '../data/sync_service.dart';
import '../domain/auth_validators.dart';
import 'auth_error_banner.dart';

/// Hesabım — profil + çıkış. Misafirse giriş yapmaya yönlendirir.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(authControllerProvider).user;
    final sync = ref.watch(syncControllerProvider);

    return SelayaScaffold(
      title: 'auth.account'.tr(),
      showBack: true,
      body: user == null
          ? const _GuestPrompt()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                const Gap.sm(),
                // Gradyan profil başlığı — avatar + ad + e-posta + rumuz rozeti.
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.rXl,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.gold.withValues(alpha: 0.22), c.surfaceAlt],
                    ),
                    border: Border.all(color: c.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: c.gold.withValues(alpha: 0.2),
                        child: Text(user.initials,
                            style: TextStyle(
                                color: c.gold,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                      ),
                      const Gap.md(),
                      Text(user.fullName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const Gap.xs(),
                      Text(user.email,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textSecondary)),
                      if (user.rumuz.trim().isNotEmpty) ...[
                        const Gap.sm(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.gold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: c.gold.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.front_hand_rounded,
                                  size: 14, color: c.gold),
                              const SizedBox(width: 5),
                              Text('@${user.rumuz.trim()}',
                                  style: TextStyle(
                                      color: c.gold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      const Gap.sm(),
                      TextButton.icon(
                        onPressed: () => _showEditProfile(context, ref),
                        icon:
                            Icon(Icons.edit_rounded, size: 16, color: c.gold),
                        label: Text('auth.editProfile'.tr(),
                            style: TextStyle(color: c.gold)),
                      ),
                    ],
                  ),
                ),
                const Gap.md(),
                SelayaCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Icon(Icons.cloud_done_rounded, color: c.gold),
                    const Gap.md(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('auth.syncTitle'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(_syncLabel(sync.lastSyncedAt),
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    sync.syncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.2))
                        : IconButton(
                            icon: Icon(Icons.sync_rounded, color: c.gold),
                            tooltip: 'auth.syncNow'.tr(),
                            onPressed: () => ref
                                .read(syncControllerProvider.notifier)
                                .restore(),
                          ),
                  ]),
                ),
                const Gap.md(),
                SelayaCard(
                  onTap: () => context.push(Routes.liked),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Icon(Icons.favorite_rounded, color: c.gold),
                    const Gap.md(),
                    Expanded(
                      child: Text('liked.title'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ]),
                ),
                const Gap.sm(),
                SelayaCard(
                  onTap: () => _showChangePassword(context, ref),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Icon(Icons.lock_reset_rounded, color: c.gold),
                    const Gap.md(),
                    Expanded(
                      child: Text('auth.changePassword'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ]),
                ),
                const Gap.sm(),
                // GDPR/KVKK veri taşınabilirliği: kullanıcı tüm verisini indirir.
                SelayaCard(
                  onTap: () => _exportData(context, ref),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Icon(Icons.download_rounded, color: c.gold),
                    const Gap.md(),
                    Expanded(
                      child: Text('auth.exportData'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ]),
                ),
                const Gap.xl(),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('auth.logout'.tr()),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: c.danger,
                        side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                        shape:
                            RoundedRectangleBorder(borderRadius: AppRadius.rLg)),
                  ),
                ),
                const Gap.sm(),
                // Hesabı kalıcı sil (KVKK + Play zorunluluğu).
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: Icon(Icons.delete_forever_rounded,
                      size: 18, color: c.danger),
                  label: Text('auth.deleteAccount'.tr(),
                      style: TextStyle(color: c.danger)),
                ),
              ],
            ),
    );
  }

  /// GDPR/KVKK erişim & taşınabilirlik hakkı — verisini önce okunabilir bir
  /// özet olarak gösterir; isteyen ham JSON'u da paylaşabilir.
  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    final user = auth.user;
    if (auth.token == null || user == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.exportPreparing'.tr())));
    try {
      final synced = await AuthApi.getData(auth.token!);
      if (!context.mounted) return;
      final isTr = context.locale.languageCode == 'tr';
      final readable = _readableExport(user, synced.data, synced.updatedAt, isTr);
      final jsonStr = const JsonEncoder.withIndent('  ').convert({
        'app': 'SELAYA',
        'account': {
          'name': user.name,
          'surname': user.surname,
          'email': user.email,
          'rumuz': user.rumuz,
        },
        'syncedData': synced.data,
        'syncedAt': synced.updatedAt,
      });
      _showDataSheet(context, readable, jsonStr);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth.exportFailed'.tr())));
      }
    }
  }

  /// Senkron verisini (tipli zarf: {t,v}) insan-okur bir metne çevirir.
  String _readableExport(
      dynamic user, Map<String, dynamic> data, int syncedAt, bool isTr) {
    String l(String tr, String en) => isTr ? tr : en;

    // Tipli zarfı aç: {'t':..,'v':..} -> v
    dynamic raw(String key) {
      final e = data[key];
      if (e is Map && e.containsKey('v')) return e['v'];
      return e;
    }

    String onOff(String key) {
      final v = raw(key);
      if (v == null) return '—';
      final on = v == true || v == 'true' || v == 1;
      return on ? l('Açık', 'On') : l('Kapalı', 'Off');
    }

    int count(String key) {
      final v = raw(key);
      if (v is List) return v.length;
      if (v is String && v.trim().isNotEmpty) {
        return v.split(',').where((s) => s.trim().isNotEmpty).length;
      }
      return 0;
    }

    String two(int n) => n.toString().padLeft(2, '0');
    String dt(int ms) {
      if (ms <= 0) return '—';
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
    }

    String mapVal(String key, Map<String, String> m, String fallback) {
      final v = '${raw(key) ?? ''}';
      return m[v] ?? (v.isEmpty ? fallback : v);
    }

    final b = StringBuffer();
    void h(String title) => b.writeln('\n━━━━━  $title  ━━━━━');
    void row(String label, String value) => b.writeln('• $label: $value');

    b.writeln('SELAYA — ${l('Verilerim', 'My Data')}');
    final now = DateTime.now();
    b.writeln(
        '${l('Dışa aktarma', 'Exported')}: ${two(now.day)}.${two(now.month)}.${now.year}');

    h(l('HESAP', 'ACCOUNT'));
    row(l('Ad', 'First name'), '${user.name ?? '—'}');
    row(l('Soyad', 'Last name'), '${user.surname ?? '—'}');
    row(l('E-posta', 'Email'), '${user.email ?? '—'}');
    row(l('Rumuz', 'Nickname'), '${user.rumuz ?? '—'}');

    h(l('GÖRÜNÜM', 'APPEARANCE'));
    row(l('Tema', 'Theme'),
        mapVal('theme_mode', {
          'dark': l('Koyu', 'Dark'),
          'light': l('Açık', 'Light'),
          'system': l('Sistem', 'System'),
        }, '—'));
    row('AMOLED', onOff('amoled'));
    row(l('Renk paleti', 'Color palette'),
        mapVal('app_palette', {
          'gold': l('Altın', 'Gold'),
          'green': l('Yeşil', 'Green'),
        }, l('Altın', 'Gold')));

    h(l('NAMAZ', 'PRAYER'));
    row(l('Hesaplama yöntemi', 'Calc. method'),
        mapVal('calc_method', {'diyanet': 'Diyanet'}, '—'));
    row(l('İkindi (Hanefi)', 'Asr (Hanafi)'), onOff('hanafi_asr'));

    h(l('BİLDİRİMLER', 'NOTIFICATIONS'));
    row(l('Namaz uyarıları', 'Prayer alerts'), onOff('prayer_alerts'));
    row(l('Sürekli bildirim', 'Ongoing bar'), onOff('ongoing_notif'));
    row(l('Günlük ayet', 'Daily verse'), onOff('daily_ayah_notif'));
    row(l('Günlük hadis', 'Daily hadith'), onOff('daily_hadith_notif'));
    row(l('Ezan tam-ekran alarm', 'Full-screen adhan'),
        onOff('full_screen_adhan'));
    row(l('Titreşim', 'Vibration'), onOff('notif_vibration'));
    row(l('Akıllı sessiz', 'Smart silent'), onOff('smart_silent'));
    row(l('Kandil bildirimi', 'Holy nights'), onOff('kandil_notif'));
    row(l('Cuma hatırlatma', 'Friday reminder'), onOff('cuma_notif'));
    row(l('Ramazan modu', 'Ramadan mode'),
        mapVal('ramadan_mode', {
          'auto': l('Otomatik', 'Auto'),
          'on': l('Açık', 'On'),
          'off': l('Kapalı', 'Off'),
        }, l('Otomatik', 'Auto')));

    h(l('İÇERİĞİM', 'MY CONTENT'));
    row(l("Kur'an yer imleri", "Qur'an bookmarks"), '${count('quran_bookmarks')}');
    row(l('Dua favorileri', 'Prayer favorites'), '${count('dua_favorites')}');
    row(l('Ayet/hadis favorileri', 'Verse/hadith favorites'),
        '${count('inspiration_favorites')}');
    row(l('Beğeniler', 'Likes'), '${count('liked_keys')}');
    final mushaf = raw('mushaf_last_page');
    if (mushaf != null) {
      row(l('Mushaf son sayfa', 'Last mushaf page'), '$mushaf');
    }

    h(l('SENKRON', 'SYNC'));
    row(l('Son bulut yedeği', 'Last cloud backup'), dt(syncedAt));

    b.writeln(
        '\n${l('Bu, kişisel verilerinin bir kopyasıdır (KVKK/GDPR erişim hakkı).', 'This is a copy of your personal data (GDPR/KVKK right of access).')}');
    return b.toString();
  }

  /// Okunabilir özeti uygulama içinde gösterir; Paylaş + Ham JSON seçenekli.
  void _showDataSheet(BuildContext context, String readable, String jsonStr) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.shield_outlined, color: c.gold, size: 20),
                const Gap.sm(),
                Expanded(
                  child: Text('auth.exportData'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textTertiary)),
              ]),
              const Gap.sm(),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border),
                  ),
                  child: SingleChildScrollView(
                    controller: scroll,
                    child: SelectableText(readable,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5, color: c.textSecondary)),
                  ),
                ),
              ),
              const Gap.md(),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(
                        ShareParams(text: readable, subject: 'SELAYA — ${'auth.exportData'.tr()}')),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text('common.share'.tr()),
                  ),
                ),
                const Gap.sm(),
                OutlinedButton(
                  onPressed: () => SharePlus.instance.share(
                      ShareParams(text: jsonStr, subject: 'SELAYA — JSON')),
                  child: const Text('JSON'),
                ),
              ]),
              const Gap.sm(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final c = context.colors;
    final pwCtrl = TextEditingController();
    bool busy = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Future<void> run() async {
            if (pwCtrl.text.isEmpty) {
              setSt(() => err = 'auth.deletePwRequired'.tr());
              return;
            }
            setSt(() {
              busy = true;
              err = null;
            });
            try {
              await ref
                  .read(authControllerProvider.notifier)
                  .deleteAccount(pwCtrl.text);
              await ref.read(syncControllerProvider.notifier).resetLocal();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('auth.deleteDone'.tr())));
              }
            } on AuthException catch (e) {
              setSt(() {
                busy = false;
                err = e.code == 'wrong_password'
                    ? 'auth.deleteWrongPw'.tr()
                    : 'auth.deleteFailed'.tr();
              });
            } catch (_) {
              setSt(() {
                busy = false;
                err = 'auth.deleteFailed'.tr();
              });
            }
          }

          return AlertDialog(
            backgroundColor: c.surface,
            title: Text('auth.deleteAccount'.tr()),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('auth.deleteWarn'.tr(),
                  style: TextStyle(color: c.textSecondary, height: 1.4)),
              const Gap.md(),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: 'auth.password'.tr(),
                  errorText: err,
                ),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr())),
              FilledButton(
                onPressed: busy ? null : run,
                style: FilledButton.styleFrom(backgroundColor: c.danger),
                child: Text('auth.deleteConfirm'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  String _syncLabel(int ms) {
    if (ms == 0) return 'auth.syncNever'.tr();
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'auth.syncJustNow'.tr();
    if (d.inMinutes < 60) return 'auth.syncMinAgo'.tr(args: ['${d.inMinutes}']);
    if (d.inHours < 24) return 'auth.syncHourAgo'.tr(args: ['${d.inHours}']);
    return 'auth.syncDayAgo'.tr(args: ['${d.inDays}']);
  }

  void _showEditProfile(BuildContext context, WidgetRef ref) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditProfileSheet(name: user.name, surname: user.surname),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth.logout'.tr()),
        content: Text('auth.logoutConfirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('auth.logout'.tr())),
        ],
      ),
    );
    if (ok == true) {
      final sync = ref.read(syncControllerProvider.notifier);
      await sync.push(); // son değişiklikleri buluta kaydet (kaybolmasın)
      await sync.resetLocal(); // sonra yereli temizle → ilk ayarlara dön
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.pop();
    }
  }
}

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined,
                size: 64, color: c.textTertiary),
            const Gap.md(),
            Text('auth.guestDesc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary)),
            const Gap.lg(),
            FilledButton(
              onPressed: () => context.pushReplacement(Routes.auth),
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold, foregroundColor: c.bg),
              child: Text('auth.guestTitle'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Şifre değiştir alt sayfası — mevcut + yeni şifre.
class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();
  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  String _msg(String code) {
    const known = {
      'wrong_password', 'weak_password', 'network', 'unauthorized', 'bad_response'
    };
    return (known.contains(code) ? 'auth.err_$code' : 'auth.err_unknown').tr();
  }

  void _snack(String m) {
    if (!mounted) return;
    setState(() => _error = m); // ekranda kalıcı kırmızı uyarı
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    if (_old.text.isEmpty || _new.text.isEmpty) {
      _snack('auth.fillAll'.tr());
      return;
    }
    if (!isStrongPassword(_new.text)) {
      _snack('auth.err_weak_password'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthApi.changePassword(token, _old.text, _new.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
          SnackBar(content: Text('auth.passwordChanged'.tr())));
    } on AuthException catch (e) {
      _snack(_msg(e.code));
    } catch (_) {
      _snack(_msg('unknown'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl))),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: AppSpacing.xxxl,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill))),
            ),
            const Gap.md(),
            Text('auth.changePassword'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Gap.lg(),
            AuthErrorBanner(_error),
            _field(_old, 'auth.currentPassword'.tr()),
            const Gap.md(),
            _field(_new, 'auth.newPassword'.tr(), submit: true),
            const Gap.lg(),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg)),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2))
                    : Text('common.save'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const Gap.sm(),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool submit = false}) {
    final c = context.colors;
    return TextField(
      controller: ctrl,
      obscureText: _obscure,
      enabled: !_busy,
      textInputAction: submit ? TextInputAction.done : TextInputAction.next,
      onSubmitted: submit ? (_) => _submit() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: submit
            ? IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: c.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide(color: c.gold)),
      ),
    );
  }
}

/// Profil düzenle alt sayfası — ad/soyad.
class _EditProfileSheet extends ConsumerStatefulWidget {
  final String name, surname;
  const _EditProfileSheet({required this.name, required this.surname});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _surname = TextEditingController(text: widget.surname);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    if (_name.text.trim().isEmpty) {
      _snack('auth.err_name_required'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      final u = await AuthApi.updateProfile(
          token, _name.text.trim(), _surname.text.trim());
      await ref.read(authControllerProvider.notifier).updateUser(u);
      if (!mounted) return;
      Navigator.pop(context);
      _snack('auth.profileUpdated'.tr());
    } on AuthException catch (e) {
      _snack((e.code == 'network' ? 'auth.err_network' : 'auth.err_unknown').tr());
    } catch (_) {
      _snack('auth.err_unknown'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl))),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: AppSpacing.xxxl,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill))),
            ),
            const Gap.md(),
            Text('auth.editProfile'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Gap.lg(),
            _tf(_name, 'auth.name'.tr(), Icons.person_outline_rounded),
            const Gap.md(),
            _tf(_surname, 'auth.surname'.tr(), Icons.badge_outlined),
            const Gap.lg(),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.bg,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg)),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2))
                    : Text('common.save'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const Gap.sm(),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label, IconData icon) {
    final c = context.colors;
    return TextField(
      controller: ctrl,
      enabled: !_busy,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: c.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg, borderSide: BorderSide(color: c.gold)),
      ),
    );
  }
}
