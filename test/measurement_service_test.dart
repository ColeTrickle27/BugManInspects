import 'package:bugman_graphs/models/graph_point.dart';
import 'package:bugman_graphs/models/trace_geometry.dart';
import 'package:bugman_graphs/services/measurement_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy calibration retains 24 pixels per foot', () {
    final meters = MeasurementService.measureCanvasDistanceMeters(
      const GraphPoint(x: 0, y: 0),
      const GraphPoint(x: 24, y: 0),
      MeasurementCalibration.legacy(),
    );

    expect(meters, closeTo(0.3048, 0.0000001));
  });

  test('map trace measurements are independent of canvas coordinates', () {
    const geographicPoints = [
      GeoPoint(latitude: 35, longitude: -86),
      GeoPoint(latitude: 35, longitude: -85.9999),
      GeoPoint(latitude: 35.0001, longitude: -85.9999),
      GeoPoint(latitude: 35.0001, longitude: -86),
    ];
    const first = TraceGeometry(
      id: 'parcel',
      label: 'Property',
      geoPoints: geographicPoints,
      canvasPoints: [
        GraphPoint(x: 0, y: 0),
        GraphPoint(x: 10, y: 0),
        GraphPoint(x: 10, y: 10),
        GraphPoint(x: 0, y: 10),
      ],
    );
    const zoomed = TraceGeometry(
      id: 'parcel',
      label: 'Property',
      geoPoints: geographicPoints,
      canvasPoints: [
        GraphPoint(x: 100, y: 100),
        GraphPoint(x: 900, y: 100),
        GraphPoint(x: 900, y: 900),
        GraphPoint(x: 100, y: 900),
      ],
    );

    final firstResult = MeasurementService.measureTrace(
      first,
      status: MeasurementAccuracyStatus.estimated,
    );
    final zoomedResult = MeasurementService.measureTrace(
      zoomed,
      status: MeasurementAccuracyStatus.estimated,
    );

    expect(firstResult.linearMeters, closeTo(zoomedResult.linearMeters, 1e-9));
    expect(firstResult.squareMeters, closeTo(zoomedResult.squareMeters, 1e-9));
    expect(firstResult.squareMeters, greaterThan(90));
    expect(firstResult.squareMeters, lessThan(120));
    expect(firstResult.isUsableForBusinessCalculations, isFalse);
  });

  test('only verified measurements can drive business calculations', () {
    const trace = TraceGeometry(
      id: 'line',
      label: 'Treatment run',
      closed: false,
      geoPoints: [
        GeoPoint(latitude: 35, longitude: -86),
        GeoPoint(latitude: 35.0001, longitude: -86),
      ],
      canvasPoints: [],
    );

    final result = MeasurementService.measureTrace(
      trace,
      status: MeasurementAccuracyStatus.verified,
    );

    expect(result.linearMeters, closeTo(11.12, 0.05));
    expect(result.squareMeters, 0);
    expect(result.isUsableForBusinessCalculations, isTrue);
  });
}
