import 'package:flutter/material.dart';

import '../models/graph_shape.dart';
import '../models/wall_segment.dart';
import 'wall_segments_painter.dart';

@visibleForTesting
bool usesStyledSegmentRendering(GraphShape shape) =>
    shape.preset?.kind == GraphDrawingPresetKind.line;

class GraphShapesPainter extends CustomPainter {
  const GraphShapesPainter({
    required this.shapes,
    required this.segments,
    required this.selectedShapeIndex,
    this.hoveredShapeIndex,
  });

  final List<GraphShape> shapes;
  final List<WallSegment> segments;
  final int? selectedShapeIndex;
  final int? hoveredShapeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < shapes.length; i += 1) {
      final shape = shapes[i];
      final shapeSegments = _segmentsForShape(shape);
      if (shapeSegments.isEmpty) {
        continue;
      }

      final path = _pathForShape(shape, shapeSegments);
      final bounds = path.getBounds();
      final isStyledLine = usesStyledSegmentRendering(shape);

      if (isStyledLine) {
        WallSegmentsPainter(
          segments: shapeSegments,
          selectedSegmentIndex: null,
          hoveredSegmentIndex: null,
          activeWallStart: null,
          previewSegment: null,
          drawMeasurements: shape.preset == GraphDrawingPreset.measurementLine,
        ).paint(canvas, size);
      } else if (shape.fillColor != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = shape.fillColor!.withValues(alpha: shape.fillOpacity),
        );
      }

      if (!isStyledLine) {
        _drawPattern(canvas, shape.pattern, path, bounds);
        _drawShapeBorder(canvas, shape, path);
      }

      _drawShapeName(
        canvas,
        shape.text.trim().isEmpty ? shape.name : shape.text,
        bounds.center,
      );

      if (i == hoveredShapeIndex && i != selectedShapeIndex) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF2F80ED).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }

      if (i == selectedShapeIndex) {
        _drawSelectedShape(canvas, path, bounds);
      }
    }
  }

  void _drawShapeBorder(Canvas canvas, GraphShape shape, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = shape.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = shape.borderWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSelectedShape(Canvas canvas, Path path, Rect bounds) {
    final selectedPaint = Paint()
      ..color = const Color(0xFF2F80ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, selectedPaint);

    for (final handleCenter in [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      final handle = Rect.fromCenter(
        center: handleCenter,
        width: 12,
        height: 12,
      );
      canvas.drawRect(handle, Paint()..color = Colors.white);
      canvas.drawRect(handle, selectedPaint);
    }

    final rotationHandleCenter = bounds.topCenter - const Offset(0, 28);
    canvas.drawLine(bounds.topCenter, rotationHandleCenter, selectedPaint);
    canvas.drawCircle(rotationHandleCenter, 6, Paint()..color = Colors.white);
    canvas.drawCircle(rotationHandleCenter, 6, selectedPaint);
  }

  List<WallSegment> _segmentsForShape(GraphShape shape) {
    return shape.segmentIndexes
        .where((index) => index >= 0 && index < segments.length)
        .map((index) => segments[index])
        .toList();
  }

  Path _pathForShape(GraphShape shape, List<WallSegment> shapeSegments) {
    final path = Path()
      ..moveTo(shapeSegments.first.start.x, shapeSegments.first.start.y);

    for (final segment in shapeSegments) {
      final controlPoint = segment.controlPoint;
      if (controlPoint == null) {
        path.lineTo(segment.end.x, segment.end.y);
      } else {
        path.quadraticBezierTo(
          controlPoint.x,
          controlPoint.y,
          segment.end.x,
          segment.end.y,
        );
      }
    }

    if (shape.closed) {
      path.close();
    }

    return path;
  }

  void _drawPattern(
    Canvas canvas,
    GraphShapePattern pattern,
    Path path,
    Rect bounds,
  ) {
    switch (pattern) {
      case GraphShapePattern.none:
        return;
      case GraphShapePattern.diagonal:
        _drawLinePattern(canvas, path, bounds, _PatternLine.diagonal);
        return;
      case GraphShapePattern.reverseDiagonal:
        _drawLinePattern(canvas, path, bounds, _PatternLine.reverseDiagonal);
        return;
      case GraphShapePattern.crossHatch:
        _drawLinePattern(canvas, path, bounds, _PatternLine.diagonal);
        _drawLinePattern(canvas, path, bounds, _PatternLine.reverseDiagonal);
        return;
      case GraphShapePattern.horizontal:
        _drawLinePattern(canvas, path, bounds, _PatternLine.horizontal);
        return;
      case GraphShapePattern.vertical:
        _drawLinePattern(canvas, path, bounds, _PatternLine.vertical);
        return;
      case GraphShapePattern.grid:
        _drawLinePattern(canvas, path, bounds, _PatternLine.horizontal);
        _drawLinePattern(canvas, path, bounds, _PatternLine.vertical);
        return;
      case GraphShapePattern.dots:
        _drawDotPattern(canvas, path, bounds, spacing: 24, radius: 2.8);
        return;
      case GraphShapePattern.largeDots:
        _drawDotPattern(canvas, path, bounds, spacing: 34, radius: 4.2);
        return;
      case GraphShapePattern.checker:
        _drawCheckerPattern(canvas, path, bounds);
        return;
    }
  }

  void _drawLinePattern(
    Canvas canvas,
    Path path,
    Rect bounds,
    _PatternLine lineType,
  ) {
    canvas.save();
    canvas.clipPath(path);

    final patternPaint = Paint()
      ..color = const Color.fromRGBO(28, 43, 34, 0.16)
      ..strokeWidth = 2;
    switch (lineType) {
      case _PatternLine.diagonal:
        final startX = bounds.left - bounds.height;
        final endX = bounds.right + bounds.height;
        for (double x = startX; x <= endX; x += 22) {
          canvas.drawLine(
            Offset(x, bounds.bottom + 20),
            Offset(x + bounds.height + 40, bounds.top - 20),
            patternPaint,
          );
        }
        break;
      case _PatternLine.reverseDiagonal:
        final startX = bounds.left - bounds.height;
        final endX = bounds.right + bounds.height;
        for (double x = startX; x <= endX; x += 22) {
          canvas.drawLine(
            Offset(x, bounds.top - 20),
            Offset(x + bounds.height + 40, bounds.bottom + 20),
            patternPaint,
          );
        }
        break;
      case _PatternLine.horizontal:
        for (double y = bounds.top; y <= bounds.bottom; y += 22) {
          canvas.drawLine(
            Offset(bounds.left - 20, y),
            Offset(bounds.right + 20, y),
            patternPaint,
          );
        }
        break;
      case _PatternLine.vertical:
        for (double x = bounds.left; x <= bounds.right; x += 22) {
          canvas.drawLine(
            Offset(x, bounds.top - 20),
            Offset(x, bounds.bottom + 20),
            patternPaint,
          );
        }
        break;
    }

    canvas.restore();
  }

  void _drawDotPattern(
    Canvas canvas,
    Path path,
    Rect bounds, {
    required double spacing,
    required double radius,
  }) {
    canvas.save();
    canvas.clipPath(path);

    final dotPaint = Paint()..color = const Color.fromRGBO(28, 43, 34, 0.18);

    for (double x = bounds.left; x <= bounds.right; x += spacing) {
      for (double y = bounds.top; y <= bounds.bottom; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }

    canvas.restore();
  }

  void _drawCheckerPattern(Canvas canvas, Path path, Rect bounds) {
    canvas.save();
    canvas.clipPath(path);

    final checkerPaint = Paint()
      ..color = const Color.fromRGBO(28, 43, 34, 0.12);
    const size = 24.0;
    var row = 0;

    for (double y = bounds.top; y <= bounds.bottom; y += size) {
      var column = 0;
      for (double x = bounds.left; x <= bounds.right; x += size) {
        if ((row + column).isEven) {
          canvas.drawRect(Rect.fromLTWH(x, y, size, size), checkerPaint);
        }
        column += 1;
      }
      row += 1;
    }

    canvas.restore();
  }

  void _drawShapeName(Canvas canvas, String name, Offset center) {
    if (name.trim().isEmpty) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF1C2B22),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    final labelRect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 18,
      height: textPainter.height + 10,
    );
    final labelRRect = RRect.fromRectAndRadius(
      labelRect,
      const Radius.circular(5),
    );

    canvas.drawRRect(
      labelRRect,
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.82),
    );
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = const Color(0xFFD1CCBF)
        ..style = PaintingStyle.stroke,
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
  bool shouldRepaint(covariant GraphShapesPainter oldDelegate) {
    return oldDelegate.shapes != shapes ||
        oldDelegate.segments != segments ||
        oldDelegate.selectedShapeIndex != selectedShapeIndex ||
        oldDelegate.hoveredShapeIndex != hoveredShapeIndex;
  }
}

enum _PatternLine {
  diagonal,
  reverseDiagonal,
  horizontal,
  vertical,
}
