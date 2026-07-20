import 'dart:ui';

import '../models/graph_document.dart';
import '../models/graph_point.dart';

class ExportBoundsCalculator {
  const ExportBoundsCalculator._();

  static Rect forDocument(
    GraphDocument document, {
    double padding = 48,
    Size? canvasSize,
  }) {
    final points = <GraphPoint>[
      for (final segment in document.wallSegments) ...[
        segment.start,
        segment.end,
        if (segment.controlPoint != null) segment.controlPoint!,
      ],
      for (final annotation in document.annotations) annotation.point,
      for (final stroke in document.freehandStrokes) ...stroke.points,
      for (final trace in document.traces) ...trace.canvasPoints,
    ];

    if (points.isEmpty) {
      final fallback = Offset.zero & (canvasSize ?? const Size(1, 1));
      return fallback;
    }

    var left = points.first.x;
    var top = points.first.y;
    var right = points.first.x;
    var bottom = points.first.y;
    for (final point in points.skip(1)) {
      if (point.x < left) left = point.x;
      if (point.x > right) right = point.x;
      if (point.y < top) top = point.y;
      if (point.y > bottom) bottom = point.y;
    }

    var bounds = Rect.fromLTRB(
      left - padding,
      top - padding,
      right + padding,
      bottom + padding,
    );
    if (canvasSize != null) {
      bounds = bounds.intersect(Offset.zero & canvasSize);
    }
    if (bounds.width < 1 || bounds.height < 1) {
      return Rect.fromLTWH(bounds.left, bounds.top, 1, 1);
    }
    return bounds;
  }
}
