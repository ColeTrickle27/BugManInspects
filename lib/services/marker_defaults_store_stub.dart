import 'marker_defaults_store.dart';

/// Non-web fallback: keeps defaults in memory only for the lifetime of the
/// process (e.g. tests, or a future native build). No durable persistence is
/// available outside the browser today.
MarkerDefaultsStore createPlatformMarkerDefaultsStore() =>
    _InMemoryMarkerDefaultsStore();

class _InMemoryMarkerDefaultsStore implements MarkerDefaultsStore {
  Map<String, Map<String, Object?>>? _data;

  @override
  Map<String, Map<String, Object?>>? load() => _data;

  @override
  void save(Map<String, Map<String, Object?>> data) {
    _data = data;
  }
}
