import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;

import '../models/graph_document.dart';

class PickedGraphPhoto {
  const PickedGraphPhoto({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

abstract class GraphPhotoPicker {
  Future<List<PickedGraphPhoto>> chooseMultiple();

  Future<PickedGraphPhoto?> capture();
}

class OptimizedGraphPhoto {
  const OptimizedGraphPhoto({
    required this.attachment,
    required this.bytes,
    required this.thumbnailBytes,
  });

  final GraphAttachment attachment;
  final Uint8List bytes;
  final Uint8List thumbnailBytes;
}

OptimizedGraphPhoto optimizeGraphPhoto({
  required PickedGraphPhoto source,
  required String annotationId,
  required String attachmentId,
  String referenceLabel = '',
}) {
  final decoded = image_lib.decodeImage(source.bytes);
  if (decoded == null) {
    throw const FormatException('The selected file is not a supported image');
  }
  final oriented = image_lib.bakeOrientation(decoded);
  final scale = oriented.width > oriented.height
      ? (oriented.width > 2048 ? 2048 / oriented.width : 1.0)
      : (oriented.height > 2048 ? 2048 / oriented.height : 1.0);
  final optimized = scale < 1
      ? image_lib.copyResize(
          oriented,
          width: (oriented.width * scale).round(),
          height: (oriented.height * scale).round(),
        )
      : oriented;
  final thumbnailScale = optimized.width > optimized.height
      ? 320 / optimized.width
      : 320 / optimized.height;
  final thumbnail = thumbnailScale < 1
      ? image_lib.copyResize(
          optimized,
          width: (optimized.width * thumbnailScale).round(),
          height: (optimized.height * thumbnailScale).round(),
        )
      : optimized;
  final bytes = Uint8List.fromList(image_lib.encodeJpg(optimized, quality: 82));
  final thumbnailBytes =
      Uint8List.fromList(image_lib.encodeJpg(thumbnail, quality: 70));
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
      width: optimized.width,
      height: optimized.height,
      blobKey: blobKey,
      thumbnailKey: thumbnailKey,
    ),
    bytes: bytes,
    thumbnailBytes: thumbnailBytes,
  );
}
