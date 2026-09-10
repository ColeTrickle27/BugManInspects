import 'package:bugman_graphs/models/graph_document.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/services/graph_repository.dart';
import 'package:bugman_graphs/services/customer_identity_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('optional contact snapshot survives graph save, load and job editing',
      () {
    final job = Job(
        customerName: 'Acme',
        serviceAddress: '1 Main St',
        pestPacLocationNumber: '990001',
        pestPacBillToNumber: '100',
        serviceType: 'Inspection',
        createdBy: 'Tester',
        createdDate: DateTime(2026),
        intakeDetails: const {
          'company': 'Acme',
          'phone': '555-0100',
          'email': 'test@example.com',
          'contactName': 'Office contact',
          'contactPhone': '555-0101',
          'city': 'Raleigh',
          'zip': '27601'
        });
    final restored = GraphDocument.fromJson(GraphDocument.forJob(job).toJson());
    expect(restored.customer.intakeDetails, job.intakeDetails);
    final editable = summaryForDocument(restored).job;
    expect(editable.intakeDetails, job.intakeDetails);
    restored.updateJob(editable);
    expect(restored.customer.intakeDetails, job.intakeDetails);
    final oldJson = restored.customer.toJson()..remove('intakeDetails');
    final oldCustomer = GraphCustomerInfo.fromJson(oldJson);
    expect(oldCustomer.intakeDetails, isEmpty);
    expect(oldCustomer.name, 'Acme');
    expect(oldCustomer.serviceAddress, '1 Main St');
  });

  test(
      'canonical lookup accepts permanent complete identity and copies contacts',
      () {
    final row = <String, Object?>{
      'locationId': 'loc-id',
      'billToId': 'bill-id',
      'identityState': 'permanent',
      'pestpacBillToNumber': '100',
      'pestpacLocationNumber': '990001',
      'customerName': 'Acme',
      'locationName': 'Main Office',
      'serviceAddress': '1 Main St',
      'phone': '555-0100',
      'email': 'test@example.com'
    };
    final result = canonicalCustomerSearchResult(row)!;
    expect(result.location.phone, '555-0100');
    expect(result.location.email, 'test@example.com');
    expect(result.location.locationNumber, '990001');
    expect(result.location.billToName, 'Acme');
    expect(
        canonicalCustomerSearchResult({...row, 'identityState': 'temporary'}),
        isNull);
    expect(
        canonicalCustomerSearchResult({...row, 'pestpacLocationNumber': null}),
        isNull);
    expect(canonicalCustomerSearchResult({...row, 'locationId': ''}), isNull);
  });
}
