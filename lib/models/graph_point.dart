import 'dart:math' as math;
import 'dart:ui';

class GraphPoint {
  const GraphPoint({
    required this.x,
    required this.y,
  });

  factory GraphPoint.fromOffset(Offset offset) {
    return GraphPoint(x: offset.dx, y: offset.dy);
  }

  final double x;
  final double y;

  Offset get offset => Offset(x, y);

  double distanceTo(GraphPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;

    return math.sqrt((dx * dx) + (dy * dy));
  }
}
