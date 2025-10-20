import 'dart:convert';
import 'dart:html' as html;
import 'ml_service.dart';

class DataRepository {
  static const _trainingKey = 'watts_energy_training_v1';
  static const _forecastKey = 'watts_energy_forecast_v1';

  // ---- Training data persistence ----
  static Future<void> save(List<PowerDataPoint> data) async {
    try {
      final jsonList = data
          .map((e) => {
                'ts': e.timestamp.toIso8601String(),
                'y': e.consumption,
              })
          .toList();
      html.window.localStorage[_trainingKey] = jsonEncode({'points': jsonList});
    } catch (_) {
      // ignore
    }
  }

  static Future<List<PowerDataPoint>> load() async {
    try {
      final txt = html.window.localStorage[_trainingKey];
      if (txt == null || txt.isEmpty) return [];
      final map = jsonDecode(txt) as Map<String, dynamic>;
      final pts = (map['points'] as List)
          .map((m) => PowerDataPoint(DateTime.parse(m['ts']), (m['y'] as num).toDouble()))
          .toList();
      pts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return pts;
    } catch (_) {
      return [];
    }
  }

  static Future<List<PowerDataPoint>> mergeAndSave(List<PowerDataPoint> newData) async {
    final existing = await load();
    final map = <int, PowerDataPoint>{};
    for (final p in existing) {
      map[p.timestamp.millisecondsSinceEpoch] = p;
    }
    for (final p in newData) {
      map[p.timestamp.millisecondsSinceEpoch] = p;
    }
    final merged = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await save(merged);
    return merged;
  }

  static Future<List<PowerDataPoint>> mergeWithSaved(List<PowerDataPoint> newData) async {
    final existing = await load();
    if (existing.isEmpty) {
      final copy = [...newData]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return copy;
    }
    final map = <int, PowerDataPoint>{};
    for (final p in existing) {
      map[p.timestamp.millisecondsSinceEpoch] = p;
    }
    for (final p in newData) {
      map[p.timestamp.millisecondsSinceEpoch] = p;
    }
    final merged = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  static Future<void> clearTraining() async {
    try {
      html.window.localStorage.remove(_trainingKey);
    } catch (_) {
      // ignore
    }
  }

  // ---- Forecast persistence (web) ----
  static Future<void> saveForecast(
    List<PowerDataPoint> forecast, {
    int? stepSeconds,
    int? horizonSteps,
    double? a,
    double? b,
  }) async {
    try {
      final jsonList = forecast
          .map((e) => {
                'ts': e.timestamp.toIso8601String(),
                'y': e.consumption,
              })
          .toList();
      final meta = <String, dynamic>{};
      if (stepSeconds != null) meta['stepSeconds'] = stepSeconds;
      if (horizonSteps != null) meta['horizonSteps'] = horizonSteps;
      if (a != null) meta['a'] = a;
      if (b != null) meta['b'] = b;
      html.window.localStorage[_forecastKey] = jsonEncode({'points': jsonList, 'meta': meta});
    } catch (_) {
      // ignore
    }
  }

  static Future<List<PowerDataPoint>> loadForecast() async {
    try {
      final txt = html.window.localStorage[_forecastKey];
      if (txt == null || txt.isEmpty) return [];
      final map = jsonDecode(txt) as Map<String, dynamic>;
      final pts = (map['points'] as List)
          .map((m) => PowerDataPoint(DateTime.parse(m['ts']), (m['y'] as num).toDouble()))
          .toList();
      pts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return pts;
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearForecast() async {
    try {
      html.window.localStorage.remove(_forecastKey);
    } catch (_) {
      // ignore
    }
  }
}
