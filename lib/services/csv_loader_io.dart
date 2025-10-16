import 'dart:io';
import 'dart:typed_data';
import 'csv_loader_common.dart';
import 'ml_service.dart';

class CsvLoader {
  static Future<List<PowerDataPoint>> loadPowerData(File file) async {
    final content = await file.readAsString();
    return CsvLoaderCommon.loadPowerDataFromString(content);
  }

  static Future<List<PowerDataPoint>> loadPowerDataFromPath(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    return CsvLoaderCommon.loadPowerDataFromString(content);
  }

  static Future<List<PowerDataPoint>> loadPowerDataFromString(String content) async {
    return CsvLoaderCommon.loadPowerDataFromString(content);
  }

  static Future<List<PowerDataPoint>> loadPowerDataFromBytes(Uint8List bytes) async {
    return CsvLoaderCommon.loadPowerDataFromBytes(bytes);
  }
}
