import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../models/trace_geometry.dart';
import 'census_geocoder.dart';
import 'trace_map_provider.dart';

TraceMapProvider createTraceMapProvider() => NorthCarolinaTraceMapProvider();

class NorthCarolinaTraceMapProvider implements TraceMapProvider {
  static const String _imageryWmsUrl =
      'https://services.nconemap.gov/secure/services/Imagery/'
      'Orthoimagery_Latest/ImageServer/WMSServer?';

  @override
  Future<void> initialize() async {}

  @override
  Future<GeoPoint?> geocode(String address) async {
    final response = await _bugmanCensusGeocode(
      northCarolinaGeocodeQuery(address),
    ).toDart.timeout(const Duration(seconds: 15));
    return parseNorthCarolinaCensusMatch(response.dartify());
  }

  @override
  Widget buildMap({
    required GeoPoint center,
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
            maxZoom: 21,
            onTap: (_, position) => onMapTap(
              GeoPoint(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
          ),
          children: [
            TileLayer(
              wmsOptions: WMSTileLayerOptions(
                baseUrl: _imageryWmsUrl,
                layers: const ['0'],
                format: 'image/jpeg',
                transparent: false,
                version: '1.3.0',
              ),
              maxNativeZoom: 21,
              userAgentPackageName: 'com.holloman.bugman_graphs',
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
                    size: const Size(44, 44),
                    builder: (context, position, isDragging) =>
                        _VertexPin(number: index + 1),
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
          ),
        ),
      ),
    );
  }
}

@JS('bugmanCensusGeocode')
external JSPromise<JSObject> _bugmanCensusGeocode(String address);
