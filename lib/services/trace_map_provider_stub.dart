import 'package:flutter/material.dart';

import '../models/trace_geometry.dart';
import 'trace_map_provider.dart';

TraceMapProvider createTraceMapProvider() => UnsupportedTraceMapProvider();

class UnsupportedTraceMapProvider implements TraceMapProvider {
  @override
  Future<void> initialize() async {
    throw const TraceMapConfigurationException(
      'Satellite tracing is currently available in the web app.',
    );
  }

  @override
  Future<GeoPoint?> geocode(String address) async => null;

  @override
  Widget buildMap({
    required GeoPoint center,
    required List<GeoPoint> points,
    required ValueChanged<GeoPoint> onMapTap,
    required void Function(int index, GeoPoint point) onVertexMoved,
  }) =>
      const SizedBox.shrink();
}
