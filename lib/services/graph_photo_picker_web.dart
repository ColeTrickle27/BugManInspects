// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'graph_photo_service.dart';

GraphPhotoPicker createGraphPhotoPicker() => BrowserGraphPhotoPicker();

class BrowserGraphPhotoPicker implements GraphPhotoPicker {
  @override
  Future<List<PickedGraphPhoto>> chooseMultiple() => _pick(multiple: true);

  @override
  Future<PickedGraphPhoto?> capture() async {
    final photos = await _pick(multiple: false, capture: true);
    return photos.isEmpty ? null : photos.first;
  }

  Future<List<PickedGraphPhoto>> _pick({
    required bool multiple,
    bool capture = false,
  }) async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = multiple;
    if (capture) input.setAttribute('capture', 'environment');
    final completer = Completer<List<PickedGraphPhoto>>();
    var changeObserved = false;
    void completeWithNoSelection(html.Event _) {
      if (!changeObserved && !completer.isCompleted) {
        completer.complete(const []);
      }
    }

    input.addEventListener('cancel', completeWithNoSelection);
    late final StreamSubscription<html.Event> focusSubscription;
    focusSubscription = html.window.onFocus.listen((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!changeObserved &&
          !completer.isCompleted &&
          (input.files?.isEmpty ?? true)) {
        completer.complete(const []);
      }
    });
    input.onChange.listen((_) async {
      changeObserved = true;
      final files = input.files ?? const <html.File>[];
      final photos = <PickedGraphPhoto>[];
      for (final file in files) {
        photos.add(
          PickedGraphPhoto(name: file.name, bytes: await _readFile(file)),
        );
      }
      if (!completer.isCompleted) completer.complete(photos);
    });
    input.click();
    final result = await completer.future;
    await focusSubscription.cancel();
    input.removeEventListener('cancel', completeWithNoSelection);
    return result;
  }

  Future<Uint8List> _readFile(html.File file) async {
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result is ByteBuffer) return result.asUint8List();
    if (result is Uint8List) return result;
    throw const FormatException('The selected image could not be read');
  }
}
