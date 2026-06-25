import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/thousands_formatter.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';
import '../data/finance_api.dart';
import '../data/zakat_info.dart';

/// Zekât + Fitre hesaplayıcı. Zekât nisabı = 80.18 gr altın değeri; oran %2,5
/// (1/40). Yalnız tahminî yardımcıdır — kesin hüküm için müftülüğe danışılır.
class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  String _mode = 'zakat';

  // Zekât girişleri
  final _gold = TextEditingController(); // altın gram fiyatı (₺)
  final _cash = TextEditingController(); // nakit + banka
  final _goldGram = TextEditingController(); // altın (gram)
  final _trade = TextEditingController(); // ticari mal / yatırım
  final _debt = TextEditingController(); // borçlar

  // Fitre girişleri
  final _fitrePer = TextEditingController(); // kişi başı fitre (₺)
  final _fitreCount = TextEditingController(text: '1'); // kişi sayısı

  static const _nisabGoldGram = 80.18; // 20 miskal

  Finance? _fin; // canlı altın + Diyanet fitre
  bool _loadingFin = true;

  @override
  void initState() {
    super.initState();
    _loadFinance(); // her açılışta güncel altın + fitre çek
  }

  /// Canlı gram altın + Diyanet fitresini çek; boş alanları otomatik doldur.
  Future<void> _loadFinance({bool force = false}) async {
    setState(() => _loadingFin = true);
    final f = await FinanceApi.fetch();
    if (!mounted) return;
    setState(() {
      _fin = f;
      _loadingFin = false;
      if (f != null) {
        // Altın fiyatı: boşsa (ya da elle yenilemede) güncel değeri yaz (₺, 2 ondalık).
        if (force || _gold.text.trim().isEmpty) {
          _gold.text = _fmt(f.goldGram);
        }
        if (force || _fitrePer.text.trim().isEmpty) {
          _fitrePer.text = _fmt(f.fitre);
        }
      }
    });
  }

  // Alan dolgusu: 6337.57 → "6.337,57" (binlik nokta + ondalık virgül; canlı
  // biçimlendiriciyle ve _v ayrıştırıcısıyla uyumlu).
  String _fmt(double v) => NumberFormat.decimalPattern('tr')
      .format(double.parse(v.toStringAsFixed(2)));

  double _v(TextEditingController c) => parseTrNumber(c.text);

  @override
  void dispose() {
    for (final c in [
      _gold,
      _cash,
      _goldGram,
      _trade,
      _debt,
      _fitrePer,
      _fitreCount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _money(BuildContext context, double v) =>
      '${NumberFormat.decimalPattern(context.locale.languageCode).format(double.parse(v.toStringAsFixed(2)))} ₺';

  /// Zekât & fitre özet rehberi (AppBar bilgi butonundan).
  void _showZakatInfo() {
    final c = context.colors;
    final lang = context.langCode;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.95,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(children: [
                Icon(Icons.payments_rounded, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text('xt.zkGuideTitle'.tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ]),
              const Gap.lg(),
              for (final item in zakatInfo) ...[
                Text(item.title(lang),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.gold, fontWeight: FontWeight.w800)),
                const Gap.xs(),
                Text(item.desc(lang),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary, height: 1.5)),
                const Gap.md(),
              ],
              Row(children: [
                Icon(Icons.menu_book_rounded, size: 16, color: c.gold),
                const Gap.sm(),
                Expanded(
                  child: Text(
                      'xt.zkGuideSource'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textTertiary)),
                ),
              ]),
              const Gap.sm(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    return SelayaScaffold(
      title: 'zakat.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'xt.zkGuideTooltip'.tr(),
          icon: Icon(Icons.info_outline_rounded, color: context.colors.gold),
          onPressed: _showZakatInfo,
        ),
        IconButton(
          tooltip: 'xt.zkRefreshTooltip'.tr(),
          icon: _loadingFin
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.refresh_rounded, color: context.colors.gold),
          onPressed: _loadingFin ? null : () => _loadFinance(force: true),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.xxxl,
        ),
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'zakat',
                label: Text('xt.zkSegZakat'.tr()),
                icon: const Icon(Icons.payments_rounded, size: 18),
              ),
              ButtonSegment(
                value: 'fitre',
                label: Text('xt.zkSegFitra'.tr()),
                icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const Gap.md(),
          _privacyNote(context, tr),
          const Gap.md(),
          if (_mode == 'zakat')
            ..._zakat(context, tr)
          else
            ..._fitre(context, tr),
        ],
      ),
    );
  }

  // ---------------- ZEKÂT ----------------
  List<Widget> _zakat(BuildContext context, bool tr) {
    final c = context.colors;
    final price = _v(_gold);
    final goldVal = _v(_goldGram) * price;
    final total = (_v(_cash) + goldVal + _v(_trade) - _v(_debt)).clamp(
      0.0,
      double.infinity,
    );
    final nisab = _nisabGoldGram * price;
    final due = nisab > 0 && total >= nisab;
    final zakat = due ? total * 0.025 : 0.0;

    return [
      _field(
        _gold,
        'xt.zkFieldGoldPrice'.tr(),
        Icons.sell_rounded,
      ),
      _field(
        _cash,
        'xt.zkFieldCashBank'.tr(),
        Icons.account_balance_wallet_rounded,
      ),
      _field(
        _goldGram,
        'xt.zkFieldGoldGram'.tr(),
        Icons.workspace_premium_rounded,
      ),
      _field(
        _trade,
        'xt.zkFieldTrade'.tr(),
        Icons.storefront_rounded,
      ),
      _field(
        _debt,
        'xt.zkFieldDebts'.tr(),
        Icons.remove_circle_outline_rounded,
      ),
      const Gap.md(),
      SelayaCard(
        gradient: LinearGradient(
          colors: [c.gold.withValues(alpha: 0.18), c.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              context,
              'xt.zkTotalZakatable'.tr(),
              _money(context, total),
            ),
            _row(
              context,
              'xt.zkNisabLabel'.tr(),
              price > 0 ? _money(context, nisab) : '—',
            ),
            Divider(height: 18, color: c.border),
            Row(
              children: [
                Icon(
                  due ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: due ? c.gold : c.textTertiary,
                  size: 20,
                ),
                const Gap.sm(),
                Expanded(
                  child: Text(
                    price <= 0
                        ? 'xt.zkEnterGoldPrice'.tr()
                        : due
                        ? 'xt.zkZakatDue'.tr()
                        : 'xt.zkBelowNisab'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: due ? c.gold : c.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (due) ...[
              const Gap.sm(),
              Text(
                'xt.zkYourZakat'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: c.textSecondary),
              ),
              Text(
                _money(context, zakat),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: c.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
      const Gap.md(),
      _note(
        context,
        'xt.zkZakatNote'.tr(),
      ),
      const Gap.sm(),
      _sourceLine(
        context,
        _fin != null && _fin!.goldGram > 0
            ? (tr
                ? 'Gram altın: ${_fmt(_fin!.goldGram)} ₺ · kaynak: ${_fin!.goldSource}'
                    '${_fin!.goldUpdated.isNotEmpty ? ' · ${_fin!.goldUpdated}' : ''}'
                : 'Gold/gram: ${_fmt(_fin!.goldGram)} ₺ · source: ${_fin!.goldSource}')
            : (_loadingFin
                ? 'xt.zkFetchingGold'.tr()
                : 'xt.zkGoldUnavailable'.tr()),
      ),
      const Gap.md(),
      _sourceNote(context),
    ];
  }

  // ---------------- FİTRE ----------------
  List<Widget> _fitre(BuildContext context, bool tr) {
    final total = _v(_fitrePer) * _v(_fitreCount);
    return [
      _field(
        _fitrePer,
        'xt.zkFieldFitraPerPerson'.tr(),
        Icons.person_rounded,
      ),
      _field(
        _fitreCount,
        'xt.zkFieldPeopleCount'.tr(),
        Icons.groups_rounded,
        money: false,
      ),
      const Gap.md(),
      SelayaCard(
        gradient: LinearGradient(
          colors: [
            context.colors.gold.withValues(alpha: 0.18),
            context.colors.surfaceAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'xt.zkTotalFitra'.tr(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const Gap.xs(),
            Text(
              _money(context, total),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: context.colors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const Gap.md(),
      _note(
        context,
        'xt.zkFitraNote'.tr(),
      ),
      const Gap.sm(),
      _sourceLine(
        context,
        _fin != null && _fin!.fitre > 0
            ? 'xt.zkFitraSourceLine'.tr(args: [
                _fmt(_fin!.fitre),
                _fin!.fitreSource,
                _fin!.fitreYear.toString(),
              ])
            : (_loadingFin
                ? 'xt.zkFetchingFitra'.tr()
                : 'xt.zkFitraUnavailable'.tr()),
      ),
      const Gap.md(),
      _sourceNote(context),
    ];
  }

  // ---------------- ortak parçalar ----------------
  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool money = true}) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: money),
        // Para alanları: yazarken canlı binlik ayraç (1.234.567,89). Kişi
        // sayısı: sadece tam sayı.
        inputFormatters: money
            ? const [TrThousandsFormatter()]
            : [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: c.textTertiary, size: 20),
          isDense: true,
          filled: true,
          fillColor: c.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: AppRadius.rLg,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg,
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rLg,
            borderSide: BorderSide(color: c.gold, width: 1.4),
          ),
        ),
      ),
    );
  }

  /// Gizlilik notu — girilen mal varlığı bilgileri cihazda kalır, kaydedilmez
  /// veya senkronlanmaz (hesaba/buluta gitmez).
  Widget _privacyNote(BuildContext context, bool tr) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: c.gold),
          const Gap.sm(),
          Expanded(
            child: Text(
              'xt.zkPrivacyNote'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Veri kaynağı satırı (en altta: altın fiyatı/fitre nereden geldi).
  Widget _sourceLine(BuildContext context, String text) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.public_rounded,
            size: 14, color: c.gold.withValues(alpha: 0.7)),
        const Gap.sm(),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.textTertiary, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _note(BuildContext context, String text) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline_rounded, size: 16, color: c.textTertiary),
        const Gap.sm(),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.textTertiary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  /// Dini hüküm kaynağı uyarısı (gold-tint kutu).
  Widget _sourceNote(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.08),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: c.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.menu_book_rounded, size: 18, color: c.gold),
          const Gap.sm(),
          Expanded(
            child: Text(
              'xt.zkSourceNote'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
