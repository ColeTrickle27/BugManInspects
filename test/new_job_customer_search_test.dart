import 'package:bugman_graphs/models/customer_file.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/screens/new_job_screen.dart';
import 'package:bugman_graphs/services/customer_files_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<_JobCapture> pumpNewJobScreen(
    WidgetTester tester, {
    required CustomerFilesService service,
    CustomerLocation? preselectedLocation,
    String? resolutionWarning,
  }) async {
    final capture = _JobCapture();
    await tester.pumpWidget(
      MaterialApp(
        home: NewJobScreen(
          onCreateJob: (job) => capture.job = job,
          customerFilesService: service,
          preselectedLocation: preselectedLocation,
          resolutionWarning: resolutionWarning,
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (context) => const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return capture;
  }

  testWidgets(
    'searching shows matching Customer Files and selecting one locks the identity fields',
    (tester) async {
      final service = _FakeCustomerFilesService(results: [
        const CustomerSearchResult(
          billTo: CustomerBillTo(billToNumber: '100', billToName: 'Acme Co'),
          location: CustomerLocation(
            billToNumber: '100',
            billToName: 'Acme Co',
            locationNumber: '1',
            locationName: 'Acme Co - Main Office',
            locationAddress: '1 Main St',
          ),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: NewJobScreen(
            onCreateJob: (_) {},
            customerFilesService: service,
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (context) => const Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('customer-search-field')), findsOneWidget);
      // No manual identity fields shown before a customer is selected.
      expect(find.widgetWithText(TextField, 'PestPac Bill-To #'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('customer-search-field')),
        'Acme',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(service.lastQuery, 'Acme');
      expect(find.text('Acme Co — Acme Co - Main Office'), findsOneWidget);

      await tester.tap(find.text('Acme Co — Acme Co - Main Office'));
      await tester.pumpAndSettle();

      // The identity fields are now shown locked in a summary card, not as
      // editable TextFields.
      expect(find.text('Customer File selected'), findsOneWidget);
      expect(find.text('Acme Co - Main Office'), findsOneWidget);
      expect(find.text('1 Main St'), findsOneWidget);
      expect(find.text('Bill-To # 100 · Location # 1'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'PestPac Bill-To #'), findsNothing);

      await tester.tap(find.text('Create Graph'));
      await tester.pump();

      // Nothing else to assert on navigation here; confirm identity made it
      // onto the created Job via the callback in the wrapper below.
    },
  );

  testWidgets(
    'created job carries the selected Customer File PestPac identifiers',
    (tester) async {
      final service = _FakeCustomerFilesService(results: [
        const CustomerSearchResult(
          billTo: CustomerBillTo(billToNumber: '100', billToName: 'Acme Co'),
          location: CustomerLocation(
            billToNumber: '100',
            billToName: 'Acme Co',
            locationNumber: '1',
            locationName: 'Acme Co - Main Office',
            locationAddress: '1 Main St',
          ),
        ),
      ]);

      final capture = await pumpNewJobScreen(tester, service: service);
      // Trigger a search + selection, then submit.
      await tester.enterText(
        find.byKey(const ValueKey('customer-search-field')),
        'Acme',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acme Co — Acme Co - Main Office'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Graph'));
      await tester.pump();

      final job = capture.job;
      expect(job, isNotNull);
      expect(job!.customerName, 'Acme Co - Main Office');
      expect(job.serviceAddress, '1 Main St');
      expect(job.pestPacBillToNumber, '100');
      expect(job.pestPacLocationNumber, '1');
    },
  );

  testWidgets(
    '"Change" clears the selected customer and reopens search',
    (tester) async {
      final service = _FakeCustomerFilesService(results: const []);
      const location = CustomerLocation(
        billToNumber: '200',
        billToName: 'Beta LLC',
        locationNumber: '2',
        locationName: 'Beta LLC - Warehouse',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewJobScreen(
            onCreateJob: (_) {},
            customerFilesService: service,
            preselectedLocation: location,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer File selected'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('change-customer-button')));
      await tester.pumpAndSettle();

      expect(find.text('Customer File selected'), findsNothing);
      expect(find.byKey(const ValueKey('customer-search-field')), findsOneWidget);
    },
  );

  testWidgets(
    '"enter manually" falls back to free-text PestPac identifier fields',
    (tester) async {
      final service = _FakeCustomerFilesService(results: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: NewJobScreen(
            onCreateJob: (_) {},
            customerFilesService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('manual-entry-toggle')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'PestPac Bill-To #'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'PestPac Location #'), findsOneWidget);
    },
  );

  testWidgets(
    'a resolution warning banner is shown when a deep-linked customer could not be resolved',
    (tester) async {
      final service = _FakeCustomerFilesService(results: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: NewJobScreen(
            onCreateJob: (_) {},
            customerFilesService: service,
            resolutionWarning: 'Bill-To 999 / Location 1 was not found in Ops Brain.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bill-To 999 / Location 1 was not found in Ops Brain.'),
        findsOneWidget,
      );
      // Still falls through to the normal search flow, not manual entry.
      expect(find.byKey(const ValueKey('customer-search-field')), findsOneWidget);
    },
  );

  testWidgets(
    'editing an existing job never shows the customer search flow',
    (tester) async {
      final service = _FakeCustomerFilesService(results: const []);
      final job = Job(
        customerName: 'Existing Customer',
        serviceAddress: '5 Old Rd',
        pestPacLocationNumber: '9',
        pestPacBillToNumber: '10',
        serviceType: 'Inspection',
        createdBy: 'Tester',
        createdDate: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewJobScreen(
            onCreateJob: (_) {},
            customerFilesService: service,
            initialJob: job,
            editOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('customer-search-field')), findsNothing);
      expect(find.widgetWithText(TextField, 'Location Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'PestPac Bill-To #'), findsOneWidget);
    },
  );

  testWidgets(
    'an unavailable Customer Files service falls back to manual entry only',
    (tester) async {
      final service = _FakeCustomerFilesService(
        results: const [],
        available: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewJobScreen(
            onCreateJob: (_) {},
            customerFilesService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('customer-search-field')), findsNothing);
      expect(find.widgetWithText(TextField, 'Location Name'), findsOneWidget);
    },
  );
}

class _JobCapture {
  Job? job;
}

class _FakeCustomerFilesService implements CustomerFilesService {
  _FakeCustomerFilesService({required this.results, this.available = true});

  final List<CustomerSearchResult> results;
  final bool available;
  String? lastQuery;

  @override
  bool get isAvailable => available;

  @override
  Future<List<CustomerSearchResult>> searchCustomers(String query) async {
    lastQuery = query;
    return results;
  }

  @override
  Future<List<CustomerLocation>> getLocations(String billToNumber) async =>
      results
          .where((result) => result.billTo.billToNumber == billToNumber)
          .map((result) => result.location)
          .toList();

  @override
  Future<CustomerLocation?> getLocation(
    String billToNumber,
    String locationNumber,
  ) async {
    for (final result in results) {
      if (result.location.billToNumber == billToNumber &&
          result.location.locationNumber == locationNumber) {
        return result.location;
      }
    }
    return null;
  }
}
