import 'graph_photo_service.dart';

Future<OptimizedGraphPhoto> optimizeGraphPhotoAsync({
  required PickedGraphPhoto source,
  required String annotationId,
  required String attachmentId,
  String referenceLabel = '',
}) async =>
    optimizeGraphPhoto(
      source: source,
      annotationId: annotationId,
      attachmentId: attachmentId,
      referenceLabel: referenceLabel,
    );
