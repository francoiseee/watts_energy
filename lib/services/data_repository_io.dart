import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'ml_service.dart';

class DataRepository {
  static const _fileName = 'training_data.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
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
}
