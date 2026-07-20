import 'dart:ui';

import 'package:bugman_graphs/models/graph_document.dart';
import 'package:bugman_graphs/models/graph_point.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/models/wall_segment.dart';
import 'package:bugman_graphs/services/export_bounds_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export bounds follow graph content instead of full canvas', () {
    final document = GraphDocument.forJob(
      Job(
        customerName: 'Bounds',
        serviceAddress: '',
        pestPacLocationNumber: '',
        pestPacBillToNumber: '',
        serviceType: 'Inspection',
        createdBy: '',
        createdDate: DateTime(2026, 7, 19),
      ),
    )..replaceWallSegments(const [
        WallSegment(
          start: GraphPoint(x: 100, y: 200),
          end: GraphPoint(x: 300, y: 400),
        ),
      ]);

    final bounds = ExportBoundsCalculator.forDocument(
      document,
      padding: 20,
      canvasSize: const Size(3600, 2600),
    );

    expect(bounds, const Rect.fromLTRB(80, 180, 320, 420));
  });
}
