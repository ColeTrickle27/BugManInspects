import 'dart:typed_data';

import '../models/graph_document.dart';
import 'graph_repository.dart';

GraphRepository createGraphRepository() => MemoryGraphRepository();

class MemoryGraphRepository implements GraphRepository {
  final Map<String, Map<String, Object?>> _documents = {};
  final Map<String, Uint8List> _blobs = {};

  @override
  Future<List<SavedGraphSummary>> listGraphs() async {
    final result = _documents.values
        .map((json) => summaryForDocument(GraphDocument.fromJson(json)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<GraphDocument?> loadGraph(String id) async {
    final json = _documents[id];
    return json == null ? null : GraphDocument.fromJson(json);
  }

  @override
  Future<void> saveGraph(
    GraphDocument document, {
    Map<String, Uint8List> blobs = const {},
    Set<String> deletedBlobKeys = const {},
  }) async {
    _documents[document.id] = document.toJson();
    _blobs.addAll(blobs);
    for (final key in deletedBlobKeys) {
      _blobs.remove(key);
    }
  }

  @override
  Future<void> deleteGraph(String id) async {
    final json = _documents.remove(id);
    if (json == null) return;
    final document = GraphDocument.fromJson(json);
    for (final attachment in document.attachments) {
      if (attachment.blobKey.isNotEmpty) {
        _blobs.remove(attachment.blobKey);
      }
      if (attachment.thumbnailKey.isNotEmpty) {
        _blobs.remove(attachment.thumbnailKey);
      }
    }
  }

  @override
  Future<Uint8List?> loadBlob(String key) async => _blobs[key];
}
