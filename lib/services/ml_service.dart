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
    final sumXY = List.generate(x.length, (i) => x[i] * y[i])
        .reduce((v, e) => v + e);

    final denom = (n * sumXX - sumX * sumX);
    if (denom == 0) {
      // Fallback: all x equal; use mean
      a = sumY / n;
      b = 0;
      // rSquared undefined when variance in x is zero; set to 0
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
  // Fit a simple time-indexed regression and predict k future steps.
  static ({LinearRegressionModel model, List<double> historyX}) train(
      List<PowerDataPoint> data) {
    if (data.isEmpty) {
      throw ArgumentError('No data provided');
    }

    // Sort by timestamp just in case
    data.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final start = data.first.timestamp.millisecondsSinceEpoch.toDouble();
    final xs = data
        .map((d) => (d.timestamp.millisecondsSinceEpoch.toDouble() - start) /
            1000.0)
        .toList();
    final ys = data.map((d) => d.consumption).toList();

    final model = LinearRegressionModel();
    model.fit(xs, ys);
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

  // Seasonal naive + linear trend forecast.
  // For daily step: uses average by weekday over history (centered) plus linear trend.
  // For sub-daily (<= 12h): uses average by (weekday, hourBucket) across history (centered) plus linear trend.
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

    // Build seasonal profiles
    final Map<int, List<double>> buckets = {};
    double overallSum = 0.0;
    int overallCount = 0;

    int bucketFor(DateTime t) {
      final weekday0 = (t.weekday % 7); // 0..6 where 0 is Sunday
      if (step.inDays >= 1) {
        return weekday0; // 7 buckets
      }
      // hourly or sub-daily bucket
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

    // Forecast
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
