import 'dart:typed_data';

import '../models/graph_document.dart';

class PortalGraphPackage {
  const PortalGraphPackage(
      {required this.document, required this.blobs, required this.name});

  final GraphDocument document;
  final Map<String, Uint8List> blobs;
  final String name;
}

class PortalUploadResult {
  const PortalUploadResult({required this.key, required this.message});

  final String key;
  final String message;
}

abstract class BugManPortalService {
  bool get isAvailable;

  Future<PortalUploadResult> saveGraph(
    GraphDocument document,
    Map<String, Uint8List> blobs, {
    String? existingKey,
  });

  Future<PortalUploadResult> uploadGraph(
    GraphDocument document,
    Map<String, Uint8List> blobs,
  );

  Future<PortalGraphPackage> loadGraph(String key);
}
