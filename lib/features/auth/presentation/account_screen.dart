import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                const Gap.md(),
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: c.gold.withValues(alpha: 0.18),
                    child: Text(user.initials,
                        style: TextStyle(
                            color: c.gold,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                  ),
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
                const Gap.xs(),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showEditProfile(context, ref),
                    icon: Icon(Icons.edit_rounded, size: 16, color: c.gold),
                    label: Text('auth.editProfile'.tr(),
                        style: TextStyle(color: c.gold)),
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
              ],
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
