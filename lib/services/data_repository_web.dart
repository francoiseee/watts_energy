import 'ml_service.dart';

class DataRepository {
  static Future<void> save(List<PowerDataPoint> data) async {}
  static Future<List<PowerDataPoint>> load() async => [];
  static Future<List<PowerDataPoint>> mergeAndSave(List<PowerDataPoint> newData) async => newData;
}
