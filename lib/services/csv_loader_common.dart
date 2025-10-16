import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'ml_service.dart';

class CsvLoaderCommon {
  static Future<List<PowerDataPoint>> loadPowerDataFromString(String content) async {
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    return _parseRows(rows);
  }

  static Future<List<PowerDataPoint>> loadPowerDataFromBytes(Uint8List bytes) async {
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    return loadPowerDataFromString(content);
  }

  static List<PowerDataPoint> _parseRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return [];

    final headerRow = rows.first;
    int timeIdx = 0;
    int valueIdx = 1;

    final hasHeader = headerRow.any((c) => c is String);
    if (hasHeader) {
      final headers = headerRow.map((c) => c.toString().toLowerCase()).toList();
      timeIdx = headers.indexWhere((h) => h.contains('time') || h.contains('date') || h.contains('stamp'));
      valueIdx = headers.indexWhere((h) => h.contains('consumption') || h.contains('power') || h.contains('usage'));
    }

    if (timeIdx < 0 || valueIdx < 0) {
      timeIdx = 0;
      valueIdx = 1;
    }

    final data = <PowerDataPoint>[];
    final dataRows = hasHeader ? rows.skip(1) : rows;

    if (!hasHeader && rows.first.length == 1) {
      final today = DateTime.now();
      for (int i = 0; i < rows.length; i++) {
        final valueCell = rows[i][0];
        final val = valueCell is num ? valueCell.toDouble() : double.tryParse(valueCell.toString());
        if (val == null) continue;
        final ts = DateTime(today.year, today.month, today.day).subtract(Duration(days: (rows.length - 1 - i)));
        data.add(PowerDataPoint(ts, val));
      }
      return data;
    }

    for (final row in dataRows) {
      if (row.length <= valueIdx) continue;
      final timeCell = row[timeIdx];
      final valueCell = row[valueIdx];

      DateTime? ts;
      if (timeCell is num) {
        final v = timeCell.toDouble();
        if (v > 1e12) {
          ts = DateTime.fromMillisecondsSinceEpoch(v.toInt());
        } else if (v > 1e9) {
          ts = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
        } else {
          final base = DateTime(1899, 12, 30);
          ts = base.add(Duration(milliseconds: (v * 24 * 3600 * 1000).round()));
        }
      } else {
        try {
          ts = DateTime.parse(timeCell.toString());
        } catch (_) {
          final s = timeCell.toString();
          final parts = s.split(RegExp(r'[ T]'));
          if (parts.isNotEmpty) {
            try {
              final dateParts = parts[0].split(RegExp(r'[-/]'));
              int y, m, d;
              if (dateParts[0].length == 4) {
                y = int.parse(dateParts[0]);
                m = int.parse(dateParts[1]);
                d = int.parse(dateParts[2]);
              } else {
                d = int.parse(dateParts[0]);
                m = int.parse(dateParts[1]);
                y = int.parse(dateParts[2]);
              }
              int hh = 0, mm = 0, ss = 0;
              if (parts.length > 1) {
                final timeParts = parts[1].split(':');
                if (timeParts.isNotEmpty) hh = int.parse(timeParts[0]);
                if (timeParts.length > 1) mm = int.parse(timeParts[1]);
                if (timeParts.length > 2) ss = int.parse(timeParts[2]);
              }
              ts = DateTime(y, m, d, hh, mm, ss);
            } catch (_) {
              ts = null;
            }
          }
        }
      }

      if (ts == null) continue;

      double? val;
      if (valueCell is num) {
        val = valueCell.toDouble();
      } else {
        val = double.tryParse(valueCell.toString());
      }
      if (val == null) continue;

      data.add(PowerDataPoint(ts, val));
    }
    return data;
  }
}
