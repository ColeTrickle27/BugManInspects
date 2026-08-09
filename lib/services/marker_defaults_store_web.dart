// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'marker_defaults_store.dart';

/// localStorage-backed persistence for marker style defaults on Flutter Web.
/// `window.localStorage` access is synchronous, so no async/race handling is
/// needed around app startup.
const String _storageKey = 'bugman_graphs.marker_defaults.v1';

MarkerDefaultsStore createPlatformMarkerDefaultsStore() =>
    _WebMarkerDefaultsStore();

class _WebMarkerDefaultsStore implements MarkerDefaultsStore {
  @override
  Map<String, Map<String, Object?>>? load() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final result = <String, Map<String, Object?>>{};
      decoded.forEach((key, value) {
        if (key is String && value is Map) {
          result[key] = value.map(
            (k, v) => MapEntry(k.toString(), v),
          );
        }
      });
      return result;
    } catch (_) {
      // Corrupt or unavailable storage should never crash the app; fall back
      // to built-in defaults.
      return null;
    }
  }

  @override
  void save(Map<String, Map<String, Object?>> data) {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(data);
    } catch (_) {
      // Storage may be unavailable (e.g. private browsing quota); silently
      // skip persistence rather than surfacing an error to the user.
    }
  }
}
