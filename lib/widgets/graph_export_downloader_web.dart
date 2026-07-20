// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

bool downloadGraphPng(Uint8List bytes, String filename) {
  return downloadGraphFile(bytes, filename, 'image/png');
}

bool downloadGraphFile(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
