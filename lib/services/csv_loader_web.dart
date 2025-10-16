import 'dart:typed_data';
import 'csv_loader_common.dart';
import 'ml_service.dart';

class CsvLoader {
  // Stub to satisfy references in cross-platform code; not usable on web.
  static Future<List<PowerDataPoint>> loadPowerData(Object _unsupported) async {
    throw UnsupportedError('CsvLoader.loadPowerData(File) is not available on web');
  }

  // Stub to satisfy references; prefer using loadPowerDataFromBytes on web
  static Future<List<PowerDataPoint>> loadPowerDataFromPath(String path) async {
    throw UnsupportedError('CsvLoader.loadPowerDataFromPath is not available on web');
  }

  // On web, we can only load from string or bytes provided by pickers/network
  static Future<List<PowerDataPoint>> loadPowerDataFromString(String content) async {
    return CsvLoaderCommon.loadPowerDataFromString(content);
  }

  static Future<List<PowerDataPoint>> loadPowerDataFromBytes(Uint8List bytes) async {
    return CsvLoaderCommon.loadPowerDataFromBytes(bytes);
  }
}
