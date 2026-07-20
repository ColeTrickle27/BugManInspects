import 'dart:typed_data';

import 'package:bugman_graphs/models/graph_document.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/services/graph_repository_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository saves, lists, opens, and restores photo blobs', () async {
    final repository = MemoryGraphRepository();
    final document = GraphDocument.forJob(
      Job(
        customerName: 'Saved Location',
        serviceAddress: '1 Main St',
        pestPacLocationNumber: '42',
        pestPacBillToNumber: '84',
        serviceType: 'Inspection',
        createdBy: 'Test',
        createdDate: DateTime(2026, 7, 20),
      ),
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    await repository.saveGraph(document, blobs: {'photo-1': bytes});

    final summaries = await repository.listGraphs();
    expect(summaries.single.id, document.id);
    expect(summaries.single.job.displayName, 'Saved Location');
    expect((await repository.loadGraph(document.id))?.customer.name,
        'Saved Location');
    expect(await repository.loadBlob('photo-1'), bytes);
  });
}
