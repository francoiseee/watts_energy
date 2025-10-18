import 'dart:html' as html;

class FileOutput {
  // On web, trigger a browser download using a Blob and anchor element.
  static Future<String> saveCsv(String filename, String content) async {
    final bytes = html.Blob([content], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(bytes);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return filename; // Return the suggested filename
  }
}
