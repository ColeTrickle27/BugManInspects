// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../models/graph_document.dart';
import 'graph_photo_service.dart';

Future<OptimizedGraphPhoto> optimizeGraphPhotoAsync({
  required PickedGraphPhoto source,
  required String annotationId,
  required String attachmentId,
  String referenceLabel = '',
}) async {
  final sourceBlob = html.Blob(<Object>[source.bytes]);
  final sourceUrl = html.Url.createObjectUrlFromBlob(sourceBlob);
  try {
    final image = html.ImageElement(src: sourceUrl);
    await image.onLoad.first.timeout(const Duration(seconds: 30));
    final sourceWidth = image.naturalWidth;
    final sourceHeight = image.naturalHeight;
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      throw const FormatException('The selected file is not a supported image');
    }

    final fullSize = _fit(sourceWidth, sourceHeight, 2048);
    final thumbnailSize = _fit(fullSize.$1, fullSize.$2, 320);
    final bytes = await _encode(image, fullSize.$1, fullSize.$2, 0.82);
    final thumbnailBytes =
        await _encode(image, thumbnailSize.$1, thumbnailSize.$2, 0.70);
    final blobKey = attachmentId;
    final thumbnailKey = '$attachmentId-thumb';
    return OptimizedGraphPhoto(
      attachment: GraphAttachment(
        id: attachmentId,
        name: source.name,
        annotationId: annotationId,
        referenceLabel: referenceLabel,
        mimeType: 'image/jpeg',
        byteSize: bytes.length,
        width: fullSize.$1,
        height: fullSize.$2,
        blobKey: blobKey,
        thumbnailKey: thumbnailKey,
      ),
      bytes: bytes,
      thumbnailBytes: thumbnailBytes,
    );
  } finally {
    html.Url.revokeObjectUrl(sourceUrl);
  }
}

(int, int) _fit(int width, int height, int maximum) {
  final longest = width > height ? width : height;
  if (longest <= maximum) return (width, height);
  final scale = maximum / longest;
  return ((width * scale).round(), (height * scale).round());
}

Future<Uint8List> _encode(
  html.ImageElement image,
  int width,
  int height,
  double quality,
) async {
  final canvas = html.CanvasElement(width: width, height: height);
  canvas.context2D.drawImageScaled(image, 0, 0, width, height);
  final blob = await canvas.toBlob('image/jpeg', quality);
  final reader = html.FileReader()..readAsArrayBuffer(blob);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is ByteBuffer) return result.asUint8List();
  if (result is Uint8List) return result;
  throw const FormatException('The optimized image could not be encoded');
}
