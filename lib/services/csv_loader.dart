import 'dart:io';
import 'package:csv/csv.dart';
import 'ml_service.dart';

class CsvLoader {
  // Tries to detect columns named like: time,timestamp,date,datetime and consumption,power,usage
  static Future<List<PowerDataPoint>> loadPowerData(File file) async {
    final content = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);
  if (rows.isEmpty) return [];

  // Assume first row is header if any cell is String
    final headerRow = rows.first;
    int timeIdx = 0;
    int valueIdx = 1;

    if (headerRow.any((c) => c is String)) {
      final headers = headerRow.map((c) => c.toString().toLowerCase()).toList();
      timeIdx = headers.indexWhere((h) =>
          h.contains('time') || h.contains('date') || h.contains('stamp'));
      valueIdx = headers.indexWhere((h) =>
          h.contains('consumption') || h.contains('power') || h.contains('usage'));
    }

    if (timeIdx < 0 || valueIdx < 0) {
      // Fallback to first two columns
      timeIdx = 0;
      valueIdx = 1;
    }

    final data = <PowerDataPoint>[];
    final hasHeader = headerRow.any((c) => c is String);
    final dataRows = hasHeader ? rows.skip(1) : rows;

    // Special case: single column numeric CSV -> generate sequential dates
    if (!hasHeader && rows.first.length == 1) {
      // Treat each row as a consumption value. Generate daily timestamps counting back from today.
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
        // Try Excel/epoch days
        // If it's large, assume epoch milliseconds/seconds
        final v = timeCell.toDouble();
        if (v > 1e12) {
          ts = DateTime.fromMillisecondsSinceEpoch(v.toInt());
        } else if (v > 1e9) {
          ts = DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt());
        } else {
          // Excel serial date (days since 1899-12-30)
          final base = DateTime(1899, 12, 30);
          ts = base.add(Duration(milliseconds: (v * 24 * 3600 * 1000).round()));
        }
      } else {
        // Parse string date
        try {
          ts = DateTime.parse(timeCell.toString());
        } catch (_) {
          // try alternative: dd/MM/yyyy HH:mm
          final s = timeCell.toString();
          final parts = s.split(RegExp(r'[ T]'));
          if (parts.isNotEmpty) {
            try {
              final dateParts = parts[0].split(RegExp(r'[-/]'));
              int y, m, d;
              if (dateParts[0].length == 4) {
                // yyyy-MM-dd
                y = int.parse(dateParts[0]);
                m = int.parse(dateParts[1]);
                d = int.parse(dateParts[2]);
              } else {
                // dd/MM/yyyy
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
