import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final stories = ref.watch(storiesProvider).value ?? const <Story>[];
    if (stories.isEmpty) return const SizedBox(height: 0);
    final lang = context.langCode;

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const Gap.md(),
        itemBuilder: (context, i) {
          final s = stories[i];
          return _StoryAvatar(
            story: s,
            label: s.title(lang),
            onTap: () => context.push('${Routes.story}/$i'),
          );
        },
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
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dönen renkli gradyan halka — Instagram gibi sürekli döner.
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [...ring, ring.first]),
                    ),
                  )
                      .animate(onPlay: (ctrl) => ctrl.repeat())
                      .rotate(begin: 0, end: 1, duration: 6000.ms),
                  // Avatar — sabit (dönmez).
                  Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(2.5),
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: c.bg),
                    child: ClipOval(
                      child: AppImage.cdn(
                        story.cover,
                        fit: BoxFit.cover,
                        // 62px avatar — küçük decode (RAM + ilk kaydırma jank'ı).
                        memWidth: 160,
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
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
