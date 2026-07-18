import 'package:flutter/material.dart';

import '../models/freehand_stroke.dart';
import '../models/graph_point.dart';

class FreehandStrokesPainter extends CustomPainter {
  const FreehandStrokesPainter({
    required this.strokes,
    required this.draftPoints,
    required this.selectedStrokeIndex,
    this.hoveredStrokeIndex,
  });

  final List<FreehandStroke> strokes;
  final List<GraphPoint> draftPoints;
  final int? selectedStrokeIndex;
  final int? hoveredStrokeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < strokes.length; i += 1) {
      _drawStroke(
        canvas,
        strokes[i],
        selected: i == selectedStrokeIndex,
        hovered: i == hoveredStrokeIndex,
      );
    }

    if (draftPoints.length > 1) {
      _drawPath(
        canvas,
        draftPoints,
        Paint()
          ..color = const Color(0xFF2F80ED).withValues(alpha: 0.65)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawStroke(
    Canvas canvas,
    FreehandStroke stroke, {
    required bool selected,
    required bool hovered,
  }) {
    if (hovered && !selected) {
      _drawPath(
        canvas,
        stroke.points,
        Paint()
          ..color = const Color(0xFF2F80ED).withValues(alpha: 0.38)
          ..strokeWidth = stroke.strokeWidth + 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    _drawPath(
      canvas,
      stroke.points,
      Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (selected) {
      final bounds = _boundsForPoints(stroke.points);
      canvas.drawRect(
        bounds.inflate(8),
        Paint()
          ..color = const Color(0xFF2F80ED)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawPath(Canvas canvas, List<GraphPoint> points, Paint paint) {
    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    canvas.drawPath(path, paint);
  }

  Rect _boundsForPoints(List<GraphPoint> points) {
    var left = points.first.x;
    var right = points.first.x;
    var top = points.first.y;
    var bottom = points.first.y;

    for (final point in points.skip(1)) {
      left = left < point.x ? left : point.x;
      right = right > point.x ? right : point.x;
      top = top < point.y ? top : point.y;
      bottom = bottom > point.y ? bottom : point.y;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant FreehandStrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.draftPoints != draftPoints ||
        oldDelegate.selectedStrokeIndex != selectedStrokeIndex ||
        oldDelegate.hoveredStrokeIndex != hoveredStrokeIndex;
  }
}
