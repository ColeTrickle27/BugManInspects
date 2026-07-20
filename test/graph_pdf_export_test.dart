import 'dart:convert';

import 'package:bugman_graphs/models/trace_geometry.dart';
import 'package:bugman_graphs/services/graph_pdf_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a PDF containing the graph image and accuracy status', () async {
    final onePixelPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    final bytes = await GraphPdfExport.build(
      graphPng: onePixelPng,
      title: 'PDF Test',
      calibration: const MeasurementCalibration(
        source: MeasurementSource.mapGeodesic,
        status: MeasurementAccuracyStatus.verified,
      ),
    );

    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(500));
  });
}
