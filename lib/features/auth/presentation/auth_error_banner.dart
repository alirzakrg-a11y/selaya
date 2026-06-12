import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Tüm auth formlarının ORTAK hata uyarısı. message null/boş ise hiçbir şey
/// göstermez; doluysa kalıcı, görünür kırmızı banner çizer (snackbar gibi kaçmaz).
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null || m.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.12),
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
          const Gap.sm(),
          Expanded(
            child: Text(m,
                style: TextStyle(
                    color: c.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3)),
          ),
        ],
      ),
    );
  }
}
