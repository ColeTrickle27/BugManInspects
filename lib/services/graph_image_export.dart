import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

class GraphImageExport {
  const GraphImageExport._();

  /// Captures the canvas and returns only the requested content bounds.
  static Future<Uint8List> capturePng(
    RenderRepaintBoundary boundary,
    ui.Rect contentBounds,
  ) async {
    final source = await boundary.toImage(pixelRatio: 1);
    try {
      final imageBounds = ui.Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      );
      final crop = contentBounds.intersect(imageBounds);
      if (crop.isEmpty) {
        throw StateError('Graph has no visible export content');
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final destination = ui.Rect.fromLTWH(0, 0, crop.width, crop.height);
      canvas.drawImageRect(source, crop, destination, ui.Paint());
      final cropped = await recorder.endRecording().toImage(
            crop.width.ceil(),
            crop.height.ceil(),
          );
      try {
        final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('PNG encoding returned no data');
        }
        return data.buffer.asUint8List();
      } finally {
        cropped.dispose();
      }
    } finally {
      source.dispose();
    }
  }
}
