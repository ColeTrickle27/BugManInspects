import 'dart:typed_data';

import '../models/graph_document.dart';
import '../models/job.dart';

class SavedGraphSummary {
  const SavedGraphSummary({
    required this.id,
    required this.job,
    required this.updatedAt,
    this.isPersisted = true,
  });

  final String id;
  final Job job;
  final DateTime updatedAt;
  final bool isPersisted;
}

abstract class GraphRepository {
  Future<List<SavedGraphSummary>> listGraphs();

  Future<GraphDocument?> loadGraph(String id);

  Future<void> saveGraph(
    GraphDocument document, {
    Map<String, Uint8List> blobs = const {},
    Set<String> deletedBlobKeys = const {},
  });

  Future<Uint8List?> loadBlob(String key);
}

SavedGraphSummary summaryForDocument(GraphDocument document) =>
    SavedGraphSummary(
      id: document.id,
      job: Job(
        id: document.id,
        customerName: document.customer.name,
        serviceAddress: document.customer.serviceAddress,
        pestPacLocationNumber: document.customer.pestPacLocationNumber,
        pestPacBillToNumber: document.customer.pestPacBillToNumber,
        serviceType: document.customer.serviceType,
        createdBy: document.customer.createdBy,
        createdDate: document.createdAt,
      ),
      updatedAt: document.updatedAt,
    );
