import 'dart:math' as math;

import '../models/graph_point.dart';
import '../models/trace_geometry.dart';

class MeasurementResult {
  const MeasurementResult({
    required this.linearMeters,
    required this.squareMeters,
    required this.status,
  });

  final double linearMeters;
  final double squareMeters;
  final MeasurementAccuracyStatus status;

  double get linearFeet => linearMeters * 3.280839895013123;
  double get squareFeet => squareMeters * 10.763910416709722;
  double get acres => squareMeters / 4046.8564224;

  bool get isUsableForBusinessCalculations =>
      status == MeasurementAccuracyStatus.verified;
}

/// Central measurement engine. Real-world values are kept in SI units and
/// converted only for display/reporting.
class MeasurementService {
  const MeasurementService._();

  static const double earthRadiusMeters = 6371008.8;

  static MeasurementResult measureTrace(
    TraceGeometry trace, {
    required MeasurementAccuracyStatus status,
  }) {
    final points = trace.geoPoints;
    if (points.length < 2) {
      return MeasurementResult(
        linearMeters: 0,
        squareMeters: 0,
        status: status,
      );
    }

    var length = 0.0;
    for (var index = 1; index < points.length; index += 1) {
      length += geodesicDistanceMeters(points[index - 1], points[index]);
    }
    if (trace.closed && points.length > 2) {
      length += geodesicDistanceMeters(points.last, points.first);
    }

    return MeasurementResult(
      linearMeters: length,
      squareMeters: trace.closed && points.length > 2
          ? geodesicAreaSquareMeters(points)
          : 0,
      status: status,
    );
  }

  static double measureCanvasDistanceMeters(
    GraphPoint start,
    GraphPoint end,
    MeasurementCalibration calibration,
  ) {
    final scale = calibration.metersPerCanvasUnit;
    if (scale == null || scale <= 0) {
      throw StateError('Canvas measurement requires a valid calibration');
    }
    return start.distanceTo(end) * scale;
  }

  static double geodesicDistanceMeters(GeoPoint start, GeoPoint end) {
    final latitude1 = _radians(start.latitude);
    final latitude2 = _radians(end.latitude);
    final latitudeDelta = latitude2 - latitude1;
    final longitudeDelta = _radians(end.longitude - start.longitude);
    final sinLatitude = math.sin(latitudeDelta / 2);
    final sinLongitude = math.sin(longitudeDelta / 2);
    final haversine = sinLatitude * sinLatitude +
        math.cos(latitude1) * math.cos(latitude2) * sinLongitude * sinLongitude;
    return 2 * earthRadiusMeters * math.asin(math.sqrt(haversine.clamp(0, 1)));
  }

  /// Spherical polygon area using the Chamberlain-Duquette method.
  /// Suitable for parcel-sized map traces and independent of screen zoom.
  static double geodesicAreaSquareMeters(List<GeoPoint> points) {
    if (points.length < 3) return 0;

    var sum = 0.0;
    for (var index = 0; index < points.length; index += 1) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      var longitudeDelta = _radians(next.longitude - current.longitude);
      if (longitudeDelta > math.pi) longitudeDelta -= 2 * math.pi;
      if (longitudeDelta < -math.pi) longitudeDelta += 2 * math.pi;
      sum += longitudeDelta *
          (2 +
              math.sin(_radians(current.latitude)) +
              math.sin(_radians(next.latitude)));
    }
    return (sum * earthRadiusMeters * earthRadiusMeters / 2).abs();
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
