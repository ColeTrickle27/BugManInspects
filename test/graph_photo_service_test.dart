import 'dart:typed_data';

import 'package:bugman_graphs/services/graph_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test('photo optimization creates durable image and thumbnail metadata', () {
    final sourceImage = image_lib.Image(width: 2400, height: 1200);
    final source = PickedGraphPhoto(
      name: 'inspection.png',
      bytes: Uint8List.fromList(image_lib.encodePng(sourceImage)),
    );

    final optimized = optimizeGraphPhoto(
      source: source,
      annotationId: 'pin-1',
      attachmentId: 'photo-1',
    );

    expect(optimized.attachment.annotationId, 'pin-1');
    expect(optimized.attachment.mimeType, 'image/jpeg');
    expect(optimized.attachment.width, 2048);
    expect(optimized.attachment.height, 1024);
    expect(optimized.bytes, isNotEmpty);
    expect(optimized.thumbnailBytes, isNotEmpty);
    final thumbnail = image_lib.decodeJpg(optimized.thumbnailBytes)!;
    expect(thumbnail.width, 320);
    expect(thumbnail.height, 160);
  });
}
