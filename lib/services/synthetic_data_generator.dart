import 'dart:math';
import 'ml_service.dart';
import 'csv_loader_common.dart';
import 'package:csv/csv.dart';

/// Generates a larger synthetic dataset based on a small seed dataset.
/// Strategy:
/// - Resample at a specified interval.
/// - Learn a simple trend from the seed, then add seasonality + noise.
/// - Optionally scale to reach a target length.
class SyntheticDataGenerator {
  /// Expand a seed time series to a larger dataset.
  ///
  /// seed: Seed points (timestamp + consumption).
  /// step: Desired uniform interval for the generated series.
  /// totalPoints: Target number of points to generate (>= seed length). If null, will generate 5x seed length.
  /// noiseStd: Standard deviation of additive Gaussian noise.
  /// seasonality: Whether to inject weekday/hour-of-day seasonal pattern.
  static List<PowerDataPoint> expand(
    List<PowerDataPoint> seed, {
    Duration step = const Duration(hours: 1),
    int? totalPoints,
    double noiseStd = 0.05,
    bool seasonality = true,
    int randomSeed = 42,
  }) {
    if (seed.isEmpty) return [];

    // Train a simple linear model for baseline trend using seed
    final trained = MLService.train(seed);
    final model = trained.model;

    // Resample start at the first seed timestamp rounded to step
    final start = _alignToStep(seed.first.timestamp, step);
    final points = totalPoints ?? (seed.length * 5);

    final rng = Random(randomSeed);

    // Precompute seasonal statistics from seed for hour-of-week pattern
    Map<int, double> seasonalAdj = {};
    double overallMean = 0.0;
    if (seasonality) {
      final sorted = [...seed]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      overallMean = sorted.map((e) => e.consumption).fold(0.0, (a, b) => a + b) / sorted.length;
      final buckets = <int, List<double>>{};
      for (final p in sorted) {
        final b = _bucketFor(p.timestamp, step);
        (buckets[b] ??= []).add(p.consumption);
      }
      seasonalAdj = {
        for (final e in buckets.entries)
          e.key: (e.value.reduce((a, b) => a + b) / e.value.length) - overallMean
      };
    }

    final startEpoch = start.millisecondsSinceEpoch.toDouble();

    final generated = <PowerDataPoint>[];
    for (int i = 0; i < points; i++) {
      final t = start.add(step * i);
      final xSec = (t.millisecondsSinceEpoch.toDouble() - startEpoch) / 1000.0;
      double y = model.predict(xSec);
      if (seasonality) {
        final b = _bucketFor(t, step);
        y += seasonalAdj[b] ?? 0.0;
      }
      // Additive Gaussian noise
      y += _gaussian(rng) * noiseStd * (y.abs() + 1.0);
      // Clip to non-negative
      if (y < 0) y = 0;
      generated.add(PowerDataPoint(t, y));
    }

    return generated;
  }

  /// Generate a completely synthetic dataset without any seed data.
  /// The shape is: baseline + linear trend + weekly seasonality + noise.
  static List<PowerDataPoint> generate(
    DateTime start, {
    Duration step = const Duration(hours: 1),
    int points = 1000,
    double baseline = 1.0,
    double slopePerStep = 0.0,
    double weeklySeasonalityAmp = 0.3,
    double dailySeasonalityAmp = 0.2,
    double noiseStd = 0.05,
    int randomSeed = 42,
  }) {
    final rng = Random(randomSeed);
    final out = <PowerDataPoint>[];
    for (int i = 0; i < points; i++) {
      final t = start.add(step * i);
      final dow = t.weekday % 7; // 0..6
      final hod = t.hour + t.minute / 60.0;
      // Weekly component: sine by day-of-week
      final weekly = weeklySeasonalityAmp * sin(2 * pi * dow / 7);
      // Daily component: sine by hour-of-day (peak in evening around 18-20h)
      final daily = dailySeasonalityAmp * sin(2 * pi * (hod - 18) / 24);
      double y = baseline + slopePerStep * i + weekly + daily + _gaussian(rng) * noiseStd * (baseline + 1.0);
      if (y < 0) y = 0;
      out.add(PowerDataPoint(t, y));
    }
    return out;
  }

  static DateTime _alignToStep(DateTime t, Duration step) {
    if (step.inSeconds <= 0) return t;
    final s = step.inSeconds;
    final epoch = t.millisecondsSinceEpoch ~/ 1000;
    final aligned = (epoch ~/ s) * s;
    return DateTime.fromMillisecondsSinceEpoch(aligned * 1000);
  }

  static int _bucketFor(DateTime t, Duration step) {
    final weekday0 = (t.weekday % 7);
    if (step.inDays >= 1) return weekday0;
    final hours = step.inHours == 0 ? 1 : step.inHours;
    final bucketPerDay = (24 / hours).floor().clamp(1, 24);
    final slot = (t.hour / hours).floor().clamp(0, bucketPerDay - 1);
    return weekday0 * 24 + slot * hours;
  }

  // Box-Muller transform for Gaussian noise
  static double _gaussian(Random rng) {
    final u1 = rng.nextDouble().clamp(1e-12, 1 - 1e-12);
    final u2 = rng.nextDouble().clamp(1e-12, 1 - 1e-12);
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  /// Load seed data from CSV string and expand it, returning CSV string.
  /// Output columns: timestamp,consumption
  static Future<String> expandCsvToCsv(
    String csvContent, {
    Duration step = const Duration(hours: 1),
    int? totalPoints,
    double noiseStd = 0.05,
    bool seasonality = true,
    int randomSeed = 42,
  }) async {
    final seed = await CsvLoaderCommon.loadPowerDataFromString(csvContent);
    final out = expand(
      seed,
      step: step,
      totalPoints: totalPoints,
      noiseStd: noiseStd,
      seasonality: seasonality,
      randomSeed: randomSeed,
    );
    return _toCsv(out);
  }

  /// Convert a list of points to CSV string
  static String _toCsv(List<PowerDataPoint> data) {
    final rows = <List<dynamic>>[
      ['timestamp', 'consumption'],
      ...data.map((p) => [p.timestamp.toIso8601String(), p.consumption])
    ];
    return const ListToCsvConverter().convert(rows);
  }
}
