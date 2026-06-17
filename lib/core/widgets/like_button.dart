import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/likes_service.dart';
import '../theme/app_colors.dart';

/// Sunucu destekli beğeni butonu: kalp + sayı. Dokununca beğenir (+1); dolu
/// kalbe tekrar dokununca beğeniyi geri alır (−1). Gösterilen sayı = sabit taban
/// + sunucudaki gerçek beğeniler + yerel beğeni.
/// [light] = koyu görsel/arka plan üzerinde beyaz görünüm.
class LikeButton extends ConsumerWidget {
  final String likeKey;
  final bool light;
  const LikeButton({super.key, required this.likeKey, this.light = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedKeysProvider).contains(likeKey);
    final server = ref.watch(likesProvider).asData?.value[likeKey] ?? 0;
    // Deterministik rastgele taban + sunucudaki gerçek beğeniler + yerel beğeni.
    final count = likeSeed(likeKey) + server + (liked ? 1 : 0);
    final c = context.colors;
    final fg = light ? Colors.white : c.textSecondary;
    return InkWell(
      // Çift yönlü: dolu kalbe tekrar dokununca beğeni geri alınır (panelde −1).
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(likedKeysProvider.notifier).toggle(likeKey);
      },
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: liked ? const Color(0xFFE57373) : fg,
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
