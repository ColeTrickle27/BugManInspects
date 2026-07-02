import 'package:flutter_test/flutter_test.dart';

import 'package:bugman_graphs/main.dart';

void main() {
  testWidgets('BugMan Graphs starts on the job list', (tester) async {
    await tester.pumpWidget(const BugManGraphsApp());

    expect(find.text('BugMan Graphs'), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('New Job'), findsOneWidget);
  });
}
