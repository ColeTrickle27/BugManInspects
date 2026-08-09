// Regression test for the PDF export bug (BugMan Graphs production pass,
// item 13).
//
// Root cause (two layered bugs, both exercised here):
// 1. _exportGraph() used to load a marker-icon font from
//    assets/fonts/MaterialIcons-Regular.otf via rootBundle.load(), but that
//    file was never declared under pubspec.yaml's `flutter: assets:` list
//    (and didn't exist in the project at all) -- every PDF export threw and
//    was swallowed by _exportGraph()'s catch block, while PNG export (which
//    never touches this asset) always worked.
// 2. Even after bundling the real MaterialIcons-Regular.otf, the `pdf`
//    package (3.13.0) detects a font's Unicode support by checking for the
//    raw TrueType `glyf` table signature (bytes 0x00010000). Material
//    Icons' font is CFF-flavored OpenType (`OTTO` signature), so it is
//    misdetected as non-Unicode. The package then tries to Latin1-encode
//    the Material Icon glyph's private-use-area codepoint and throws
//    ("Cannot decode the string to Latin1... use a TrueType (TTF) font
//    instead"). This is a real limitation of embedding this specific font
//    file as a PDF glyph via this package version, not a fixable one-line
//    bug -- so the real fix removes the icon-glyph-in-PDF feature and keeps
//    GraphPdfExport's existing solid-color-square legend fallback instead,
//    which has no font/encoding dependency at all.
//
// This test builds a full PDF using the exact same call shape as
// GraphCanvasScreen._exportGraph()'s current (fixed) PDF path -- a
// populated legend, measurement summary, and photos, with no
// markerIconFontBytes -- and validates the resulting bytes are a real,
// non-trivial PDF, not just that the build call didn't throw.
import 'dart:convert';

import 'package:bugman_graphs/models/graph_annotation.dart';
import 'package:bugman_graphs/services/graph_export_legend.dart';
import 'package:bugman_graphs/services/graph_pdf_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('branding logo asset still loads (no regression)', () async {
    final logoBytes =
        (await rootBundle.load('assets/branding/holloman_exterminators.png'))
            .buffer
            .asUint8List();
    expect(logoBytes.length, greaterThan(0));
  });

  test(
    'PDF export succeeds end-to-end with a populated legend, measurement '
    'summary, and photos -- the exact shape GraphCanvasScreen._exportGraph() '
    'now builds for the PDF path',
    () async {
      final onePixelPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

      final legend = [
        GraphLegendSection(
          title: 'Inspection Markers',
          entries: [
            GraphLegendEntry(
              markerType: GraphMarkerType.damage,
              color: GraphMarkerType.damage.defaultColor,
              icon: Icons.warning_amber_rounded,
            ),
            GraphLegendEntry(
              markerType: GraphMarkerType.moistureReading,
              color: GraphMarkerType.moistureReading.defaultColor,
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
      ];

      final bytes = await GraphPdfExport.build(
        graphPng: onePixelPng,
        title: 'PDF Export Regression Test',
        legend: legend,
        measurementSummary: const [
          GraphMeasurementSummary(label: 'Perimeter', measurements: ['40 ft']),
        ],
        photos: [
          GraphPdfPhoto(
            referenceLabel: '1a',
            filename: 'crawlspace.jpg',
            bytes: onePixelPng,
          ),
        ],
        // Intentionally no markerIconFontBytes -- see file-level comment.
      );

      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(500));
    },
  );
}
