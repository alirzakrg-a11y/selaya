import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../audio_stories/data/audio_handler.dart';

/// Kur'an ayet sesi arka planda indirilirken gösterilen ÇOK KÜÇÜK, ibadeti
/// BÖLMEYEN rozet (kullanıcı 2026-06-17). İndirme bitince kendiliğinden kaybolur
/// (yumuşak daralma); indirme yokken hiç yer kaplamaz. Statik ikon — dönen
/// animasyon yok (dikkat dağıtmasın + jank olmasın).
class QuranCachingBadge extends StatelessWidget {
  const QuranCachingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<bool>(
      valueListenable: quranCaching,
      builder: (_, downloading, _) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: !downloading
            ? const SizedBox(width: double.infinity)
            : Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 12,
                          color: c.gold.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'xt.qcbDownloadingAudio'.tr(),
                          style: TextStyle(
                            color: c.gold.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
