import 'dart:typed_data';

void notifySalesBrainGraphSaved(String graphKey) {}

void Function() listenForPresentationExport({
  required String graphKey,
  required Future<Uint8List> Function() capture,
}) =>
    () {};
