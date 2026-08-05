import 'dart:typed_data';

import '../models/graph_document.dart';
import 'bugman_portal_service.dart';

BugManPortalService createPortalService() => UnavailableBugManPortalService();

class UnavailableBugManPortalService implements BugManPortalService {
  @override
  bool get isAvailable => false;

  @override
  Future<PortalGraphPackage> loadGraph(String key) =>
      Future.error(UnsupportedError('Holloman Ops Brain is unavailable.'));

  @override
  Future<PortalUploadResult> uploadGraph(
    GraphDocument document,
    Map<String, Uint8List> blobs,
  ) =>
      Future.error(UnsupportedError('Holloman Ops Brain is unavailable.'));
}
