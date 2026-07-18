import 'package:flutter/material.dart';

import '../models/graph_annotation.dart';

class GraphAnnotationsPainter extends CustomPainter {
  const GraphAnnotationsPainter({
    required this.annotations,
    required this.selectedAnnotationIndex,
    this.hoveredAnnotationIndex,
    required this.findingsVisible,
    required this.photosVisible,
  });

  final List<GraphAnnotation> annotations;
  final int? selectedAnnotationIndex;
  final int? hoveredAnnotationIndex;
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
      } else if (i == hoveredAnnotationIndex) {
        canvas.drawCircle(
          annotation.point.offset,
          25 * annotation.size,
          Paint()
            ..color = const Color(0xFF2F80ED).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
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

    final markerPath = _markerPath(
      center,
      radius,
      annotation.markerType.category,
    );
    canvas.drawPath(markerPath.shift(const Offset(2, 3)), shadowPaint);
    canvas.drawPath(markerPath, fillPaint);
    canvas.drawPath(markerPath, borderPaint);

    canvas.restore();
    _drawMarkerText(canvas, center, annotation);
    _drawSmallLabel(
        canvas, center + Offset(0, 36 * annotation.size), annotation.label);
  }

  Path _markerPath(
    Offset center,
    double radius,
    GraphMarkerCategory category,
  ) {
    switch (category) {
      case GraphMarkerCategory.insectFindings:
        return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      case GraphMarkerCategory.structureFindings:
        return Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy)
          ..close();
      case GraphMarkerCategory.moistureFindings:
        return Path()
          ..moveTo(center.dx, center.dy - (radius * 1.15))
          ..quadraticBezierTo(
            center.dx + (radius * 1.25),
            center.dy + (radius * 0.35),
            center.dx,
            center.dy + radius,
          )
          ..quadraticBezierTo(
            center.dx - (radius * 1.25),
            center.dy + (radius * 0.35),
            center.dx,
            center.dy - (radius * 1.15),
          )
          ..close();
      case GraphMarkerCategory.structureDetails:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: center,
                width: radius * 2,
                height: radius * 1.7,
              ),
              Radius.circular(radius * 0.28),
            ),
          );
      case GraphMarkerCategory.treatment:
        return Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + (radius * 0.86), center.dy - (radius * 0.5))
          ..lineTo(center.dx + (radius * 0.86), center.dy + (radius * 0.5))
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - (radius * 0.86), center.dy + (radius * 0.5))
          ..lineTo(center.dx - (radius * 0.86), center.dy - (radius * 0.5))
          ..close();
      case GraphMarkerCategory.review:
        return Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius))
          ..moveTo(center.dx - (radius * 0.25), center.dy + (radius * 0.8))
          ..lineTo(center.dx - (radius * 0.7), center.dy + (radius * 1.35))
          ..lineTo(center.dx + (radius * 0.25), center.dy + (radius * 0.85))
          ..close();
    }
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
        oldDelegate.hoveredAnnotationIndex != hoveredAnnotationIndex ||
        oldDelegate.findingsVisible != findingsVisible ||
        oldDelegate.photosVisible != photosVisible;
  }
}
