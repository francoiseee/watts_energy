class FileOutput {
  // On web, return a pseudo-path and rely on the UI to present the CSV content for download if desired
  static Future<String> saveCsv(String filename, String content) async {
    // A real implementation could trigger a browser download via anchor blob
    return filename;
  }
}
