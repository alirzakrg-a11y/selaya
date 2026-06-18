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

  @override
  Widget build(BuildContext context) {
    final tr = context.langCode == 'tr';
    return SelayaScaffold(
      title: 'zakat.title'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: tr ? 'Güncel fiyatı yenile' : 'Refresh live price',
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
                label: Text(tr ? 'Zekât' : 'Zakat'),
                icon: const Icon(Icons.payments_rounded, size: 18),
              ),
              ButtonSegment(
                value: 'fitre',
                label: Text(tr ? 'Fitre' : 'Fitra'),
                icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
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
        tr ? 'Güncel altın gram fiyatı (₺)' : 'Current gold price /gram (₺)',
        Icons.sell_rounded,
      ),
      _field(
        _cash,
        tr ? 'Nakit + banka (₺)' : 'Cash + bank (₺)',
        Icons.account_balance_wallet_rounded,
      ),
      _field(
        _goldGram,
        tr ? 'Altın (gram)' : 'Gold (grams)',
        Icons.workspace_premium_rounded,
      ),
      _field(
        _trade,
        tr ? 'Ticari mal / yatırım (₺)' : 'Trade goods / investment (₺)',
        Icons.storefront_rounded,
      ),
      _field(
        _debt,
        tr ? 'Borçlar (₺)' : 'Debts (₺)',
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
              tr ? 'Zekâta tâbi toplam' : 'Total zakatable',
              _money(context, total),
            ),
            _row(
              context,
              tr ? 'Nisap (80,18 gr altın)' : 'Nisab (80.18g gold)',
              price > 0 ? _money(context, nisab) : '—',
            ),
            const Divider(height: 18),
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
                        ? (tr
                              ? 'Hesaplamak için altın gram fiyatını gir.'
                              : 'Enter the gold price to calculate.')
                        : due
                        ? (tr ? 'Zekât farz' : 'Zakat is due')
                        : (tr
                              ? 'Nisabın altında — zekât gerekmez'
                              : 'Below nisab — no zakat'),
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
                tr ? 'Vereceğin zekât (%2,5)' : 'Your zakat (2.5%)',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: c.textSecondary),
              ),
              Text(
                _money(context, zakat),
                style: TextStyle(
                  color: c.gold,
                  fontSize: 30,
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
        tr
            ? 'Zekât; bir kameri yıl boyunca elde tutulan, ihtiyaç fazlası mala düşer. Bu hesap tahminîdir — kesin hüküm için müftülüğe danış.'
            : 'Zakat applies to surplus wealth held for one lunar year. This is an estimate — consult a scholar for a ruling.',
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
                ? (tr ? 'Güncel altın fiyatı alınıyor…' : 'Fetching live gold price…')
                : (tr
                    ? 'Canlı fiyat alınamadı — altın gram fiyatını elle girebilirsin.'
                    : 'Live price unavailable — enter the gold price manually.')),
      ),
    ];
  }

  // ---------------- FİTRE ----------------
  List<Widget> _fitre(BuildContext context, bool tr) {
    final total = _v(_fitrePer) * _v(_fitreCount);
    return [
      _field(
        _fitrePer,
        tr ? 'Kişi başı fitre (₺)' : 'Fitra per person (₺)',
        Icons.person_rounded,
      ),
      _field(
        _fitreCount,
        tr ? 'Kişi sayısı' : 'Number of people',
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
              tr ? 'Toplam fitre' : 'Total fitra',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _money(context, total),
              style: TextStyle(
                color: context.colors.gold,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const Gap.md(),
      _note(
        context,
        tr
            ? 'Fıtır sadakası, bayram namazından önce verilir. Kişi başı miktar Diyanet’in açıkladığı güncel tutardır (yaklaşık bir günlük yemek bedeli); istersen değiştirebilirsin.'
            : 'Fitra is given before the Eid prayer. The per-person amount is Diyanet’s current figure; you can edit it.',
      ),
      const Gap.sm(),
      _sourceLine(
        context,
        _fin != null && _fin!.fitre > 0
            ? (tr
                ? 'Kişi başı fitre: ${_fmt(_fin!.fitre)} ₺ · kaynak: ${_fin!.fitreSource} (${_fin!.fitreYear})'
                : 'Per person: ${_fmt(_fin!.fitre)} ₺ · source: ${_fin!.fitreSource} (${_fin!.fitreYear})')
            : (_loadingFin
                ? (tr ? 'Güncel fitre alınıyor…' : 'Fetching current fitra…')
                : (tr
                    ? 'Güncel fitre alınamadı — kişi başı tutarı elle girebilirsin.'
                    : 'Could not fetch fitra — enter the amount manually.')),
      ),
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
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
}
