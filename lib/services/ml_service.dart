class PowerDataPoint {
  final DateTime timestamp;
  final double consumption;

  PowerDataPoint(this.timestamp, this.consumption);
}

class LinearRegressionModel {
  // y = a + b * x
  double? a;
  double? b;
  double? rSquared;

  bool get isTrained => a != null && b != null;

  // Train using least squares on (x, y). Here x is time index or seconds.
  void fit(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) {
      throw ArgumentError('x and y must have same non-zero length');
    }

    final n = x.length.toDouble();
    final sumX = x.reduce((v, e) => v + e);
    final sumY = y.reduce((v, e) => v + e);
    final sumXX = x.map((e) => e * e).reduce((v, e) => v + e);
    final sumXY = List.generate(x.length, (i) => x[i] * y[i]).reduce((v, e) => v + e);

    final denom = (n * sumXX - sumX * sumX);
    if (denom == 0) {
      a = sumY / n;
      b = 0;
      final yBar = sumY / n;
      final ssTot = y.map((yi) => (yi - yBar) * (yi - yBar)).fold(0.0, (p, c) => p + c);
      final ssRes = y.map((yi) => (yi - a!) * (yi - a!)).fold(0.0, (p, c) => p + c);
      rSquared = ssTot == 0 ? 0.0 : (1 - ssRes / ssTot);
      return;
    }

    b = (n * sumXY - sumX * sumY) / denom;
    a = (sumY - b! * sumX) / n;

    // Compute R^2
    final yBar = sumY / n;
    double ssTot = 0.0;
    double ssRes = 0.0;
    for (int i = 0; i < x.length; i++) {
      final yi = y[i];
      final yHat = a! + b! * x[i];
      ssTot += (yi - yBar) * (yi - yBar);
      ssRes += (yi - yHat) * (yi - yHat);
    }
    rSquared = ssTot == 0 ? 0.0 : (1 - ssRes / ssTot);
  }

  double predict(double x) {
    if (!isTrained) throw StateError('Model not trained');
    return a! + b! * x;
  }

  List<double> predictMany(List<double> xs) => xs.map(predict).toList();
}

class MLService {
  static ({LinearRegressionModel model, List<double> historyX}) train(List<PowerDataPoint> data) {
    if (data.isEmpty) {
      throw ArgumentError('No data provided');
    }
    data.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    // Light smoothing to reduce high-frequency noise
    final smoothed = _movingAverage(data, window: 3);
    final start = smoothed.first.timestamp.millisecondsSinceEpoch.toDouble();
    final xs = smoothed
        .map((d) => (d.timestamp.millisecondsSinceEpoch.toDouble() - start) / 1000.0)
        .toList();
    final ys = smoothed.map((d) => d.consumption).toList();

    final model = _robustFit(xs, ys);
    return (model: model, historyX: xs);
  }

  static List<PowerDataPoint> forecast(
    LinearRegressionModel model,
    DateTime lastTime,
    List<double> historyX,
    int steps,
    Duration step,
  ) {
    if (!model.isTrained) {
      throw StateError('Model not trained');
    }
    final result = <PowerDataPoint>[];
    final startEpoch = (lastTime.millisecondsSinceEpoch -
            (historyX.isNotEmpty ? (historyX.last * 1000).round() : 0))
        .toDouble();
    for (int i = 1; i <= steps; i++) {
      final t = lastTime.add(step * i);
      final x = (t.millisecondsSinceEpoch.toDouble() - startEpoch) / 1000.0;
      final y = model.predict(x);
      result.add(PowerDataPoint(t, y));
    }
    return result;
  }

  static List<PowerDataPoint> forecastSeasonal(
    LinearRegressionModel model,
    List<PowerDataPoint> history,
    int steps,
    Duration step,
  ) {
    if (!model.isTrained) {
      throw StateError('Model not trained');
    }
    if (history.isEmpty) return [];
    final data = [...history]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final startEpoch = data.first.timestamp.millisecondsSinceEpoch.toDouble();

    final Map<int, List<double>> buckets = {};
    double overallSum = 0.0;
    int overallCount = 0;

    int bucketFor(DateTime t) {
      final weekday0 = (t.weekday % 7); // 0..6 where 0 is Sunday
      if (step.inDays >= 1) {
        return weekday0; // 7 buckets
      }
      final hours = step.inHours == 0 ? 1 : step.inHours; // guard
      final bucketPerDay = (24 / hours).floor().clamp(1, 24);
      final slot = (t.hour / hours).floor().clamp(0, bucketPerDay - 1);
      return weekday0 * 24 + slot * hours; // spread across week by hour start
    }

    for (final p in data) {
      final b = bucketFor(p.timestamp);
      (buckets[b] ??= []).add(p.consumption);
      overallSum += p.consumption;
      overallCount++;
    }
    final overallMean = overallCount > 0 ? overallSum / overallCount : 0.0;

    final Map<int, double> seasonalMean = {
      for (final e in buckets.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length
    };

    final lastTime = data.last.timestamp;
    final results = <PowerDataPoint>[];
    for (int i = 1; i <= steps; i++) {
      final t = lastTime.add(step * i);
      final xSec = (t.millisecondsSinceEpoch.toDouble() - startEpoch) / 1000.0;
      final base = model.predict(xSec);
      final b = bucketFor(t);
      final seasonalAdj = seasonalMean.containsKey(b)
          ? (seasonalMean[b]! - overallMean)
          : 0.0;
      final y = base + seasonalAdj;
      results.add(PowerDataPoint(t, y));
    }
    return results;
  }
}

// Helpers for robustness
List<PowerDataPoint> _movingAverage(List<PowerDataPoint> data, {int window = 3}) {
  if (data.length <= 2 || window <= 1) return data;
  final w = window.clamp(2, 21);
  final out = <PowerDataPoint>[];
  for (int i = 0; i < data.length; i++) {
    final start = (i - (w ~/ 2)).clamp(0, data.length - 1);
    final end = (i + (w ~/ 2) + 1).clamp(0, data.length);
    final slice = data.sublist(start, end);
    final mean = slice.map((e) => e.consumption).reduce((a, b) => a + b) / slice.length;
    out.add(PowerDataPoint(data[i].timestamp, mean));
  }
  return out;
}

LinearRegressionModel _robustFit(List<double> xs, List<double> ys) {
  final model = LinearRegressionModel();
  if (xs.length < 10) {
    model.fit(xs, ys);
    return model;
  }
  // RANSAC-like: sample pairs to estimate slope, choose model with best median absolute residual
  // Deterministic seeding from data to make forecasts reproducible run-to-run
  final seed = _seedFromData(xs, ys);
  int iters = (50 + xs.length).clamp(50, 500);
  double bestScore = double.infinity;
  double bestA = 0, bestB = 0;
  for (int k = 0; k < iters; k++) {
    final i = (seed * (k + 3) + k * 37) % xs.length;
    final j = (seed * (k + 5) + k * 91) % xs.length;
    final i1 = i.toInt();
    final j1 = (j == i ? (j + 1) % xs.length : j).toInt();
    final dx = xs[j1] - xs[i1];
    if (dx.abs() < 1e-9) continue;
    final b = (ys[j1] - ys[i1]) / dx;
    final a = ys[i1] - b * xs[i1];
    // Score by median absolute residual
    final res = <double>[];
    for (int t = 0; t < xs.length; t++) {
      res.add((ys[t] - (a + b * xs[t])).abs());
    }
    res.sort();
    final med = res[res.length ~/ 2];
    if (med < bestScore) {
      bestScore = med;
      bestA = a;
      bestB = b;
    }
  }
  if (bestScore.isFinite) {
    model.a = bestA;
    model.b = bestB;
    // Compute R^2 for reference
    final yBar = ys.reduce((v, e) => v + e) / ys.length;
    double ssTot = 0.0, ssRes = 0.0;
    for (int i = 0; i < xs.length; i++) {
      final yi = ys[i];
      final yHat = bestA + bestB * xs[i];
      ssTot += (yi - yBar) * (yi - yBar);
      ssRes += (yi - yHat) * (yi - yHat);
    }
    model.rSquared = ssTot == 0 ? 0.0 : (1 - ssRes / ssTot);
    return model;
  } else {
    model.fit(xs, ys);
    return model;
  }
}

// Deterministic seed derived from the input data (cheap rolling hash over sampled points)
int _seedFromData(List<double> xs, List<double> ys) {
  int h = 0x811C9DC5; // FNV-1a 32-bit offset basis
  int mix(int v) {
    h ^= (v & 0xFFFFFFFF);
    h = (h * 16777619) & 0xFFFFFFFF; // FNV prime
    return h;
  }

  int stepX = (xs.length / 64).ceil();
  if (stepX <= 0) stepX = 1;
  for (int i = 0; i < xs.length; i += stepX) {
    mix(((xs[i]) * 1e6).round());
  }
  int stepY = (ys.length / 64).ceil();
  if (stepY <= 0) stepY = 1;
  for (int i = 0; i < ys.length; i += stepY) {
    mix(((ys[i]) * 1e6).round());
  }
  mix(xs.length);
  mix(ys.length << 16);
  return h & 0x7FFFFFFF; // positive int
}
