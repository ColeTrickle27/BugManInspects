import 'package:flutter_test/flutter_test.dart';

import 'package:bugman_graphs/main.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/screens/graph_canvas_screen.dart';
import 'package:bugman_graphs/screens/new_job_screen.dart';
import 'package:bugman_graphs/theme/app_theme.dart';
import 'package:bugman_graphs/widgets/canvas_toolbar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('BugMan Graphs starts on the job list', (tester) async {
    await tester.pumpWidget(const BugManGraphsApp());

    expect(find.text('BugMan Graphs'), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('New Job'), findsOneWidget);
    expect(find.byKey(const ValueKey('holloman-logo')), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final theme = materialApp.theme!;
    expect(theme.colorScheme.primary, AppColors.red);
    expect(theme.colorScheme.secondary, AppColors.black);
    expect(theme.colorScheme.outline, AppColors.wolfGrey);
    expect(theme.colorScheme.surface, AppColors.white);
    expect(theme.colorScheme.onPrimary, AppColors.white);
  });

  testWidgets('New Job shows optional metadata fields and approved services',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BugManGraphsApp());

    await tester.tap(find.text('New Job'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.decoration?.labelText)
        .toList();
    expect(fields, [
      'Date',
      'Location Name',
      'Location Address',
      'PestPac Location #',
      'PestPac Bill-To #',
      'Created By',
    ]);

    final today = DateTime.now();
    final expectedDate = '${today.month.toString().padLeft(2, '0')}/'
        '${today.day.toString().padLeft(2, '0')}/'
        '${today.year.toString().padLeft(4, '0')}';
    final dateField = tester.widget<TextField>(
      find.byKey(const ValueKey('job-date-field')),
    );
    expect(dateField.controller?.text, expectedDate);
    expect(dateField.readOnly, isTrue);

    final serviceType = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(NewJobScreen.serviceTypes,
        ['Inspection', 'WDIR', 'ATBS Installation', 'General Use']);
    expect(serviceType.initialValue, 'Inspection');
    expect(find.text('Termite Inspection'), findsNothing);
    expect(find.text('Termite Treatment'), findsNothing);
    expect(find.text('Rodent Inspection'), findsNothing);
    expect(find.text('General Pest'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('job-date-field')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Create Graph'), findsOneWidget);
  });

  testWidgets('blank New Job submission opens an Untitled Job graph',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BugManGraphsApp());

    await tester.tap(find.text('New Job'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Graph'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNothing);
    expect(find.text('Untitled Job'), findsOneWidget);
    expect(find.byType(GraphCanvasScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Untitled Job'), findsOneWidget);
    expect(find.textContaining('Location #'), findsNothing);
    expect(find.textContaining('Bill-To #'), findsNothing);
  });

  testWidgets('job card labels both populated PestPac identifiers',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BugManGraphsApp());

    await tester.tap(find.text('New Job'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'PestPac Location #'),
      'LOC-42',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'PestPac Bill-To #'),
      'BILL-84',
    );
    await tester.tap(find.text('Create Graph'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Location # LOC-42'), findsOneWidget);
    expect(find.text('Bill-To # BILL-84'), findsOneWidget);
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

  for (final size in const [Size(1440, 900), Size(1024, 768)]) {
    testWidgets('initial canvas is centered in the usable viewport at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await _pumpEditor(tester);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final viewport = tester.getSize(find.byType(InteractiveViewer));
      final matrix = viewer.transformationController!.value;

      expect(matrix.entry(0, 3), closeTo((viewport.width - 3600) / 2, 0.1));
      expect(matrix.entry(1, 3), closeTo((viewport.height - 2600) / 2, 0.1));
      expect(find.text('Drawing Tools'), findsOneWidget);
      expect(find.text('Structures'), findsOneWidget);
      expect(find.text('Inspection Markers'), findsOneWidget);
      expect(find.text('Treatment Markers'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CanvasToolbar),
          matching: find.text('Shapes'),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('Spacebar drag pans without drawing and restores the line tool',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await tester.tap(find.byTooltip('Line (L)'));
    await tester.pump();

    final viewerBefore = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final before = viewerBefore.transformationController!.value.clone();
    final center = tester.getCenter(find.byType(InteractiveViewer));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(90, 55));
    await gesture.up();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();

    final after = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    expect(after.entry(0, 3), isNot(closeTo(before.entry(0, 3), 0.1)));
    expect(find.text('0 overlays'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);

    await tester.tapAt(center - const Offset(80, 0));
    await tester.tapAt(center + const Offset(80, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Line Properties'), findsOneWidget);
  });

  testWidgets('modifier wheel controls zoom and both scroll axes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    final center = tester.getCenter(find.byType(InteractiveViewer));
    Matrix4 matrix() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .clone();

    final initial = matrix();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, -120),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
        matrix().getMaxScaleOnAxis(), greaterThan(initial.getMaxScaleOnAxis()));

    final beforeAlt = matrix();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendEventToBinding(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, 80),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(matrix().entry(0, 3), isNot(closeTo(beforeAlt.entry(0, 3), 0.1)));

    final beforeShift = matrix();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, 80),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(matrix().entry(1, 3), isNot(closeTo(beforeShift.entry(1, 3), 0.1)));
  });

  testWidgets('line double-click closes and finishes the plotted path',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await tester.tap(find.byTooltip('Line (L)'));
    await tester.tapAt(const Offset(320, 260));
    await tester.tapAt(const Offset(500, 260));
    await tester.tapAt(const Offset(500, 420));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(500, 420));
    await tester.pumpAndSettle();

    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Finish closes and saves a multi-point line', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await tester.tap(find.byTooltip('Line (L)'));
    await tester.tapAt(const Offset(320, 260));
    await tester.tapAt(const Offset(500, 260));
    await tester.tapAt(const Offset(500, 420));
    await tester.tap(find.text('Finish').first);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Finish')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Treatment Area plots points and double-click closes the area',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    final picker = find.byTooltip('Treatment Marker: Treatment Area');
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Treatment Area').last);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 240));
    await tester.tapAt(const Offset(520, 240));
    await tester.tapAt(const Offset(480, 430));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(480, 430));
    await tester.pumpAndSettle();

    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.text('Treatment Area'), findsWidgets);
  });

  testWidgets('right-click removes only the latest unfinished line point',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await tester.tap(find.byTooltip('Line (L)'));
    await tester.tapAt(const Offset(320, 260));
    await tester.tapAt(const Offset(500, 260));
    await _secondaryClick(tester, const Offset(500, 260));
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) =>
          widget is Tooltip &&
          widget.message == 'Latest plotted point removed'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(500, 300));
    await tester.tapAt(const Offset(500, 430));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(500, 430));
    await tester.pumpAndSettle();
    expect(find.text('1 overlays'), findsOneWidget);
  });

  testWidgets('thin line selection uses reduced but practical tolerance',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await tester.tap(find.byTooltip('Line (L)'));
    await tester.dragFrom(const Offset(320, 300), const Offset(260, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.pump();

    await tester.tapAt(const Offset(450, 326));
    await tester.pump();
    expect(find.text('Line Properties'), findsNothing);

    await tester.tapAt(const Offset(450, 306));
    await tester.pump();
    expect(find.text('Line Properties'), findsOneWidget);
  });
}

Future<void> _pumpEditor(WidgetTester tester) async {
  final job = Job(
    customerName: 'Interaction Test',
    serviceAddress: '1 Canvas Way',
    pestPacLocationNumber: 'TEST-1',
    pestPacBillToNumber: 'BILL-1',
    serviceType: 'Inspection',
    createdBy: 'Widget Test',
    createdDate: DateTime(2026, 7, 18),
  );
  await tester.pumpWidget(MaterialApp(home: GraphCanvasScreen(job: job)));
  await tester.pumpAndSettle();
}

Future<void> _secondaryClick(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.down(position);
  await gesture.up();
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
