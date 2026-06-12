import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/cdn.dart';
import '../di/providers.dart';
import '../services/notification_service.dart';

/// Açılışta panelden gönderilen özel bildirimleri çeker ve daha önce
/// gösterilmemiş olanları yerel bildirim olarak gösterir. Görülenleri prefs'te
/// tutar. İlk çalıştırmada mevcut bildirimleri sessizce "görüldü" işaretler
/// (eski yığını basmamak için). Asla hata fırlatmaz.
final customNotificationsSyncProvider = FutureProvider<void>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final firstRun = !prefs.containsKey(PrefKeys.seenNotificationIds);
  try {
    final res = await http
        .get(Uri.parse('${SelayaCdn.apiBase}/v1/notifications'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];
    if (items.isEmpty) return;

    final seen = (prefs.getStringList(PrefKeys.seenNotificationIds) ?? <String>[]).toSet();
    final notif = ref.read(notificationServiceProvider);

    // API yeni->eski döner; eskiden yeniye göstermek için ters çevir.
    final ordered = items.whereType<Map>().toList().reversed;
    var shown = 0;
    for (final m in ordered) {
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty || seen.contains(id)) continue;
      if (!firstRun && shown < 5) {
        await notif.showCustom(
          id: 2000 + (id.hashCode.abs() % 90000),
          title: (m['title'] ?? '').toString(),
          body: (m['body'] ?? '').toString(),
        );
        shown++;
      }
      seen.add(id);
    }
    await prefs.setStringList(PrefKeys.seenNotificationIds, seen.toList());
  } catch (e) {
    if (kDebugMode) debugPrint('SELAYA custom notifications sync failed: $e');
  }
});
