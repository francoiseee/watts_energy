import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileOutput {
  static Future<String> saveCsv(String filename, String content) async {
    Directory dir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      dir = Directory.current;
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    return file.path;
  }
}
