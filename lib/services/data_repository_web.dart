import 'ml_service.dart';

class DataRepository {
  static Future<void> save(List<PowerDataPoint> data) async {}
  static Future<List<PowerDataPoint>> load() async => [];
  static Future<List<PowerDataPoint>> mergeAndSave(List<PowerDataPoint> newData) async => newData;

  // Forecast persistence stubs (no-op on web by default)
  static Future<void> saveForecast(
    List<PowerDataPoint> forecast, {
    int? stepSeconds,
    int? horizonSteps,
    double? a,
    double? b,
  }) async {}
  static Future<List<PowerDataPoint>> loadForecast() async => [];
  static Future<void> clearForecast() async {}
}
