import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadCsv(String content, String filename) {
  final blob = web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', filename);
  anchor.click();
  web.URL.revokeObjectURL(url);
}
