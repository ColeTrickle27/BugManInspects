import 'package:flutter_test/flutter_test.dart';

import 'package:bugman_graphs/main.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/screens/graph_canvas_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('BugMan Graphs starts on the job list', (tester) async {
    await tester.pumpWidget(const BugManGraphsApp());

    expect(find.text('BugMan Graphs'), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('New Job'), findsOneWidget);
  });

  testWidgets(
      'plain click selects an existing shape while drag uses the active tool',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    final job = Job(
      customerName: 'Interaction Test',
      serviceAddress: '1 Canvas Way',
      pestPacAccountNumber: 'TEST-1',
      serviceType: 'Termite Inspection',
      createdBy: 'Widget Test',
      createdDate: DateTime(2026, 7, 16),
    );

    await tester.pumpWidget(
      MaterialApp(home: GraphCanvasScreen(job: job)),
    );
    await tester.pump();

    await tester.tap(find.text('MAIN'));
    await tester.pump();
    await tester.dragFrom(
      const Offset(300, 250),
      const Offset(260, 220),
    );
    await tester.pump();

    expect(find.text('1 overlays'), findsOneWidget);

    await tester.tap(find.text('SLAB'));
    await tester.pump();
    await tester.tapAt(const Offset(430, 360));
    await tester.pump();

    expect(find.text('1 overlays'), findsOneWidget);
    expect(find.text('Shape Properties'), findsOneWidget);

    await tester.dragFrom(
      const Offset(430, 360),
      const Offset(240, 180),
    );
    await tester.pump();

    expect(find.text('2 overlays'), findsOneWidget);
  });
}
