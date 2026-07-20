import 'package:bugman_graphs/models/graph_annotation.dart';
import 'package:bugman_graphs/models/graph_point.dart';
import 'package:bugman_graphs/services/graph_export_legend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legend includes only placed inspection and treatment markers', () {
    const point = GraphPoint(x: 10, y: 20);
    final legend = buildGraphLegend(const [
      GraphAnnotation(
        kind: GraphAnnotationKind.marker,
        point: point,
        label: '18%',
        markerType: GraphMarkerType.moisture,
      ),
      GraphAnnotation(
        kind: GraphAnnotationKind.marker,
        point: point,
        label: 'Termite Activity',
        markerType: GraphMarkerType.termiteActivity,
      ),
      GraphAnnotation(
        kind: GraphAnnotationKind.marker,
        point: point,
        label: 'Bait Station',
        markerType: GraphMarkerType.baitStation,
      ),
      GraphAnnotation(
        kind: GraphAnnotationKind.marker,
        point: point,
        label: 'HVAC',
        markerType: GraphMarkerType.hvacUnit,
      ),
      GraphAnnotation(
        kind: GraphAnnotationKind.photo,
        point: point,
        label: 'Photo',
        markerType: GraphMarkerType.camera,
      ),
    ]);

    expect(legend.map((section) => section.title), [
      'Inspection Markers',
      'Treatment Markers',
    ]);
    expect(
      legend.first.entries.map((entry) => entry.markerType),
      [GraphMarkerType.moisture, GraphMarkerType.termiteActivity],
    );
    expect(
      legend.last.entries.map((entry) => entry.markerType),
      [GraphMarkerType.baitStation],
    );
  });
}
