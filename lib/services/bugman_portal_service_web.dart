import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/graph_document.dart';
import 'bugman_portal_service.dart';

BugManPortalService createPortalService() => HttpBugManPortalService();

class HttpBugManPortalService implements BugManPortalService {
  @override
  bool get isAvailable => Uri.base.path.startsWith('/bugman-graphs/');

  @override
  Future<PortalUploadResult> uploadGraph(
    GraphDocument document,
    Map<String, Uint8List> blobs,
  ) async {
    final response = await http.post(
      Uri.parse('/api/bugman-graphs/upload'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'bugman-graph',
        'version': 1,
        'document': document.toJson(),
        'blobs': {
          for (final entry in blobs.entries)
            entry.key: base64Encode(entry.value),
        },
      }),
    );
    final payload = _decodeResponse(response);
    return PortalUploadResult(
      key: payload['key']?.toString() ?? '',
      message: payload['message']?.toString() ?? 'Graph uploaded.',
    );
  }

  @override
  Future<PortalGraphPackage> loadGraph(String key) async {
    final uri = Uri.parse('/api/bugman-graphs/load')
        .replace(queryParameters: {'key': key});
    final response = await http.get(uri);
    final payload = _decodeResponse(response);
    final graph = payload['graph'];
    if (graph is! Map || graph['document'] is! Map) {
      throw const FormatException('This BugMan graph could not be opened.');
    }
    final documentJson = (graph['document'] as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final blobs = <String, Uint8List>{};
    final encodedBlobs = graph['blobs'];
    if (encodedBlobs is Map) {
      for (final entry in encodedBlobs.entries) {
        if (entry.value is String) {
          blobs[entry.key.toString()] = base64Decode(entry.value as String);
        }
      }
    }
    return PortalGraphPackage(
      document: GraphDocument.fromJson(documentJson),
      blobs: blobs,
      name: payload['name']?.toString() ?? 'BugMan Graph',
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? decoded.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['error']?.toString() ??
            'Holloman Ops Brain request failed (${response.statusCode}).',
      );
    }
    return payload;
  }
}
