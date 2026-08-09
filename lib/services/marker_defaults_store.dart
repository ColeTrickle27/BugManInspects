/// Persists the user's "Set as Default" marker style choices (color + size
/// per [GraphMarkerType]) so they survive app restarts/reloads.
///
/// This does NOT retroactively change any already-placed marker annotation —
/// annotations bake in their own color/size at creation time. This store only
/// affects which color/size is pre-selected the next time a marker type is
/// chosen from the toolbar.
abstract class MarkerDefaultsStore {
  /// Returns the persisted defaults as `{markerTypeName: {'color': argbInt,
  /// 'size': double}}`, or `null` if nothing has been saved yet or
  /// persistence is unavailable on this platform.
  Map<String, Map<String, Object?>>? load();

  /// Persists the full set of marker defaults. Keyed by
  /// `GraphMarkerType.name` so entries remain stable across enum reordering.
  void save(Map<String, Map<String, Object?>> data);
}
