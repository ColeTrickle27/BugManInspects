import 'package:flutter_test/flutter_test.dart';

import 'package:bugman_graphs/main.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/screens/graph_canvas_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('BugMan Graphs starts on the job list', (tester) async {
    await tester.pumpWidget(const BugManGraphsApp());

    expect(find.text('BugMan Graphs'), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('New Job'), findsOneWidget);
  });

  testWidgets('structure plotting requires points and Enter completes it',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectStructure(tester, 'Detached Structure');

    await tester.tapAt(const Offset(280, 240));
    await tester.pump();
    expect(find.text('0 overlays'), findsOneWidget);

    await tester.tapAt(const Offset(500, 240));
    await tester.tapAt(const Offset(460, 430));
    await tester.pump();
    expect(find.text('0 overlays'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.text('Shape Properties'), findsOneWidget);
  });

  testWidgets('Escape cancels an unfinished structure', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectStructure(tester, 'Garage');

    await tester.tapAt(const Offset(280, 240));
    await tester.tapAt(const Offset(500, 240));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('0 overlays'), findsOneWidget);
  });

  testWidgets('double-click completes an in-progress structure',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectStructure(tester, 'Crawlspace');

    await tester.tapAt(const Offset(280, 240));
    await tester.tapAt(const Offset(500, 240));
    await tester.tapAt(const Offset(460, 430));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(460, 430));
    await tester.pump();

    expect(find.text('1 overlays'), findsOneWidget);
  });

  testWidgets('generic shapes require drag and support text editing',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await tester.tap(find.textContaining('Rectangle').first);
    await tester.pump();
    await tester.tapAt(const Offset(300, 250));
    await tester.pump();
    expect(find.text('0 overlays'), findsOneWidget);

    await tester.dragFrom(const Offset(300, 250), const Offset(220, 170));
    await tester.pump();
    expect(find.text('1 overlays'), findsOneWidget);

    await tester.tapAt(const Offset(410, 335));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(410, 335));
    await tester.pumpAndSettle();
    expect(find.text('Edit shape text'), findsOneWidget);
  });

  testWidgets(
      'existing object selection and movement override an active structure tool',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await tester.tap(find.textContaining('Rectangle').first);
    await tester.dragFrom(const Offset(300, 250), const Offset(220, 170));
    await tester.pump();
    expect(find.text('1 overlays'), findsOneWidget);

    await _selectStructure(tester, 'Slab');
    await tester.tapAt(const Offset(410, 335));
    await tester.pump();
    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.text('Shape Properties'), findsOneWidget);

    await tester.dragFrom(const Offset(410, 335), const Offset(120, 80));
    await tester.pump();
    expect(find.text('1 overlays'), findsOneWidget);

    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(find.text('1 overlays'), findsOneWidget);
    await _sendShortcut(
      tester,
      LogicalKeyboardKey.keyZ,
      shift: true,
    );
    expect(find.text('1 overlays'), findsOneWidget);

    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    await _sendShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(find.text('0 overlays'), findsOneWidget);
    await _sendShortcut(tester, LogicalKeyboardKey.keyY);
    expect(find.text('1 overlays'), findsOneWidget);
  });

  testWidgets(
      'iPad-sized touch drag moves an object without drawing a structure',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await tester.ensureVisible(find.textContaining('Rectangle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Rectangle').first);
    await tester.dragFrom(const Offset(250, 220), const Offset(180, 140));
    await tester.pump();
    expect(find.text('1 overlays'), findsOneWidget);

    await _selectStructure(tester, 'Detached Structure');
    final touch = await tester.startGesture(
      const Offset(340, 290),
      kind: PointerDeviceKind.touch,
    );
    await touch.moveBy(const Offset(80, 60));
    await touch.up();
    await tester.pump();

    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.text('Shape Properties'), findsOneWidget);
  });
}

Future<void> _pumpEditor(WidgetTester tester) async {
  final job = Job(
    customerName: 'Interaction Test',
    serviceAddress: '1 Canvas Way',
    pestPacAccountNumber: 'TEST-1',
    serviceType: 'Termite Inspection',
    createdBy: 'Widget Test',
    createdDate: DateTime(2026, 7, 18),
  );
  await tester.pumpWidget(MaterialApp(home: GraphCanvasScreen(job: job)));
  await tester.pump();
}

Future<void> _selectStructure(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text('MAIN'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('MAIN'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _sendShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}
