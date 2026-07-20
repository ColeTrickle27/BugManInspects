import 'graph_point.dart';

/// How a graph's real-world measurements were established.
enum MeasurementSource {
  legacyCanvasScale,
  mapGeodesic,
  calibratedImage,
}

/// Communicates whether measurements are suitable for downstream calculations.
enum MeasurementAccuracyStatus {
  uncalibrated,
  estimated,
  verified,
  outsideTolerance,
  modifiedSinceVerification,
}

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  factory GeoPoint.fromJson(Map<String, Object?> json) => GeoPoint(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      );

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Relates canvas coordinates to real-world metres.
///
/// Legacy graphs retain the original 24 px/ft behavior, while calibrated
/// images can store an explicit scale. Map traces do not use this scale for
/// measurement; their latitude/longitude vertices remain authoritative.
class MeasurementCalibration {
  const MeasurementCalibration({
    required this.source,
    required this.status,
    this.metersPerCanvasUnit,
    this.residualErrorMeters,
    this.verifiedAt,
    this.note = '',
  });

  factory MeasurementCalibration.legacy() => const MeasurementCalibration(
        source: MeasurementSource.legacyCanvasScale,
        status: MeasurementAccuracyStatus.estimated,
        metersPerCanvasUnit: 0.3048 / 24,
        note: 'Legacy 24 px/ft canvas scale',
      );

  factory MeasurementCalibration.fromJson(Map<String, Object?> json) {
    T readEnum<T extends Enum>(
      Iterable<T> values,
      Object? value,
      T fallback,
    ) =>
        values.firstWhere(
          (item) => item.name == value,
          orElse: () => fallback,
        );

    return MeasurementCalibration(
      source: readEnum(
        MeasurementSource.values,
        json['source'],
        MeasurementSource.legacyCanvasScale,
      ),
      status: readEnum(
        MeasurementAccuracyStatus.values,
        json['status'],
        MeasurementAccuracyStatus.estimated,
      ),
      metersPerCanvasUnit: (json['metersPerCanvasUnit'] as num?)?.toDouble(),
      residualErrorMeters: (json['residualErrorMeters'] as num?)?.toDouble(),
      verifiedAt: json['verifiedAt'] is String
          ? DateTime.tryParse(json['verifiedAt']! as String)
          : null,
      note: json['note']?.toString() ?? '',
    );
  }

  final MeasurementSource source;
  final MeasurementAccuracyStatus status;
  final double? metersPerCanvasUnit;
  final double? residualErrorMeters;
  final DateTime? verifiedAt;
  final String note;

  bool get isUsableForBusinessCalculations =>
      status == MeasurementAccuracyStatus.verified;

  Map<String, Object?> toJson() => {
        'source': source.name,
        'status': status.name,
        'metersPerCanvasUnit': metersPerCanvasUnit,
        'residualErrorMeters': residualErrorMeters,
        'verifiedAt': verifiedAt?.toIso8601String(),
        'note': note,
      };
}

/// A traced map feature stores both geographic and canvas coordinates.
/// Geographic coordinates own measurements; canvas coordinates only own
/// presentation and hit testing.
class TraceGeometry {
  const TraceGeometry({
    required this.id,
    required this.label,
    required this.geoPoints,
    required this.canvasPoints,
    this.closed = true,
  });

  factory TraceGeometry.fromJson(Map<String, Object?> json) => TraceGeometry(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        geoPoints: (json['geoPoints'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((value) => GeoPoint.fromJson(
                  value.map((key, item) => MapEntry(key.toString(), item)),
                ))
            .toList(),
        canvasPoints: (json['canvasPoints'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((value) => GraphPoint(
                  x: (value['x'] as num?)?.toDouble() ?? 0,
                  y: (value['y'] as num?)?.toDouble() ?? 0,
                ))
            .toList(),
        closed: json['closed'] as bool? ?? true,
      );

  final String id;
  final String label;
  final List<GeoPoint> geoPoints;
  final List<GraphPoint> canvasPoints;
  final bool closed;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'geoPoints': geoPoints.map((point) => point.toJson()).toList(),
        'canvasPoints':
            canvasPoints.map((point) => {'x': point.x, 'y': point.y}).toList(),
        'closed': closed,
      };
}
