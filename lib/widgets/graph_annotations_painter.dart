import 'package:flutter/material.dart';

import '../models/graph_annotation.dart';

class GraphAnnotationsPainter extends CustomPainter {
  const GraphAnnotationsPainter({
    required this.annotations,
    required this.selectedAnnotationIndex,
    required this.findingsVisible,
    required this.photosVisible,
  });

  final List<GraphAnnotation> annotations;
  final int? selectedAnnotationIndex;
  final bool findingsVisible;
  final bool photosVisible;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < annotations.length; i += 1) {
      final annotation = annotations[i];
      if (!_isVisible(annotation)) {
        continue;
      }

      switch (annotation.kind) {
        case GraphAnnotationKind.marker:
          _drawMarker(canvas, annotation);
          break;
        case GraphAnnotationKind.photo:
          _drawPhotoPin(canvas, annotation);
          break;
        case GraphAnnotationKind.text:
          _drawTextLabel(canvas, annotation);
          break;
      }

      if (i == selectedAnnotationIndex) {
        _drawSelectionBox(canvas, annotation);
      }
    }
  }

  bool _isVisible(GraphAnnotation annotation) {
    return switch (annotation.kind) {
      GraphAnnotationKind.marker || GraphAnnotationKind.text => findingsVisible,
      GraphAnnotationKind.photo => photosVisible,
    };
  }

  void _drawSelectionBox(Canvas canvas, GraphAnnotation annotation) {
    final center = annotation.point.offset;
    final rect = Rect.fromCenter(center: center, width: 84, height: 66);
    final selectedPaint = Paint()
      ..color = const Color(0xFF2F80ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(rect, selectedPaint);

    for (final handleCenter in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final handle = Rect.fromCenter(
        center: handleCenter,
        width: 10,
        height: 10,
      );
      canvas.drawRect(handle, Paint()..color = Colors.white);
      canvas.drawRect(handle, selectedPaint);
    }
  }

  void _drawMarker(Canvas canvas, GraphAnnotation annotation) {
    final center = annotation.point.offset;
    final color = annotation.color ?? annotation.markerType.defaultColor;
    final radius = 15 * annotation.size;
    final shadowPaint = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.16);
    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(annotation.rotationDegrees * 3.1415926535 / 180);
    canvas.translate(-center.dx, -center.dy);

    if (annotation.markerType == GraphMarkerType.triangle) {
      final path = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy + radius)
        ..close();
      canvas.drawPath(path.shift(const Offset(2, 3)), shadowPaint);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    } else if (annotation.markerType == GraphMarkerType.square ||
        annotation.markerType == GraphMarkerType.baitStation ||
        annotation.markerType == GraphMarkerType.accessPoint) {
      final rect = Rect.fromCenter(
        center: center,
        width: radius * 1.8,
        height: radius * 1.8,
      );
      canvas.drawRect(rect.shift(const Offset(2, 3)), shadowPaint);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    } else if (annotation.markerType == GraphMarkerType.damage ||
        annotation.markerType == GraphMarkerType.termiteDamage ||
        annotation.markerType == GraphMarkerType.camera ||
        annotation.markerType == GraphMarkerType.photoPoint ||
        annotation.markerType == GraphMarkerType.entryPoint) {
      final markerPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius))
        ..moveTo(center.dx - (radius * 0.55), center.dy + (radius * 0.7))
        ..lineTo(center.dx, center.dy + (radius * 1.75))
        ..lineTo(center.dx + (radius * 0.55), center.dy + (radius * 0.7))
        ..close();
      canvas.drawCircle(center + const Offset(2, 3), radius, shadowPaint);
      canvas.drawPath(markerPath, fillPaint);
      canvas.drawPath(markerPath, borderPaint);
    } else {
      canvas.drawCircle(center + const Offset(2, 3), radius, shadowPaint);
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, borderPaint);
    }

    canvas.restore();
    _drawMarkerText(canvas, center, annotation);
    _drawSmallLabel(
        canvas, center + Offset(0, 36 * annotation.size), annotation.label);
  }

  void _drawMarkerText(
      Canvas canvas, Offset center, GraphAnnotation annotation) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: annotation.markerType == GraphMarkerType.moisture &&
                annotation.note.trim().isNotEmpty
            ? annotation.note
            : annotation.markerType.shortLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 46);

    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  void _drawPhotoPin(Canvas canvas, GraphAnnotation annotation) {
    final center = annotation.point.offset;
    final rect = Rect.fromCenter(center: center, width: 54, height: 38);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    final fillPaint = Paint()..color = const Color(0xFF2C6F9F);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      rrect.shift(const Offset(2, 3)),
      Paint()..color = const Color.fromRGBO(0, 0, 0, 0.16),
    );
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF2C6F9F));
    _drawSmallLabel(canvas, center + const Offset(0, 32), annotation.label);
  }

  void _drawTextLabel(Canvas canvas, GraphAnnotation annotation) {
    _drawSmallLabel(
      canvas,
      annotation.point.offset,
      annotation.label,
      textColor: annotation.textColor,
      fontSize: annotation.fontSize,
      fontWeight: annotation.bold ? FontWeight.w800 : FontWeight.w500,
      fontStyle: annotation.italic ? FontStyle.italic : FontStyle.normal,
      backgroundColor: annotation.backgroundColor,
      borderColor: annotation.borderColor,
    );
  }

  void _drawSmallLabel(
    Canvas canvas,
    Offset center,
    String label, {
    Color textColor = const Color(0xFF1C2B22),
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    FontStyle fontStyle = FontStyle.normal,
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFD1CCBF),
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);

    final labelRect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 16,
      height: textPainter.height + 8,
    );
    final labelRRect = RRect.fromRectAndRadius(
      labelRect,
      const Radius.circular(5),
    );

    canvas.drawRRect(labelRRect, Paint()..color = backgroundColor);
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GraphAnnotationsPainter oldDelegate) {
    return oldDelegate.annotations != annotations ||
        oldDelegate.selectedAnnotationIndex != selectedAnnotationIndex ||
        oldDelegate.findingsVisible != findingsVisible ||
        oldDelegate.photosVisible != photosVisible;
  }
}
