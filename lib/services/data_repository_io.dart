import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'ml_service.dart';

class DataRepository {
  static const _fileName = 'training_data.json';
  static const _forecastFileName = 'forecast_data.json';

  static Future<Directory> _getBaseDir() async {
    // On desktop platforms, save to the current working directory (project folder during dev)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Directory.current;
    }
    // On mobile, use the app documents directory
    return await getApplicationDocumentsDirectory();
  }

  static Future<File> _getFile() async {
    final dir = await _getBaseDir();
    return File('${dir.path}/$_fileName');
  }

  static Future<File> _getForecastFile() async {
    final dir = await _getBaseDir();
    return File('${dir.path}/$_forecastFileName');
  }

  static Future<void> save(List<PowerDataPoint> data) async {
    final f = await _getFile();
    final jsonList = data
        .map((e) => {
              'ts': e.timestamp.toIso8601String(),
              'y': e.consumption,
            })
        .toList();
    await f.writeAsString(jsonEncode({'points': jsonList}));
  }

  static Future<List<PowerDataPoint>> load() async {
    try {
      final f = await _getFile();
      if (!await f.exists()) return [];
      final txt = await f.readAsString();
      final map = jsonDecode(txt) as Map<String, dynamic>;
      final pts = (map['points'] as List)
          .map((m) => PowerDataPoint(DateTime.parse(m['ts']), (m['y'] as num).toDouble()))
          .toList();
      return pts;
    } catch (_) {
      return [];
    }
  }

  // ---- Forecast persistence ----
  static Future<void> saveForecast(
    List<PowerDataPoint> forecast, {
    int? stepSeconds,
    int? horizonSteps,
    double? a,
    double? b,
  }) async {
    try {
      final f = await _getForecastFile();
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
      await f.writeAsString(jsonEncode({'points': jsonList, 'meta': meta}));
    } catch (_) {
      // ignore
    }
  }

  static Future<List<PowerDataPoint>> loadForecast() async {
    try {
      final f = await _getForecastFile();
      if (!await f.exists()) return [];
      final txt = await f.readAsString();
      final map = jsonDecode(txt) as Map<String, dynamic>;
      final pts = (map['points'] as List)
          .map((m) => PowerDataPoint(DateTime.parse(m['ts']), (m['y'] as num).toDouble()))
          .toList();
      return pts;
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearForecast() async {
    try {
      final f = await _getForecastFile();
      if (await f.exists()) await f.delete();
    } catch (_) {
      // ignore
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

  static Future<void> clearTraining() async {
    try {
      final dir = await _getBaseDir();
      final f = File('${dir.path}/$_fileName');
      if (await f.exists()) await f.delete();
    } catch (_) {
      // ignore
    }
  }

  // Merge with saved data without writing back; useful when user wants to compare
  // forecasts with/without saved history without mutating the stored set.
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
}
