import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import '../models/graph_document.dart';
import 'graph_repository.dart';

GraphRepository createGraphRepository() => IndexedDbGraphRepository();

class IndexedDbGraphRepository implements GraphRepository {
  static const _databaseName = 'bugman-graphs';
  static const _documentsStore = 'documents';
  static const _blobsStore = 'photo-blobs';
  Database? _database;

  Future<Database> get _db async => _database ??= await idbFactoryBrowser.open(
        _databaseName,
        version: 1,
        onUpgradeNeeded: (event) {
          final database = event.database;
          if (!database.objectStoreNames.contains(_documentsStore)) {
            database.createObjectStore(_documentsStore);
          }
          if (!database.objectStoreNames.contains(_blobsStore)) {
            database.createObjectStore(_blobsStore);
          }
        },
      );

  @override
  Future<List<SavedGraphSummary>> listGraphs() async {
    final database = await _db;
    final transaction = database.transaction(_documentsStore, idbModeReadOnly);
    final values = await transaction.objectStore(_documentsStore).getAll();
    await transaction.completed;
    final result = <SavedGraphSummary>[];
    for (final value in values) {
      if (value is! String) continue;
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final document = GraphDocument.fromJson(
          decoded.map((key, item) => MapEntry(key.toString(), item)),
        );
        result.add(summaryForDocument(document));
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<GraphDocument?> loadGraph(String id) async {
    final database = await _db;
    final transaction = database.transaction(_documentsStore, idbModeReadOnly);
    final value = await transaction.objectStore(_documentsStore).getObject(id);
    await transaction.completed;
    if (value is! String) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) return null;
    return GraphDocument.fromJson(
      decoded.map((key, item) => MapEntry(key.toString(), item)),
    );
  }

  @override
  Future<void> saveGraph(
    GraphDocument document, {
    Map<String, Uint8List> blobs = const {},
    Set<String> deletedBlobKeys = const {},
  }) async {
    final database = await _db;
    final transaction = database.transaction(
      [_documentsStore, _blobsStore],
      idbModeReadWrite,
    );
    await transaction
        .objectStore(_documentsStore)
        .put(jsonEncode(document.toJson()), document.id);
    final blobStore = transaction.objectStore(_blobsStore);
    for (final entry in blobs.entries) {
      await blobStore.put(entry.value, entry.key);
    }
    for (final key in deletedBlobKeys) {
      await blobStore.delete(key);
    }
    await transaction.completed;
  }

  @override
  Future<void> deleteGraph(String id) async {
    final document = await loadGraph(id);
    final database = await _db;
    final transaction = database.transaction(
      [_documentsStore, _blobsStore],
      idbModeReadWrite,
    );
    await transaction.objectStore(_documentsStore).delete(id);
    if (document != null) {
      final blobStore = transaction.objectStore(_blobsStore);
      for (final attachment in document.attachments) {
        if (attachment.blobKey.isNotEmpty) {
          await blobStore.delete(attachment.blobKey);
        }
        if (attachment.thumbnailKey.isNotEmpty) {
          await blobStore.delete(attachment.thumbnailKey);
        }
      }
    }
    await transaction.completed;
  }

  @override
  Future<Uint8List?> loadBlob(String key) async {
    final database = await _db;
    final transaction = database.transaction(_blobsStore, idbModeReadOnly);
    final value = await transaction.objectStore(_blobsStore).getObject(key);
    await transaction.completed;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }
}
