import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/trace_geometry.dart';

class GraphPdfExport {
  const GraphPdfExport._();

  static Future<Uint8List> build({
    required Uint8List graphPng,
    required String title,
    required MeasurementCalibration calibration,
  }) async {
    final document = pw.Document(
      title: title,
      creator: 'BugMan Graphs',
    );
    final image = pw.MemoryImage(graphPng);
    final accuracy = switch (calibration.status) {
      MeasurementAccuracyStatus.verified => 'Verified',
      MeasurementAccuracyStatus.estimated => 'Estimated',
      MeasurementAccuracyStatus.uncalibrated => 'Uncalibrated',
      MeasurementAccuracyStatus.outsideTolerance => 'Outside tolerance',
      MeasurementAccuracyStatus.modifiedSinceVerification =>
        'Modified since verification',
    };

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Measurement status: $accuracy'),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }
}
