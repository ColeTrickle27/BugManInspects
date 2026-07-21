import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'graph_export_legend.dart';

class GraphPdfPhoto {
  const GraphPdfPhoto({
    required this.referenceLabel,
    required this.filename,
    required this.bytes,
  });

  final String referenceLabel;
  final String filename;
  final Uint8List bytes;
}

class GraphPdfExport {
  const GraphPdfExport._();

  static Future<Uint8List> build({
    required Uint8List graphPng,
    required String title,
    List<GraphLegendSection> legend = const [],
    List<GraphPdfPhoto> photos = const [],
  }) async {
    final document = pw.Document(
      title: title,
      creator: 'BugMan Graphs',
    );
    final image = pw.MemoryImage(graphPng);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
            if (legend.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              for (final section in legend) ...[
                pw.Text(
                  section.title,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final entry in section.entries)
                      pw.SizedBox(
                        width: 155,
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 9,
                              height: 9,
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromInt(entry.color.toARGB32()),
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                '${entry.markerType.shortLabel}  ${entry.markerType.label}',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
    for (var start = 0; start < photos.length; start += 2) {
      final pagePhotos = photos.skip(start).take(2).toList(growable: false);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '$title - Photo Appendix',
                style: const pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              for (final photo in pagePhotos)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 14),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${photo.referenceLabel}  ${photo.filename}',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Expanded(
                          child: pw.Center(
                            child: pw.Image(
                              pw.MemoryImage(photo.bytes),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return document.save();
  }
}
