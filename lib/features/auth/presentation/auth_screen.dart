import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_logo.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/auth_api.dart';
import '../data/auth_controller.dart';
import '../data/sync_service.dart';
import '../domain/auth_validators.dart';
import 'auth_error_banner.dart';

/// Tek ekran: üstte Giriş / Üye Ol geçişi. Üye ol modunda ad/soyad da görünür.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _msg(String code) {
    const known = {
      'email_taken', 'invalid_email', 'weak_password',
      'invalid_credentials', 'name_required', 'network', 'bad_response',
      'too_many_attempts', 'name_profanity',
    };
    return (known.contains(code) ? 'auth.err_$code' : 'auth.err_unknown').tr();
  }

  void _snack(String m) {
    if (!mounted) return;
    setState(() => _error = m); // ekranda kalıcı kırmızı uyarı (snackbar değil)
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || pw.isEmpty || (_register && _name.text.trim().isEmpty)) {
      _snack('auth.fillAll'.tr());
      return;
    }
    if (!isValidEmail(email)) {
      _snack('auth.err_invalid_email'.tr());
      return;
    }
    if (_register && !isStrongPassword(pw)) {
      _snack('auth.err_weak_password'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      final ctrl = ref.read(authControllerProvider.notifier);
      if (_register) {
        await ctrl.register(
            name: _name.text.trim(),
            surname: _surname.text.trim(),
            email: email,
            password: pw);
      } else {
        await ctrl.login(email: email, password: pw);
      }
      // Giriş başarılı → verileri buluttan getir + birleştir (kendi hatasını yutar).
      await ref.read(syncControllerProvider.notifier).restore();
      if (!mounted) return;
      context.pushReplacement(Routes.account);
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
    return SelayaScaffold(
      title: 'auth.title'.tr(),
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          const Center(child: SelayaLogo(size: 72)),
          const Gap.lg(),
          _ModeToggle(
              register: _register,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        _register = v;
                        _error = null;
                      })),
          const Gap.lg(),
          AuthErrorBanner(_error),
          if (_register) ...[
            _field(_name, 'auth.name'.tr(), Icons.person_outline_rounded,
                action: TextInputAction.next),
            const Gap.md(),
            _field(_surname, 'auth.surname'.tr(), Icons.badge_outlined,
                action: TextInputAction.next),
            const Gap.md(),
          ],
          _field(_email, 'auth.email'.tr(), Icons.alternate_email_rounded,
              keyboard: TextInputType.emailAddress, action: TextInputAction.next),
          const Gap.md(),
          _field(_password, 'auth.password'.tr(), Icons.lock_outline_rounded,
              obscure: _obscure,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )),
          if (_register)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text('auth.pwHint'.tr(),
                  style: TextStyle(color: c.textTertiary, fontSize: 12)),
            ),
          if (!_register)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      _ForgotPasswordSheet(initialEmail: _email.text.trim()),
                ),
                child: Text('auth.forgot'.tr(), style: TextStyle(color: c.gold)),
              ),
            ),
          const Gap.md(),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.bg,
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.rLg)),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Text(
                      _register
                          ? 'auth.registerCta'.tr()
                          : 'auth.loginCta'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const Gap.md(),
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
              child: Text(
                  _register ? 'auth.haveAccount'.tr() : 'auth.noAccount'.tr(),
                  style: TextStyle(color: c.textSecondary)),
            ),
          ),
          const Gap.sm(),
          Text('auth.syncNote'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false,
      Widget? suffix,
      TextInputType? keyboard,
      TextInputAction? action,
      void Function(String)? onSubmitted}) {
    final c = context.colors;
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: action,
      onSubmitted: onSubmitted,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
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

class _ModeToggle extends StatelessWidget {
  final bool register;
  final ValueChanged<bool>? onChanged;
  const _ModeToggle({required this.register, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget seg(String label, bool isRegister) {
      final sel = register == isRegister;
      return Expanded(
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(isRegister),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: sel ? c.gold : Colors.transparent,
                borderRadius: AppRadius.rMd),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: sel ? c.bg : c.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration:
          BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadius.rLg),
      child: Row(children: [
        seg('auth.login'.tr(), false),
        seg('auth.register'.tr(), true),
      ]),
    );
  }
}

/// Şifremi unuttum — 2 adım: e-posta → kod gönder; sonra kod + yeni şifre.
class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordSheet({this.initialEmail = ''});
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _newPw = TextEditingController();
  int _step = 0; // 0 = e-posta, 1 = kod + yeni şifre
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPw.dispose();
    super.dispose();
  }

  String _msg(String code) {
    const known = {
      'email_not_configured', 'invalid_email', 'invalid_code',
      'weak_password', 'network', 'bad_response',
      'email_not_found', 'email_send_failed', 'too_soon',
    };
    return (known.contains(code) ? 'auth.err_$code' : 'auth.err_unknown').tr();
  }

  void _snack(String m) {
    if (!mounted) return;
    setState(() => _error = m); // ekranda kalıcı kırmızı uyarı (snackbar değil)
  }

  Future<void> _sendCode() async {
    setState(() => _error = null);
    final email = _email.text.trim();
    if (email.isEmpty) {
      _snack('auth.fillAll'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthApi.forgot(email);
      if (!mounted) return;
      // Adım 1'e geç — alt başlık zaten "kod gönderildi" der.
      setState(() {
        _step = 1;
        _error = null;
      });
    } on AuthException catch (e) {
      _snack(_msg(e.code));
    } catch (_) {
      _snack(_msg('unknown'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    if (_code.text.trim().isEmpty || _newPw.text.isEmpty) {
      _snack('auth.fillAll'.tr());
      return;
    }
    if (!isStrongPassword(_newPw.text)) {
      _snack('auth.err_weak_password'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthApi.reset(_email.text.trim(), _code.text.trim(), _newPw.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
          SnackBar(content: Text('auth.passwordReset'.tr())));
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const Gap.md(),
            Text('auth.forgotTitle'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Gap.sm(),
            Text(_step == 0 ? 'auth.forgotEmailHint'.tr() : 'auth.codeSent'.tr(),
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const Gap.lg(),
            AuthErrorBanner(_error),
            if (_step == 0) ...[
              _tf(_email, 'auth.email'.tr(), Icons.alternate_email_rounded,
                  keyboard: TextInputType.emailAddress),
              const Gap.lg(),
              _btn('auth.sendCode'.tr(), _sendCode),
            ] else ...[
              _tf(_code, 'auth.resetCode'.tr(), Icons.pin_rounded,
                  keyboard: TextInputType.number),
              const Gap.md(),
              _tf(_newPw, 'auth.newPassword'.tr(), Icons.lock_outline_rounded,
                  obscure: true),
              const Gap.lg(),
              _btn('auth.resetCta'.tr(), _reset),
            ],
            const Gap.sm(),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    final c = context.colors;
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: _busy ? null : onTap,
        style: FilledButton.styleFrom(
            backgroundColor: c.gold,
            foregroundColor: c.bg,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg)),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2))
            : Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboard}) {
    final c = context.colors;
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      enabled: !_busy,
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
