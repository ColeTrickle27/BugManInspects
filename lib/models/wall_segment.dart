import 'dart:ui';

import 'graph_point.dart';

enum LinePattern {
  solid('Solid'),
  dashed('Dashed'),
  xMarks('X shapes'),
  dottedSmall('Dotted small'),
  dottedLarge('Dotted large'),
  diamonds('Diamond shapes');

  const LinePattern(this.label);

  final String label;
}

class WallSegment {
  const WallSegment({
    required this.start,
    required this.end,
    this.controlPoint,
    this.color = const Color(0xFF214D38),
    this.strokeWidth = 5,
    this.pattern = LinePattern.solid,
    this.hasArrow = false,
  });

  // Temporary visual scale for the MVP. Later this can be calibrated per job.
  static const double pixelsPerFoot = 24.0;

  final GraphPoint start;
  final GraphPoint end;
  final GraphPoint? controlPoint;
  final Color color;
  final double strokeWidth;
  final LinePattern pattern;
  final bool hasArrow;

  bool get isCurve => controlPoint != null;

  double get lengthPixels => start.distanceTo(end);

  double get lengthFeet => lengthPixels / pixelsPerFoot;

  String get measurementLabel {
    if (lengthFeet < 10) {
      return '${lengthFeet.toStringAsFixed(1)} lf';
    }

    return '${lengthFeet.round()} lf';
  }

  WallSegment copyWith({
    GraphPoint? start,
    GraphPoint? end,
    GraphPoint? controlPoint,
    bool clearControlPoint = false,
    Color? color,
    double? strokeWidth,
    LinePattern? pattern,
    bool? hasArrow,
  }) {
    return WallSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      controlPoint:
          clearControlPoint ? null : controlPoint ?? this.controlPoint,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      pattern: pattern ?? this.pattern,
      hasArrow: hasArrow ?? this.hasArrow,
    );
  }
}
