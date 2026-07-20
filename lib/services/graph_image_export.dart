import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'graph_export_legend.dart';

class GraphImageExport {
  const GraphImageExport._();

  /// Captures the canvas and returns only the requested content bounds.
  static Future<Uint8List> capturePng(
    RenderRepaintBoundary boundary,
    ui.Rect contentBounds, {
    List<GraphLegendSection> legend = const [],
  }) async {
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

      final legendEntries = legend.fold<int>(
        0,
        (total, section) => total + section.entries.length,
      );
      final columns = (crop.width / 280).floor().clamp(1, 4);
      final legendRows = legendEntries == 0
          ? 0
          : legend.fold<int>(
              0,
              (total, section) =>
                  total + 1 + (section.entries.length / columns).ceil(),
            );
      final legendHeight = legendRows == 0 ? 0.0 : 24 + (legendRows * 38.0);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final destination = ui.Rect.fromLTWH(0, 0, crop.width, crop.height);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, crop.width, crop.height + legendHeight),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawImageRect(source, crop, destination, ui.Paint());
      if (legend.isNotEmpty) {
        _drawLegend(canvas, crop.width, crop.height, legend, columns);
      }
      final cropped = await recorder.endRecording().toImage(
            crop.width.ceil(),
            (crop.height + legendHeight).ceil(),
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

  static void _drawLegend(
    ui.Canvas canvas,
    double width,
    double top,
    List<GraphLegendSection> sections,
    int columns,
  ) {
    var y = top + 20;
    final columnWidth = width / columns;
    for (final section in sections) {
      _drawText(
        canvas,
        section.title,
        const ui.Offset(16, 0),
        y,
        fontSize: 18,
        bold: true,
      );
      y += 34;
      for (var i = 0; i < section.entries.length; i++) {
        final column = i % columns;
        final row = i ~/ columns;
        final x = 16 + (column * columnWidth);
        final entryY = y + (row * 38);
        final entry = section.entries[i];
        canvas.drawCircle(
          ui.Offset(x + 12, entryY + 10),
          10,
          ui.Paint()..color = entry.color,
        );
        _drawText(
          canvas,
          '${entry.markerType.shortLabel}  ${entry.markerType.label}',
          ui.Offset(x + 30, 0),
          entryY,
          fontSize: 14,
        );
      }
      y += ((section.entries.length / columns).ceil() * 38) + 8;
    }
  }

  static void _drawText(
    ui.Canvas canvas,
    String text,
    ui.Offset offset,
    double y, {
    required double fontSize,
    bool bold = false,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        fontSize: fontSize,
        fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      ),
    )..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 260));
    canvas.drawParagraph(paragraph, ui.Offset(offset.dx, y));
  }
}
