import 'dart:ui';

import 'graph_point.dart';

class FreehandStroke {
  const FreehandStroke({
    required this.points,
    this.color = const Color(0xFF1C2B22),
    this.strokeWidth = 4,
    this.opacity = 0.85,
  });

  final List<GraphPoint> points;
  final Color color;
  final double strokeWidth;
  final double opacity;

  FreehandStroke copyWith({
    List<GraphPoint>? points,
    Color? color,
    double? strokeWidth,
    double? opacity,
  }) {
    return FreehandStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
    );
  }
}
