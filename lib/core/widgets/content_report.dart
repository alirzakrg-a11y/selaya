import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/cdn.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Yönetici/iletişim e-postası (telif talepleri + doğrudan iletişim buraya gelir).
const String _adminEmail = 'alirza.krg@gmail.com';

/// İçerik şikayeti (Bildir) — duvar kâğıdı/video/ses/ayet vb. için ortak akış.
/// Anonim: sunucu IP-dedup + rate-limit uygular. [key] = "type:id" (beğeni
/// anahtarıyla aynı biçim), böylece panelde içerik tanınır.
Future<void> showContentReport(
  BuildContext context, {
  required String key,
  String? type,
  String? title,
}) async {
  final c = context.colors;
  final reasons = <(String, String)>[
    ('inappropriate', 'report.inappropriate'.tr()),
    ('broken', 'report.broken'.tr()),
    ('wrong', 'report.wrong'.tr()),
    ('copyright', 'report.copyright'.tr()),
    ('other', 'report.other'.tr()),
  ];
  await showModalBottomSheet(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag_outlined, color: c.gold, size: 20),
              const Gap.sm(),
              Expanded(
                child: Text('report.title'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const Gap.sm(),
            for (final r in reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.$2),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final ok = await _send(
                      key: key, type: type, title: title, reason: r.$1);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            (ok ? 'report.thanks' : 'report.failed').tr())));
                  }
                },
              ),
            const Divider(height: 22),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.mail_outline_rounded, color: c.gold),
              title: Text('report.email'.tr()),
              subtitle: Text(_adminEmail,
                  style: TextStyle(color: c.textTertiary, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _email(context, key: key, title: title);
              },
            ),
            const Gap.sm(),
          ],
        ),
      ),
    ),
  );
}

/// Telif/iletişim için e-posta uygulamasını aç (mailto). Sunucu gerektirmez →
/// worker deploy edilmese de çalışır.
Future<void> _email(BuildContext context,
    {required String key, String? title}) async {
  final subject =
      Uri.encodeComponent('SELAYA — İçerik bildirimi / Content report');
  final body = Uri.encodeComponent(
      'İçerik / Content: ${title ?? ''}  ($key)\n\nMesajınız / Your message:\n');
  final uri = Uri.parse('mailto:$_adminEmail?subject=$subject&body=$body');
  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  // E-posta uygulaması yoksa/açılmazsa: adresi panoya kopyala + bilgilendir.
  if (!ok) {
    await Clipboard.setData(const ClipboardData(text: _adminEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('report.emailCopied'.tr())));
    }
  }
}

Future<bool> _send({
  required String key,
  String? type,
  String? title,
  required String reason,
}) async {
  try {
    final res = await http
        .post(
          Uri.parse('${SelayaCdn.apiBase}/v1/report'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'key': key,
            'type': type ?? '',
            'title': title ?? '',
            'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
