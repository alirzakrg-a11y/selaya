import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../prayer_times/data/prayer_repository.dart';

/// One day of forecast (WMO weather code + max/min °C).
class WeatherDay {
  final DateTime date;
  final int code;
  final double tMax;
  final double tMin;
  const WeatherDay(this.date, this.code, this.tMax, this.tMin);

  IconData get icon => _iconFor(code);
  String labelKey() => _labelKeyFor(code);
}

/// Free, key-less forecast from Open-Meteo (4 days for the selected city).
class WeatherService {
  const WeatherService();

  Future<List<WeatherDay>> forecast(double lat, double lng) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=auto&forecast_days=4');
    final res = await http
        .get(uri, headers: {'User-Agent': 'SELAYA/1.0 (prayer app)'}).timeout(
            const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('weather ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final daily = (j['daily'] as Map).cast<String, dynamic>();
    final times = (daily['time'] as List).cast<String>();
    final codes = daily['weather_code'] as List;
    final maxs = daily['temperature_2m_max'] as List;
    final mins = daily['temperature_2m_min'] as List;
    return [
      for (var i = 0; i < times.length; i++)
        WeatherDay(
          DateTime.parse(times[i]),
          (codes[i] as num).toInt(),
          (maxs[i] as num).toDouble(),
          (mins[i] as num).toDouble(),
        ),
    ];
  }
}

IconData _iconFor(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 3) return Icons.wb_cloudy_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 57) return Icons.grain_rounded;
  if (code >= 61 && code <= 67) return Icons.umbrella_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.grain_rounded;
  if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.wb_cloudy_rounded;
}

String _labelKeyFor(int code) {
  if (code == 0) return 'weather.clear';
  if (code <= 3) return 'weather.cloudy';
  if (code == 45 || code == 48) return 'weather.fog';
  if (code >= 51 && code <= 67) return 'weather.rain';
  if (code >= 71 && code <= 77) return 'weather.snow';
  if (code >= 80 && code <= 82) return 'weather.showers';
  if (code >= 85 && code <= 86) return 'weather.snow';
  if (code >= 95) return 'weather.thunder';
  return 'weather.cloudy';
}

final weatherServiceProvider =
    Provider<WeatherService>((ref) => const WeatherService());

/// 4-day forecast for the currently selected city.
final weatherForecastProvider = FutureProvider<List<WeatherDay>>((ref) async {
  final city = await ref.watch(selectedCityProvider.future);
  return ref.read(weatherServiceProvider).forecast(city.lat, city.lng);
});
