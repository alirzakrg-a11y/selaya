import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_ai_icon.dart';
import '../../../core/widgets/selaya_scaffold.dart';

class _Msg {
  final bool user;
  final String text;
  final List<AiSource> sources;
  const _Msg(this.user, this.text, [this.sources = const []]);
}

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Türkçe karakterleri sadeleştir + küçült (eşleştirme için).
  static String _norm(String s) {
    const map = {
      'ı': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ç': 'c', 'Ç': 'c',
      'ğ': 'g', 'Ğ': 'g', 'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o',
      'â': 'a', 'î': 'i', 'û': 'u'
    };
    final sb = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static final _splitRe = RegExp(r'[^a-z0-9]+');

  /// Puanlı eşleştirme: soru (TR+EN) + anahtar kelimeler üzerinden EN İYİ cevabı
  /// seçer (ilk eşleşme değil). Eşik altındaysa null → yönlendirici mesaj.
  AiQa? _bestMatch(String text, List<AiQa> qa) {
    final qn = _norm(text);
    final words =
        qn.split(_splitRe).where((w) => w.length > 2).toSet();
    if (words.isEmpty) return null;
    AiQa? best;
    var bestScore = 0.0;
    for (final item in qa) {
      final hay = _norm(
          '${item.question('tr')} ${item.question('en')} ${item.keywords.join(' ')}');
      final hayTokens = hay.split(_splitRe).where((w) => w.length > 2).toSet();
      var score = 0.0;
      for (final w in words) {
        if (hayTokens.contains(w)) {
          score += 2; // tam kelime
        } else if (w.length > 4 && hay.contains(w)) {
          score += 1; // kısmi/kök
        }
      }
      if (qn.length > 5 && hay.contains(qn)) score += 4; // tam ifade bonusu
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 2 ? best : null;
  }

  /// Ana ekranda gösterilecek çeşitli/yaygın örnek sorular.
  List<AiQa> _exampleQuestions(List<AiQa> qa) {
    const ids = [
      'qa_namaz_how', 'qa_ghusl', 'qa_zakat', 'qa_hajj', 'qa_tawbah',
      'qa_dua_accept'
    ];
    final byId = {for (final q in qa) q.id: q};
    final out = [for (final id in ids) if (byId[id] != null) byId[id]!];
    for (final q in qa) {
      if (out.length >= 6) break;
      if (!out.contains(q)) out.add(q);
    }
    return out;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _ask(String text, List<AiQa> qa, String lang) {
    if (text.trim().isEmpty) return;
    final match = _bestMatch(text, qa);
    final fallback = lang == 'tr'
        ? 'Bunu tam çözemedim 🤲 Namaz, oruç, zekât, abdest/gusül, hac, Kur\'an, dua, helal-haram, ahlak gibi konularda sorabilirsin. Örn: "Gusül nasıl alınır?" ya da "Teheccüd namazı nedir?"'
        : 'I couldn\'t quite parse that 🤲 Ask about prayer, fasting, zakat, wudu/ghusl, hajj, Quran, dua, halal-haram, ethics, etc. e.g. "How is ghusl performed?"';
    setState(() {
      _messages.add(_Msg(true, text));
      _thinking = true;
    });
    _input.clear();
    _scrollDown();
    // Kısa "düşünme" gecikmesi → gerçek AI hissi (yazıyor göstergesi görünür).
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(match != null
            ? _Msg(false, match.answer(lang), match.sources)
            : _Msg(false, fallback));
      });
      _scrollDown();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.langCode;
    final c = context.colors;
    final qa = ref.watch(aiQaProvider).value ?? const <AiQa>[];

    return SelayaScaffold(
      title: 'ai.title'.tr(),
      showBack: true,
      body: Column(
        children: [
          _Disclaimer(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                _AiBubble(text: 'ai.greeting'.tr(), sources: const [])
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.08, end: 0, curve: Curves.easeOut),
                for (final m in _messages)
                  (m.user
                          ? _UserBubble(text: m.text)
                          : _AiBubble(text: m.text, sources: m.sources))
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideX(
                          begin: m.user ? 0.12 : -0.08,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOut),
                if (_thinking)
                  const _TypingBubble().animate().fadeIn(duration: 250.ms),
                if (_messages.isEmpty && !_thinking) ...[
                  const Gap.md(),
                  Text('ai.examples'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: c.textTertiary)),
                  const Gap.sm(),
                  for (final (i, q) in _exampleQuestions(qa).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ExampleChip(
                        label: q.question(lang),
                        onTap: () => _ask(q.question(lang), qa, lang),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (i * 80).ms, duration: 350.ms)
                        .slideX(begin: 0.12, end: 0, curve: Curves.easeOut),
                ],
              ],
            ),
          ),
          _InputBar(
            controller: _input,
            onSend: () => _ask(_input.text, qa, lang),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.info, size: 18, color: c.textTertiary),
          const Gap.sm(),
          Expanded(
            child: Text('ai.disclaimer'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.textTertiary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.xxxl),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c.goldGradient),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF1A1203), fontWeight: FontWeight.w600)),
      ),
    );
  }
}

IconData _sourceIcon(String type) {
  switch (type) {
    case 'quran':
      return Icons.menu_book_rounded;
    case 'hadith':
      return Icons.format_quote_rounded;
    default:
      return Icons.verified_rounded; // diyanet vb.
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  final List<AiSource> sources;
  const _AiBubble({required this.text, required this.sources});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md, right: AppSpacing.xxl),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedAiIcon(size: 18, color: c.accent),
                const Gap.xs(),
                Text('SELAYA AI',
                    style: TextStyle(
                        color: c.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
            const Gap.sm(),
            Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textPrimary, height: 1.5)),
            if (sources.isNotEmpty) ...[
              const Gap.sm(),
              Divider(height: 1, color: c.border),
              const Gap.sm(),
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 13, color: c.textTertiary),
                  const Gap.xs(),
                  Text('ai.sources'.tr().toUpperCase(),
                      style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                ],
              ),
              const Gap.xs(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in sources)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                          color: c.gold.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rSm,
                          border: Border.all(
                              color: c.gold.withValues(alpha: 0.3))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_sourceIcon(s.type), size: 12, color: c.gold),
                          const Gap.xs(),
                          Text('${'ai.${s.type}Ref'.tr()}: ${s.ref}',
                              style: TextStyle(
                                  color: c.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Yazıyor…" göstergesi — AI cevabı hazırlarken üç zıplayan nokta.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md, right: AppSpacing.xxl),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 14),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
              )
                  .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
                  .scaleXY(
                      begin: 0.5,
                      end: 1.0,
                      delay: (i * 180).ms,
                      duration: 500.ms,
                      curve: Curves.easeInOut),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExampleChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Icon(AppIcons.forward, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.base),
      color: c.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'ai.inputHint'.tr(),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
                border: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rLg,
                    borderSide: BorderSide(color: c.border)),
              ),
            ),
          ),
          const Gap.sm(),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.accentGradient),
              ),
              child: const Icon(AppIcons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
