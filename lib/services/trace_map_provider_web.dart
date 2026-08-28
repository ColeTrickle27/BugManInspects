import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../models/trace_geometry.dart';
import 'trace_map_provider.dart';

TraceMapProvider createTraceMapProvider() => NorthCarolinaTraceMapProvider();

class NorthCarolinaTraceMapProvider implements TraceMapProvider {
  // NC OneMap publishes this fused tile cache alongside the dynamic WMS
  // service. Keeping the same imagery provider preserves the field tracing
  // workflow while avoiding per-tile WMS rendering work.
  static const String _imageryTileUrl =
      'https://services.nconemap.gov/secure/rest/services/Imagery/'
      'Orthoimagery_Latest_cached/ImageServer/tile/{z}/{y}/{x}';

  @override
  Future<void> initialize() async {}

  @override
  Widget buildMap({
    required GeoPoint center,
    required GeoPoint selectedAddress,
    required List<GeoPoint> points,
    required ValueChanged<GeoPoint> onMapTap,
    required void Function(int index, GeoPoint point) onVertexMoved,
  }) {
    final mapPoints = <latlong.LatLng>[
      for (final point in points)
        latlong.LatLng(point.latitude, point.longitude),
    ];
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: latlong.LatLng(
              center.latitude,
              center.longitude,
            ),
            initialZoom: 19,
            initialCameraFit: mapPoints.length >= 2
                ? CameraFit.coordinates(
                    coordinates: mapPoints,
                    padding: const EdgeInsets.all(56),
                    maxZoom: 19,
                  )
                : null,
            minZoom: 4,
            // The NC OneMap cache's usable finest scale is level 20. Allowing
            // level 21 requests blank tiles, which leaves the trace map white.
            maxZoom: 20,
            onTap: (_, position) => onMapTap(
              GeoPoint(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _imageryTileUrl,
              maxNativeZoom: 20,
              userAgentPackageName: 'com.holloman.bugman_graphs',
            ),
            // This is a temporary trace-workspace aid only. It represents the
            // selected address result, not a saved graph object or an
            // inspection marker.
            MarkerLayer(
              markers: [
                Marker(
                  point: latlong.LatLng(
                    selectedAddress.latitude,
                    selectedAddress.longitude,
                  ),
                  width: 40,
                  height: 40,
                  child: const Tooltip(
                    message: 'Selected address',
                    child: Icon(
                      Icons.gps_fixed,
                      key: ValueKey('trace-search-result-pin'),
                      color: Color(0xFF1565C0),
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
            if (mapPoints.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: mapPoints,
                    color: const Color(0x33CC2000),
                    borderColor: const Color(0xFFCC2000),
                    borderStrokeWidth: 4,
                  ),
                ],
              ),
            if (mapPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: mapPoints,
                    color: const Color(0xFFCC2000),
                    strokeWidth: 4,
                  ),
                ],
              ),
            DragMarkers(
              markers: [
                for (var index = 0; index < mapPoints.length; index += 1)
                  DragMarker(
                    point: mapPoints[index],
                    // Keep a comfortable drag target while making the visible
                    // pin small enough to place close property corners.
                    size: const Size(36, 36),
                    builder: (context, position, isDragging) => Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: _VertexPin(number: index + 1),
                      ),
                    ),
                    onDragEnd: (_, position) => onVertexMoved(
                      index,
                      GeoPoint(
                        latitude: position.latitude,
                        longitude: position.longitude,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(
          right: 6,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xCCFFFFFF)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                'NC OneMap Orthoimagery · NCCGIA / NC 911 Board',
                style: TextStyle(fontSize: 10, color: Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VertexPin extends StatelessWidget {
  const _VertexPin({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFCC2000),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
