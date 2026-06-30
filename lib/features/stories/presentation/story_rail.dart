import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/content_providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/models/content.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image.dart';

/// Hikaye çemberi için canlı (deterministik) rastgele renk kombinasyonları —
/// hangi hikaye eklenirse eklensin otomatik renkli gradyan halka alır.
const _ringPalettes = <List<Color>>[
  [Color(0xFFFF6A3D), Color(0xFFFF2D78), Color(0xFF8A2BE2)],
  [Color(0xFF00C9A7), Color(0xFF2E86DE), Color(0xFF5F27CD)],
  [Color(0xFF26DE81), Color(0xFF00B894), Color(0xFF1DD1A1)],
  [Color(0xFFFF4757), Color(0xFFFF9F43), Color(0xFFFECA57)],
  [Color(0xFFEE5A9E), Color(0xFF9B59B6), Color(0xFF6C5CE7)],
  [Color(0xFF00D2FF), Color(0xFF3A7BD5), Color(0xFF6C5CE7)],
  [Color(0xFFFFD200), Color(0xFFFF8008), Color(0xFFFF2D78)],
  [Color(0xFF1DE9B6), Color(0xFF18FFFF), Color(0xFF2979FF)],
];

List<Color> _ringColors(String seed) {
  var h = 0;
  for (final code in seed.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return _ringPalettes[h % _ringPalettes.length];
}

/// Instagram-style horizontal story rail for the home screen.
class StoryRail extends ConsumerWidget {
  const StoryRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Şeritte EN FAZLA 5 hikâye — SABİT, yatay KAYDIRMA YOK. (Kaydırınca her
    // karede SweepGradient halkalar yeniden çiziliyordu → kasma/donma.) Bir
    // hikâyeye dokununca açılan tam ekran oynatıcı TÜM hikâyeleri gösterir;
    // kaydırma orada devam eder (StoryPlayer = full liste + startIndex).
    final stories = ref.watch(storiesProvider).value ?? const <Story>[];
    if (stories.isEmpty) return const SizedBox(height: 0);
    final lang = context.langCode;
    final shown = stories.length > 5 ? stories.sublist(0, 5) : stories;

    return SizedBox(
      height: 100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, s) in shown.indexed)
              Expanded(
                child: _StoryAvatar(
                  story: s,
                  label: s.title(lang),
                  onTap: () => context.push('${Routes.story}/$i'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final Story story;
  final String label;
  final VoidCallback onTap;
  const _StoryAvatar({required this.story, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ring = _ringColors(story.id);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // dilimdeki boşluk da tıklanabilir
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Renkli gradyan halka — STATİK (dönmez; akış animasyonu donma
                // yapıyordu, 2026-06-15). Şerit de artık kaydırılmıyor (kasma yok).
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [...ring, ring.first]),
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(2.5),
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: c.bg),
                  child: ClipOval(
                    child: AppImage.cdn(
                      story.cover,
                      fit: BoxFit.cover,
                      memWidth: 150, // 54px çembere tam-çözünürlük decode etme
                      fallbackColors: [
                        ring[0].withValues(alpha: 0.35),
                        ring[1].withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
