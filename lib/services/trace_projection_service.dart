import 'dart:math' as math;
import 'dart:ui';

import '../models/graph_point.dart';
import '../models/trace_geometry.dart';
import 'measurement_service.dart';

class TraceProjectionResult {
  const TraceProjectionResult({
    required this.canvasPoints,
    required this.metersPerCanvasUnit,
  });

  final List<GraphPoint> canvasPoints;
  final double metersPerCanvasUnit;
}

class TraceProjectionService {
  const TraceProjectionService._();

  static TraceProjectionResult projectToCanvas(
    List<GeoPoint> points, {
    required Size canvasSize,
    double padding = 320,
  }) {
    if (points.isEmpty) {
      return const TraceProjectionResult(
        canvasPoints: <GraphPoint>[],
        metersPerCanvasUnit: 1,
      );
    }
    final latitudeOrigin =
        points.fold<double>(0, (sum, point) => sum + point.latitude) /
            points.length;
    final latitudeRadians = latitudeOrigin * math.pi / 180;
    final projected = <Offset>[
      for (final point in points)
        Offset(
          MeasurementService.earthRadiusMeters *
              point.longitude *
              math.pi /
              180 *
              math.cos(latitudeRadians),
          -MeasurementService.earthRadiusMeters *
              point.latitude *
              math.pi /
              180,
        ),
    ];
    final left = projected.map((point) => point.dx).reduce(math.min);
    final right = projected.map((point) => point.dx).reduce(math.max);
    final top = projected.map((point) => point.dy).reduce(math.min);
    final bottom = projected.map((point) => point.dy).reduce(math.max);
    final widthMeters = math.max(right - left, 0.01);
    final heightMeters = math.max(bottom - top, 0.01);
    final availableWidth = math.max(canvasSize.width - (padding * 2), 1);
    final availableHeight = math.max(canvasSize.height - (padding * 2), 1);
    final canvasUnitsPerMeter = math.min(
      availableWidth / widthMeters,
      availableHeight / heightMeters,
    );
    final renderedWidth = widthMeters * canvasUnitsPerMeter;
    final renderedHeight = heightMeters * canvasUnitsPerMeter;
    final offsetX = (canvasSize.width - renderedWidth) / 2;
    final offsetY = (canvasSize.height - renderedHeight) / 2;
    return TraceProjectionResult(
      canvasPoints: <GraphPoint>[
        for (final point in projected)
          GraphPoint(
            x: offsetX + ((point.dx - left) * canvasUnitsPerMeter),
            y: offsetY + ((point.dy - top) * canvasUnitsPerMeter),
          ),
      ],
      metersPerCanvasUnit: 1 / canvasUnitsPerMeter,
    );
  }

  static double scaleBarFeet(double metersPerCanvasUnit) {
    final targetFeet = 140 * metersPerCanvasUnit * 3.280839895013123;
    if (targetFeet <= 0) return 1;
    final power = math.pow(10, (math.log(targetFeet) / math.ln10).floor());
    final normalized = targetFeet / power;
    final nice = normalized >= 5
        ? 5
        : normalized >= 2
            ? 2
            : 1;
    return (nice * power).toDouble();
  }

  static GeoPoint moveGeoPointByCanvasDelta({
    required GeoPoint point,
    required Offset canvasDelta,
    required double metersPerCanvasUnit,
  }) {
    final northMeters = -canvasDelta.dy * metersPerCanvasUnit;
    final eastMeters = canvasDelta.dx * metersPerCanvasUnit;
    final latitudeRadians = point.latitude * math.pi / 180;
    final latitudeDelta =
        northMeters / MeasurementService.earthRadiusMeters * 180 / math.pi;
    final longitudeScale = math.max(math.cos(latitudeRadians).abs(), 0.000001);
    final longitudeDelta = eastMeters /
        (MeasurementService.earthRadiusMeters * longitudeScale) *
        180 /
        math.pi;
    return GeoPoint(
      latitude: point.latitude + latitudeDelta,
      longitude: point.longitude + longitudeDelta,
    );
  }
}
