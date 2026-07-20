import 'package:flutter_test/flutter_test.dart';

import 'package:bugman_graphs/main.dart';
import 'package:bugman_graphs/models/graph_shape.dart';
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
    expect(_shapeCount(tester), 0);

    await tester.tapAt(const Offset(500, 240));
    await tester.tapAt(const Offset(460, 430));
    await tester.pump();
    expect(_shapeCount(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_shapeCount(tester), 1);
    expect(find.text('Shape Properties'), findsNothing);
  });

  testWidgets('Escape cancels an unfinished structure', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectStructure(tester, 'Garage/Carport');

    await tester.tapAt(const Offset(280, 240));
    await tester.tapAt(const Offset(500, 240));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(_shapeCount(tester), 0);
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

    expect(_shapeCount(tester), 1);
  });

  testWidgets('property line closes and shows acreage summary on canvas',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await _selectPropertyTool(tester, 'Property Line (acres)');
    await tester.tapAt(const Offset(300, 250));
    await tester.tapAt(const Offset(500, 250));
    await tester.tapAt(const Offset(500, 450));
    await tester.tap(find.text('Finish'));
    await tester.pump();

    expect(_shapeCount(tester), 1);
    final summaryCard = find.byKey(
      const ValueKey('property-line-measurement-summary'),
    );
    expect(summaryCard, findsOneWidget);
    expect(
      find.descendant(
        of: summaryCard,
        matching: find.text('Property Line (acres)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summaryCard,
        matching: find.textContaining(' sf • '),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summaryCard,
        matching: find.textContaining(' lf'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('generic shapes require drag and double-click opens properties',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await _selectBasicShape(tester, 'Rectangle');
    await tester.pump();
    await tester.tapAt(const Offset(300, 250));
    await tester.pump();
    expect(_shapeCount(tester), 0);

    await tester.dragFrom(const Offset(300, 250), const Offset(220, 170));
    await tester.pump();
    expect(_shapeCount(tester), 1);
    expect(find.text('Shape Properties'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.tapAt(const Offset(410, 335));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(410, 335));
    await tester.pumpAndSettle();
    expect(find.text('Shape Properties'), findsOneWidget);
  });

  testWidgets('deleting a finished shape removes its backing lines',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await _selectBasicShape(tester, 'Rectangle');
    await tester.dragFrom(const Offset(300, 250), const Offset(220, 170));
    await tester.pump();
    expect(_shapeCount(tester), 1);
    expect(_wallCount(tester), 4);

    await tester.tap(find.byTooltip('Delete selection'));
    await tester.pump();

    expect(_shapeCount(tester), 0);
    expect(_wallCount(tester), 0);
  });

  testWidgets('main and quick toolbars collapse independently', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    expect(find.text('Select V'), findsNothing);
    expect(find.text('Pan H'), findsNothing);
    expect(find.byType(CanvasQuickToolbar), findsOneWidget);

    await tester.tap(find.byTooltip('Hide main toolbar'));
    await tester.pump();
    expect(find.byType(CanvasToolbar), findsNothing);
    expect(find.byTooltip('Show main toolbar'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide quick toolbar'));
    await tester.pump();
    expect(find.byType(CanvasQuickToolbar), findsNothing);
    expect(find.byTooltip('Show quick toolbar'), findsOneWidget);
  });

  testWidgets('properties and layers start collapsed in bottom toolbar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(910, 794);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    expect(find.text('Properties'), findsNothing);
    expect(find.text('Layers'), findsNothing);
    expect(find.byTooltip('Properties panel'), findsOneWidget);
    expect(find.byTooltip('Layers panel'), findsOneWidget);
    expect(find.byTooltip('Delete selection'), findsOneWidget);

    final viewerWidth = tester.getSize(find.byType(InteractiveViewer)).width;
    await tester.tap(find.byTooltip('Layers panel'));
    await tester.pump();
    expect(find.text('Layers'), findsWidgets);
    expect(tester.getSize(find.byType(InteractiveViewer)).width, viewerWidth);

    await tester.tap(find.byTooltip('Properties panel'));
    await tester.pump();
    expect(find.text('Properties'), findsWidgets);
    expect(tester.getSize(find.byType(InteractiveViewer)).width, viewerWidth);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('Properties'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('Properties'), findsWidgets);
  });

  testWidgets('top toolbar keeps file and canvas options collapsed',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(910, 794);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Upload'), findsNothing);
    expect(find.text('20:1'), findsNothing);

    await tester.tap(find.byTooltip('File actions'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    await tester.tapAt(const Offset(600, 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Canvas options'));
    await tester.pumpAndSettle();
    expect(find.text('Snap to grid'), findsOneWidget);
    expect(find.text('Snap to objects'), findsOneWidget);
    expect(find.text('10:1'), findsOneWidget);
    expect(find.text('20:1'), findsNothing);
  });

  testWidgets('main toolbar tools can be dragged into quick tools',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    final quickMeasure = find.byTooltip(
      'Quick Measure\nHold and drag to customize quick tools',
    );
    final quickToolbar = find.byKey(const ValueKey('canvas-quick-toolbar'));
    expect(quickMeasure, findsOneWidget);
    expect(quickToolbar, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(quickMeasure),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(quickToolbar));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final toolbar = tester.widget<CanvasQuickToolbar>(
      find.byType(CanvasQuickToolbar),
    );
    expect(
      toolbar.actions,
      contains(
        const CanvasToolbarAction.preset(
          GraphDrawingPreset.measurementLine,
        ),
      ),
    );
  });

  testWidgets('drawing tools can overlap shapes and place markers inside them',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await _selectBasicShape(tester, 'Rectangle');
    await tester.dragFrom(const Offset(300, 250), const Offset(220, 170));
    await tester.pump();
    expect(_shapeCount(tester), 1);

    await _selectBasicShape(tester, 'Rectangle');
    await tester.dragFrom(const Offset(350, 290), const Offset(110, 90));
    await tester.pump();
    expect(_shapeCount(tester), 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.tapAt(const Offset(410, 335));
    await tester.pump();
    expect(_annotationCount(tester), 1);
    expect(find.text('Item Properties'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.tapAt(const Offset(410, 335));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Item Properties'), findsNothing);
    await tester.tapAt(const Offset(410, 335));
    await tester.pump();
    expect(find.text('Item Properties'), findsOneWidget);
  });

  testWidgets('selected shape rotation handle rotates the finished shape',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await _selectBasicShape(tester, 'Rectangle');
    await tester.dragFrom(const Offset(300, 250), const Offset(220, 170));
    await tester.pump();
    expect(_shapeCount(tester), 1);
    expect(_firstShapeRotation(tester), 0);

    await tester.dragFrom(const Offset(410, 222), const Offset(70, 55));
    await tester.pump();

    expect(_firstShapeRotation(tester), isNot(closeTo(0, 0.1)));
  });

  testWidgets(
      'iPad-sized touch drag moves an object without drawing a structure',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);

    await _selectBasicShape(tester, 'Rectangle');
    await tester.dragFrom(const Offset(250, 220), const Offset(180, 140));
    await tester.pump();
    expect(_shapeCount(tester), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    final touch = await tester.startGesture(
      const Offset(340, 290),
      kind: PointerDeviceKind.touch,
    );
    await touch.moveBy(const Offset(80, 60));
    await touch.up();
    await tester.pump();

    expect(_shapeCount(tester), 1);
    expect(find.text('Shape Properties'), findsNothing);
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
      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Structures'), findsOneWidget);
      expect(find.text('Inspection Markers'), findsOneWidget);
      expect(find.text('Treatment Markers'), findsOneWidget);
      expect(find.byType(CanvasQuickToolbar), findsOneWidget);
      expect(find.byTooltip('Select (V)'), findsOneWidget);
      expect(find.byTooltip('Pan (H)'), findsOneWidget);
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
    await _selectLineTool(tester, 'Line');
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
    expect(_shapeCount(tester), 0);
    expect(_annotationCount(tester), 0);

    await tester.tapAt(center - const Offset(80, 0));
    await tester.tapAt(center + const Offset(80, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Line Properties'), findsNothing);
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
    await tester.sendEventToBinding(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, -120),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pump();
    expect(
        matrix().getMaxScaleOnAxis(), greaterThan(initial.getMaxScaleOnAxis()));

    final beforeControl = matrix();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(PointerScrollEvent(
      position: center,
      scrollDelta: const Offset(0, 80),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
        matrix().entry(0, 3), isNot(closeTo(beforeControl.entry(0, 3), 0.1)));

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
    await _selectLineTool(tester, 'Line');
    await tester.tapAt(const Offset(320, 260));
    await tester.tapAt(const Offset(500, 260));
    await tester.tapAt(const Offset(500, 420));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(500, 420));
    await tester.pumpAndSettle();

    expect(_shapeCount(tester), 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Finish closes and saves a multi-point line', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectLineTool(tester, 'Line');
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

    expect(_shapeCount(tester), 1);
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

    expect(_shapeCount(tester), 1);
    expect(find.text('Line Properties'), findsNothing);
  });

  testWidgets('right-click removes only the latest unfinished line point',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectLineTool(tester, 'Line');
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
    expect(_shapeCount(tester), 1);
  });

  testWidgets('thin line selection uses reduced but practical tolerance',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await _pumpEditor(tester);
    await _selectLineTool(tester, 'Line');
    await tester.dragFrom(const Offset(320, 300), const Offset(260, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.pump();

    await tester.tapAt(const Offset(450, 326));
    await tester.pump();
    expect(find.text('Line Properties'), findsNothing);

    await tester.tapAt(const Offset(450, 306));
    await tester.pump();
    expect(find.text('Shape Properties'), findsNothing);

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

dynamic _graphOverlayPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const ValueKey('graph-canvas-paint')))
    .foregroundPainter as dynamic;

int _shapeCount(WidgetTester tester) =>
    (_graphOverlayPainter(tester).shapes as List).length;

int _wallCount(WidgetTester tester) =>
    (_graphOverlayPainter(tester).wallSegments as List).length;

int _annotationCount(WidgetTester tester) =>
    (_graphOverlayPainter(tester).annotations as List).length;

double _firstShapeRotation(WidgetTester tester) =>
    (_graphOverlayPainter(tester).shapes as List).first.rotationDegrees
        as double;

Future<void> _secondaryClick(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.down(position);
  await gesture.up();
}

Future<void> _selectStructure(WidgetTester tester, String label) async {
  if (label == 'Main Structure') {
    await tester.ensureVisible(find.text('MAIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MAIN'));
    await tester.pumpAndSettle();
    return;
  }

  await tester.ensureVisible(find.text('Building Features'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Building Features'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectBasicShape(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text('Basic Shapes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Basic Shapes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectPropertyTool(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text('Property'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Property'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectLineTool(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text('Lines'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lines'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
