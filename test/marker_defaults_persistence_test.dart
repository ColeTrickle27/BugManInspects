// Regression coverage for item 5: "Set as Default" must persist marker
// style choices across the app lifecycle (survives a fresh screen instance
// backed by the same store, simulating an app restart), new markers of that
// type must pick up the persisted defaults, and reopening/selecting other
// markers must never retroactively change annotations created before the
// default was changed.
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/screens/graph_canvas_screen.dart';
import 'package:bugman_graphs/services/marker_defaults_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the real localStorage-backed store. Reusing the
/// same instance across two [GraphCanvasScreen] pumps simulates data that
/// truly survived an app restart, since a fresh screen/state object reads
/// from it exactly like it would read from real persisted storage.
class _FakeMarkerDefaultsStore implements MarkerDefaultsStore {
  Map<String, Map<String, Object?>>? _data;

  @override
  Map<String, Map<String, Object?>>? load() {
    final data = _data;
    if (data == null) return null;
    return data.map((key, value) => MapEntry(key, Map.of(value)));
  }

  @override
  void save(Map<String, Map<String, Object?>> data) {
    _data = data.map((key, value) => MapEntry(key, Map.of(value)));
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  MarkerDefaultsStore store, {
  required String jobSuffix,
}) async {
  // Each pump uses a distinct job identity so it starts from a brand-new,
  // empty document rather than resuming a previously auto-saved one - the
  // marker defaults store is the only thing meant to carry over between
  // pumps here, simulating an app restart that opens a different graph.
  final job = Job(
    customerName: 'Marker Defaults Test $jobSuffix',
    serviceAddress: '1 Canvas Way $jobSuffix',
    pestPacLocationNumber: 'TEST-$jobSuffix',
    pestPacBillToNumber: 'BILL-$jobSuffix',
    serviceType: 'Inspection',
    createdBy: 'Widget Test',
    createdDate: DateTime(2026, 7, 18),
  );
  // A distinct key forces Flutter to fully dispose the previous State and
  // create a brand-new one (rather than reusing it via didUpdateWidget),
  // which is what actually happens across a real app restart/new job.
  await tester.pumpWidget(MaterialApp(
    home: GraphCanvasScreen(
      key: ValueKey('graph-canvas-screen-$jobSuffix'),
      job: job,
      markerDefaultsStore: store,
    ),
  ));
  await tester.pumpAndSettle();
}

dynamic _graphOverlayPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const ValueKey('graph-canvas-paint')))
    .foregroundPainter as dynamic;

List<dynamic> _annotations(WidgetTester tester) =>
    (_graphOverlayPainter(tester).annotations as List).cast<dynamic>();

Future<void> _expandToolbarSection(
  WidgetTester tester,
  String label,
  Finder visibleChild,
) async {
  if (visibleChild.evaluate().isNotEmpty) return;
  final sectionLabel = find.text(label);
  await tester.ensureVisible(sectionLabel);
  await tester.pumpAndSettle();
  await tester.tap(sectionLabel);
  await tester.pumpAndSettle();
}

Future<void> _placeTermiteActivityMarker(
  WidgetTester tester,
  Offset position,
) async {
  final markerTool = find.byTooltip(
    'Termite Activity\nHold and drag to customize quick tools',
  );
  await _expandToolbarSection(
    tester,
    'Inspection Findings',
    markerTool,
  );
  await tester.ensureVisible(markerTool);
  await tester.pumpAndSettle();
  await tester.tap(markerTool.hitTestable());
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Set as Default persists a marker size across a simulated app restart, '
    'is picked up by new markers, and never retroactively changes existing '
    'annotations',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);

      final store = _FakeMarkerDefaultsStore();
      expect(store.load(), isNull);

      // --- Session 1: place two termite-activity markers, then change
      // the SECOND one's size and set it as the new default. ---
      await _pumpEditor(tester, store, jobSuffix: '1');
      await _placeTermiteActivityMarker(tester, const Offset(300, 260));
      await _placeTermiteActivityMarker(tester, const Offset(600, 500));
      expect(_annotations(tester).length, 2);

      final originalFirstSize = _annotations(tester)[0].size as double;
      final originalSecondSize = _annotations(tester)[1].size as double;
      expect(originalFirstSize, originalSecondSize,
          reason: 'both should start from the same built-in default size');

      // Select the second marker (switch to Select tool, tap it twice —
      // matches the existing selection pattern used elsewhere in this
      // suite for entering the selected state).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.tapAt(const Offset(600, 500));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(const Offset(600, 500));
      await tester.pumpAndSettle();
      expect(find.text('Item Properties'), findsOneWidget);

      // Change size via the Size slider's callback directly (avoids
      // fragile pixel-perfect drag-distance math) and set as default.
      final sizeSlider = tester.widgetList<Slider>(find.byType(Slider)).first;
      const newSize = 1.7;
      expect(newSize, isNot(originalSecondSize));
      sizeSlider.onChanged!(newSize);
      await tester.pumpAndSettle();

      expect(_annotations(tester)[1].size, newSize);
      // The first marker (created before the change) must be untouched.
      expect(_annotations(tester)[0].size, originalFirstSize);

      await tester.tap(find.text('Set as Default'));
      await tester.pumpAndSettle();

      // Persisted store now has an entry for termiteActivity.
      final persisted = store.load();
      expect(persisted, isNotNull);
      expect(persisted!['termiteActivity']?['size'], newSize);

      // Setting the default must not retroactively change either existing
      // annotation's stored size.
      expect(_annotations(tester)[0].size, originalFirstSize);
      expect(_annotations(tester)[1].size, newSize);

      // --- Session 2: brand-new screen/state instance, same store,
      // simulating an app restart. A newly placed termite-activity marker
      // must use the persisted default size. ---
      await _pumpEditor(tester, store, jobSuffix: '2');
      await _placeTermiteActivityMarker(tester, const Offset(400, 350));
      expect(_annotations(tester).length, 1);
      expect(_annotations(tester)[0].size, newSize,
          reason: 'a marker placed after a simulated restart must use the '
              'persisted default, not the built-in default');
    },
  );
}
