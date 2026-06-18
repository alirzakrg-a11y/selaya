import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/cdn.dart';

/// Canlı finans verisi: gram altın (₺) + Diyanet fitre. SELAYA Worker'ı
/// (`/v1/finance`) kaynağı çekip 30 dk edge cache'ler → uygulama her açılışta
/// güncel değeri alır, kaynağı yormaz.
class Finance {
  final double goldGram; // ₺/gram (gram altın satış)
  final String goldSource;
  final String goldUpdated;
  final double fitre; // ₺/kişi
  final String fitreYear;
  final String fitreSource;
  const Finance({
    required this.goldGram,
    required this.goldSource,
    required this.goldUpdated,
    required this.fitre,
    required this.fitreYear,
    required this.fitreSource,
  });
  factory Finance.fromJson(Map<String, dynamic> j) => Finance(
        goldGram: (j['goldGram'] as num?)?.toDouble() ?? 0,
        goldSource: (j['goldSource'] ?? '').toString(),
        goldUpdated: (j['goldUpdated'] ?? '').toString(),
        fitre: (j['fitre'] as num?)?.toDouble() ?? 0,
        fitreYear: (j['fitreYear'] ?? '').toString(),
        fitreSource: (j['fitreSource'] ?? '').toString(),
      );
}

class FinanceApi {
  static Future<Finance?> fetch() async {
    try {
      final res = await http
          .get(Uri.parse('${SelayaCdn.apiBase}/v1/finance'))
          .timeout(const Duration(seconds: 12));
      final d = (jsonDecode(res.body) as Map).cast<String, dynamic>();
      if (res.statusCode == 200 && d['ok'] == true) {
        return Finance.fromJson(d);
      }
    } catch (_) {}
    return null;
  }
}
