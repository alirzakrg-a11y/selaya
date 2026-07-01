import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/geometric_background.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_logo.dart';
import '../data/purchase_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String _selected = PremiumIds.yearly;

  // Sadece "reklamsız deneyim" (kullanıcı: premium yalnız reklam kaldırma).
  static const _features = [
    (AppIcons.close, 'premium.featureAdfree'),
  ];

  // Mağaza fiyatı yüklenene kadar yedek (gerçek fiyat Play Console'dan gelir).
  static const _fallbackPrice = {
    PremiumIds.monthly: '₺119,99',
    PremiumIds.yearly: '₺799,99',
    PremiumIds.lifetime: '₺1.999,99',
  };

  // "Premium aktif" — yeni çeviri anahtarı eklememek için dil-kodu haritası.
  static String _activeLabel(String lang) {
    const m = {
      'tr': 'Premium aktif ✓',
      'en': 'Premium active ✓',
      'ar': 'العضوية المميزة مُفعّلة ✓',
      'de': 'Premium aktiv ✓',
      'id': 'Premium aktif ✓',
      'fr': 'Premium actif ✓',
      'ur': 'پریمیم فعال ✓',
      'bn': 'প্রিমিয়াম সক্রিয় ✓',
      'fa': 'پریمیوم فعال ✓',
      'ru': 'Премиум активен ✓',
    };
    return m[lang] ?? m['en']!;
  }

  // "Ömür boyu" / "tek seferlik" — yeni çeviri anahtarı eklememek için harita.
  static String _lifetimeLabel(String lang) {
    const m = {
      'tr': 'Ömür boyu',
      'en': 'Lifetime',
      'ar': 'مدى الحياة',
      'de': 'Lebenslang',
      'id': 'Seumur hidup',
      'fr': 'À vie',
      'ur': 'تاحیات',
      'bn': 'আজীবন',
      'fa': 'مادام‌العمر',
      'ru': 'Навсегда',
    };
    return m[lang] ?? m['en']!;
  }

  static String _onceLabel(String lang) {
    const m = {
      'tr': 'tek seferlik',
      'en': 'one-time',
      'ar': 'دفعة واحدة',
      'de': 'einmalig',
      'id': 'sekali bayar',
      'fr': 'paiement unique',
      'ur': 'ایک بار',
      'bn': 'এককালীন',
      'fa': 'یک‌بار',
      'ru': 'разовый',
    };
    return m[lang] ?? m['en']!;
  }

  // "Daha önce satın aldım" (geri yükle) — net etiket.
  static String _restoreLabel(String lang) {
    const m = {
      'tr': 'Daha önce satın aldım',
      'en': 'I already purchased',
      'ar': 'لقد اشتريت بالفعل',
      'de': 'Bereits gekauft',
      'id': 'Sudah pernah beli',
      'fr': 'Déjà acheté',
      'ur': 'میں پہلے خرید چکا ہوں',
      'bn': 'আগেই কিনেছি',
      'fa': 'قبلاً خریده‌ام',
      'ru': 'Уже куплено',
    };
    return m[lang] ?? m['en']!;
  }

  // "Aboneliği yönet / iptal et" — Play abonelik sayfasını açar.
  static String _manageLabel(String lang) {
    const m = {
      'tr': 'Aboneliği yönet / iptal et',
      'en': 'Manage / cancel subscription',
      'ar': 'إدارة / إلغاء الاشتراك',
      'de': 'Abo verwalten / kündigen',
      'id': 'Kelola / batalkan langganan',
      'fr': "Gérer / annuler l'abonnement",
      'ur': 'سبسکرپشن منظم / منسوخ کریں',
      'bn': 'সাবস্ক্রিপশন পরিচালনা / বাতিল',
      'fa': 'مدیریت / لغو اشتراک',
      'ru': 'Управление / отмена подписки',
    };
    return m[lang] ?? m['en']!;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.locale.languageCode;
    final purchase = ref.watch(purchaseProvider);
    final ctrl = ref.read(purchaseProvider.notifier);

    // Satın alma hatasını bir kez snackbar ile bildir.
    ref.listen(purchaseProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) _snack(next.error!);
    });

    final yearly = purchase.byId(PremiumIds.yearly);
    final monthly = purchase.byId(PremiumIds.monthly);
    final lifetime = purchase.byId(PremiumIds.lifetime);

    return Scaffold(
      backgroundColor: c.bg,
      body: GeometricBackground(
        glowColor: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(AppIcons.close, color: c.textPrimary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: AppSpacing.screen,
                  children: [
                    const Gap.md(),
                    Center(child: const SelayaLogo(size: 64, showWordmark: false)),
                    const Gap.md(),
                    Center(
                      child: ShaderMask(
                        shaderCallback: (r) =>
                            const LinearGradient(colors: AppColors.goldGradient)
                                .createShader(r),
                        child: Text('premium.title'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(color: Colors.white)),
                      ),
                    ),
                    const Gap.xs(),
                    Center(
                      child: Text('premium.subtitle'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary)),
                    ),
                    const Gap.xl(),
                    SelayaCard(
                      child: Column(
                        children: [
                          for (final f in _features) ...[
                            if (f != _features.first)
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: c.border.withValues(alpha: 0.5)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.gold.withValues(alpha: 0.14),
                                    ),
                                    child: Icon(f.$1, color: c.gold, size: 18),
                                  ),
                                  const Gap.md(),
                                  Expanded(
                                      child: Text(f.$2.tr(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall)),
                                  Icon(AppIcons.checkCircle, color: c.success, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Gap.lg(),
                    _PlanTile(
                      label: 'premium.yearly'.tr(),
                      price: yearly?.price ?? _fallbackPrice[PremiumIds.yearly]!,
                      per: 'premium.perYear'.tr(),
                      badge: 'premium.bestValue'.tr(),
                      selected: _selected == PremiumIds.yearly,
                      onTap: () => setState(() => _selected = PremiumIds.yearly),
                    ),
                    const Gap.sm(),
                    _PlanTile(
                      label: 'premium.monthly'.tr(),
                      price: monthly?.price ?? _fallbackPrice[PremiumIds.monthly]!,
                      per: 'premium.perMonth'.tr(),
                      selected: _selected == PremiumIds.monthly,
                      onTap: () => setState(() => _selected = PremiumIds.monthly),
                    ),
                    const Gap.sm(),
                    _PlanTile(
                      label: _lifetimeLabel(lang),
                      price: lifetime?.price ??
                          _fallbackPrice[PremiumIds.lifetime]!,
                      per: _onceLabel(lang),
                      selected: _selected == PremiumIds.lifetime,
                      onTap: () =>
                          setState(() => _selected = PremiumIds.lifetime),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppSpacing.screen,
                child: Column(
                  children: [
                    if (purchase.isPremium)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: c.success.withValues(alpha: 0.14),
                          borderRadius: AppRadius.rLg,
                          border: Border.all(
                              color: c.success.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(_activeLabel(lang),
                              style: TextStyle(
                                  color: c.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                        ),
                      )
                    else ...[
                      if (purchase.purchasePending)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        )
                      else
                        GradientButton(
                          label: 'premium.subscribe'.tr(),
                          icon: AppIcons.crown,
                          expand: true,
                          onPressed: () {
                            final p = purchase.byId(_selected);
                            if (p == null) {
                              _snack('common.comingSoon'.tr());
                              return;
                            }
                            ctrl.buy(p);
                          },
                        ),
                      TextButton(
                        onPressed: () {
                          ctrl.restore();
                          _snack(lang == 'tr'
                              ? 'Önceki satın alımların kontrol ediliyor…'
                              : 'Checking previous purchases…');
                        },
                        child: Text(_restoreLabel(lang),
                            style: TextStyle(color: c.textTertiary)),
                      ),
                    ],
                    // Aboneliği Play'den yönet / iptal et — HER ZAMAN tıklanabilir
                    // (Play abonelik iptalini kendi sayfasından yaptırır).
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                            'https://play.google.com/store/account/subscriptions'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: Icon(Icons.open_in_new_rounded,
                          size: 15, color: c.textTertiary),
                      label: Text(_manageLabel(lang),
                          style: TextStyle(
                              color: c.textTertiary, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String label;
  final String price;
  final String per;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  const _PlanTile({
    required this.label,
    required this.price,
    required this.per,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: selected ? c.gold.withValues(alpha: 0.12) : c.surfaceAlt,
          borderRadius: AppRadius.rLg,
          border: Border.all(
              color: selected ? c.gold : c.border, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.gold.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(selected ? AppIcons.checkCircle : Icons.circle_outlined,
                color: selected ? c.gold : c.textTertiary),
            const Gap.md(),
            Expanded(
              child: Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  if (badge != null) ...[
                    const Gap.sm(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                          color: c.gold, borderRadius: AppRadius.rSm),
                      child: Text(badge!,
                          style: TextStyle(
                              color: c.onGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: Theme.of(context).textTheme.titleMedium),
                Text(per,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
