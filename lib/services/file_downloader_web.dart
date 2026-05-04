import 'dart:html' as html;

void downloadCsv(String content, String filename) {
  final blob = html.Blob([content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename);
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
