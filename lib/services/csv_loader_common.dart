import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'ml_service.dart';

class CsvLoaderCommon {
  static Future<List<PowerDataPoint>> loadPowerDataFromString(String content) async {
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    final detection = _detectSchema(rows);
    final raw = _parseRows(rows);
    final converted = _maybeConvertEnergyToPower(raw, detection);
    return _cleanData(converted);
  }

  static Future<List<PowerDataPoint>> loadPowerDataFromBytes(Uint8List bytes) async {
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    final detection = _detectSchema(rows);
    final raw = _parseRows(rows);
    final converted = _maybeConvertEnergyToPower(raw, detection);
    return _cleanData(converted);
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
      // Try common energy/power column names
      valueIdx = headers.indexWhere((h) =>
          h.contains('consumption') ||
          h.contains('usage') ||
          h.contains('energy') ||
          h.contains('kwh') ||
          h.contains('kph') || // treat as consumption value column if present
          h == 'y' ||
          h == 'value' ||
          h.contains('power') ||
          h == 'kw');
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

  // Column detection result
  static ({bool hasHeader, String valueHeader}) _detectSchema(List<List<dynamic>> rows) {
    if (rows.isEmpty) return (hasHeader: false, valueHeader: 'value');
    final headerRow = rows.first;
    final hasHeader = headerRow.any((c) => c is String);
    String valueHeader = 'value';
    if (hasHeader) {
      final headers = headerRow.map((c) => c.toString().toLowerCase()).toList();
      final idx = headers.indexWhere((h) =>
          h.contains('consumption') ||
          h.contains('usage') ||
          h.contains('energy') ||
          h.contains('kwh') ||
          h.contains('kph') ||
          h.contains('power') ||
          h == 'kw' ||
          h == 'y' ||
          h == 'value');
      if (idx >= 0) valueHeader = headers[idx];
    }
    return (hasHeader: hasHeader, valueHeader: valueHeader);
  }

  // If the value column appears to be energy (kWh) rather than power, convert to power (kW)
  // by dividing per-interval energy by the elapsed hours since previous sample.
  static List<PowerDataPoint> _maybeConvertEnergyToPower(
      List<PowerDataPoint> data, ({bool hasHeader, String valueHeader}) detection) {
    if (data.length < 2) return data;
    final header = detection.valueHeader;
    final lower = header.toLowerCase();

    // Treat KPH as already a rate (kWh per hour == kW) => no conversion
    final isKph = lower.contains('kph');
    final isPower = lower.contains('kw') || lower.contains('power');
    final isEnergy = lower.contains('kwh') || lower.contains('energy');
    if (isKph || isPower) return data;
    if (!isEnergy) return data;

    // For energy (kWh), decide if values are cumulative meter readings or per-interval energy.
    final sorted = [...data]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final y = sorted.map((e) => e.consumption).toList();
    int nonNeg = 0;
    int total = 0;
    double deltaSum = 0.0;
    for (int i = 1; i < y.length; i++) {
      final d = y[i] - y[i - 1];
      if (d >= 0) nonNeg++;
      total++;
      deltaSum += d;
    }
    final mostlyNonDecreasing = total > 0 && (nonNeg / total) >= 0.9 && deltaSum > 0;

    // Compute median step in hours
    final stepsH = <double>[];
    for (int i = 1; i < sorted.length; i++) {
      final dt = sorted[i].timestamp.difference(sorted[i - 1].timestamp).inSeconds / 3600.0;
      if (dt > 0) stepsH.add(dt);
    }
    stepsH.sort();
    final medianDt = stepsH.isEmpty ? 1.0 : _percentile(stepsH, 0.5);

    if (mostlyNonDecreasing) {
      // CUMULATIVE meter: power = max(0, diff(kWh)) / hours
      final out = <PowerDataPoint>[];
      for (int i = 1; i < sorted.length; i++) {
        final curr = sorted[i];
        final prev = sorted[i - 1];
        final dtH = curr.timestamp.difference(prev.timestamp).inSeconds / 3600.0;
        // Skip unrealistically tiny intervals that would create spikes
        if (dtH <= 0 || dtH < (medianDt * 0.25)) {
          continue;
        }
        final hours = dtH > 0 ? dtH : (medianDt > 0 ? medianDt : 1.0);
        double eDelta = y[i] - y[i - 1];
        if (eDelta < 0) {
          // Likely meter reset; skip or clamp to 0
          eDelta = 0;
        }
        final pKw = eDelta / hours;
        out.add(PowerDataPoint(curr.timestamp, pKw));
      }
      // Remove potential startup outlier: if the very first computed point deviates
      // strongly from the median of the next few points, drop it.
      if (out.length >= 5) {
        final window = out.sublist(1, (1 + 5).clamp(1, out.length));
        final vals = window.map((e) => e.consumption).toList()..sort();
        final med = _percentile(vals, 0.5);
        final first = out.first.consumption;
        // If first is > 1.5x median or < 0.5x median, treat as outlier and drop
        if ((med > 0 && (first / med > 1.5 || first / med < 0.5)) || (med == 0 && first != 0)) {
          out.removeAt(0);
        }
      }
      return out;
    } else {
      // Per-interval kWh: power = energy / hours
      final out = <PowerDataPoint>[];
      for (int i = 0; i < sorted.length; i++) {
        final dtH = i == 0
            ? medianDt
            : (sorted[i].timestamp.difference(sorted[i - 1].timestamp).inSeconds / 3600.0);
        final hours = dtH > 0 ? dtH : (medianDt > 0 ? medianDt : 1.0);
        out.add(PowerDataPoint(sorted[i].timestamp, y[i] / hours));
      }
      return out;
    }
  }

  // Basic, robust cleaning for training-ready data
  // - Sort by timestamp
  // - Drop duplicate timestamps (keep last occurrence)
  // - Remove NaN and negative values
  // - Clip extreme outliers using IQR fences (Q1-3*IQR, Q3+3*IQR) when enough samples
  static List<PowerDataPoint> _cleanData(List<PowerDataPoint> input) {
    if (input.isEmpty) return [];

    // Sort by time
    final sorted = [...input]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Deduplicate by timestamp (keep latest value for same ts)
    final byTs = <int, PowerDataPoint>{};
    for (final p in sorted) {
      final tsKey = p.timestamp.millisecondsSinceEpoch;
      byTs[tsKey] = p; // overwrite keeps last
    }
    final deduped = byTs.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Filter invalid values
    final valid0 = deduped.where((p) {
      final y = p.consumption;
      return y.isFinite && y >= 0; // drop NaN/inf and negatives
    }).toList();
    if (valid0.isEmpty) return [];

    // Drop an incomplete leading day if it has much fewer samples than typical
    final valid = _dropIncompleteLeadingDay(valid0);

    // Remove initial transient prefix if the first few points are inconsistent
    // with the subsequent window median (helps eliminate visible start spikes)
    final trimmed = _trimInitialTransient(valid);

    // Compute IQR-based clipping thresholds when enough points
    List<double> ys = trimmed.map((e) => e.consumption).toList()..sort();
    if (ys.length >= 10) {
      double q1 = _percentile(ys, 0.25);
      double q3 = _percentile(ys, 0.75);
      double iqr = q3 - q1;
      double lower = q1 - 3 * iqr;
      double upper = q3 + 3 * iqr;
      // Ensure bounds are sensible
      if (upper < 0) upper = 0;
      // Clip values
      return trimmed
          .map((p) {
            double y = p.consumption;
            if (y < lower) y = lower;
            if (y > upper) y = upper;
            return PowerDataPoint(p.timestamp, y);
          })
          .toList();
    } else {
      return trimmed;
    }
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0.0;
    if (p <= 0) return sorted.first;
    if (p >= 1) return sorted.last;
    final pos = (sorted.length - 1) * p;
    final lower = pos.floor();
    final upper = pos.ceil();
    if (lower == upper) return sorted[lower];
    final weight = pos - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  // Detect and drop an incomplete leading day compared to median daily coverage
  static List<PowerDataPoint> _dropIncompleteLeadingDay(List<PowerDataPoint> input) {
    if (input.length < 48) return input; // need enough samples
    final data = [...input]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    // median dt in hours
    final dts = <double>[];
    for (int i = 1; i < data.length; i++) {
      final dt = data[i].timestamp.difference(data[i - 1].timestamp).inSeconds / 3600.0;
      if (dt > 0) dts.add(dt);
    }
    if (dts.isEmpty) return input;
    dts.sort();
    final medianDt = _percentile(dts, 0.5);
    if (medianDt <= 0) return input;
    final expectedPerDay = (24.0 / medianDt).round().clamp(1, 10000);

    // Count samples per day
    final counts = <DateTime, int>{};
    for (final p in data) {
      final day = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final days = counts.keys.toList()..sort();
    if (days.length < 3) return input;
    // Compute median count excluding first day
    final otherCounts = [
      for (int i = 1; i < days.length; i++) counts[days[i]]!
    ]..sort();
    final medianCount = otherCounts[otherCounts.length >> 1];
    final firstCount = counts[days.first] ?? expectedPerDay;
    // Drop first day if it has less than half the median daily samples
    if (medianCount > 0 && firstCount < (medianCount * 0.5)) {
      return data.where((p) {
        final day = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
        return day.isAfter(days.first);
      }).toList();
    }
    return input;
  }

  static List<PowerDataPoint> _trimInitialTransient(List<PowerDataPoint> input) {
    if (input.length < 6) return input;
    // Iterate up to 3 times to remove a small inconsistent prefix
    List<PowerDataPoint> data = [...input];
    for (int attempt = 0; attempt < 3; attempt++) {
      if (data.length < 6) break;
      final w1 = data.sublist(0, (5).clamp(0, data.length));
      final w2 = data.sublist(5, (5 + 10).clamp(5, data.length));
      if (w2.isEmpty) break;
      final m1 = _median(w1.map((e) => e.consumption).toList());
      final m2 = _median(w2.map((e) => e.consumption).toList());
      if (m2 == 0 && m1 == 0) break;
      final ratio = (m2 == 0) ? double.infinity : (m1 / m2).abs();
      if (ratio > 1.5 || ratio < (1 / 1.5)) {
        // Drop the first 5 points and continue
        data = data.sublist(5);
      } else {
        break;
      }
    }
    return data;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    values.sort();
    final n = values.length;
    if (n.isOdd) return values[n >> 1];
    return (values[(n >> 1) - 1] + values[n >> 1]) / 2.0;
  }
}
