import 'graph_photo_service.dart';

GraphPhotoPicker createGraphPhotoPicker() => _UnsupportedPhotoPicker();

class _UnsupportedPhotoPicker implements GraphPhotoPicker {
  @override
  Future<PickedGraphPhoto?> capture() async => null;

  @override
  Future<List<PickedGraphPhoto>> chooseMultiple() async => [];
}
