// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/trace_geometry.dart';
import 'trace_map_provider.dart';

TraceMapProvider createTraceMapProvider() => GoogleWebTraceMapProvider();

class GoogleWebTraceMapProvider implements TraceMapProvider {
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static Future<void>? _initialization;

  @override
  Future<void> initialize() {
    if (_apiKey.trim().isEmpty) {
      throw const TraceMapConfigurationException(
        'Google Maps is not configured. Build with '
        '--dart-define=GOOGLE_MAPS_API_KEY=your_restricted_key.',
      );
    }
    return _initialization ??= _loadGoogleMaps();
  }

  Future<void> _loadGoogleMaps() async {
    if (_googleMaps != null) return;

    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..id = 'bugman-google-maps'
      ..async = true
      ..defer = true
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$_apiKey';
    script.onLoad.first.then((_) => completer.complete());
    script.onError.first.then(
      (_) => completer.completeError(
        const TraceMapConfigurationException(
          'Google Maps could not load. Check the API key and referrer rules.',
        ),
      ),
    );
    html.document.head?.append(script);
    return completer.future.timeout(const Duration(seconds: 20));
  }

  @override
  Future<GeoPoint?> geocode(String address) async {
    await initialize();
    final response = await _GoogleGeocoder()
        .geocode(<String, Object?>{'address': address}.jsify() as JSObject)
        .toDart
        .timeout(const Duration(seconds: 15));
    final results = response.results.toDart;
    if (results.isEmpty) return null;
    final location = results.first.geometry.location;
    return GeoPoint(latitude: location.lat(), longitude: location.lng());
  }

  @override
  Widget buildMap({
    required GeoPoint center,
    required List<GeoPoint> points,
    required ValueChanged<GeoPoint> onMapTap,
    required void Function(int index, GeoPoint point) onVertexMoved,
  }) {
    final polygonPoints = <LatLng>[
      for (final point in points) LatLng(point.latitude, point.longitude),
    ];
    return GoogleMap(
      mapType: MapType.satellite,
      initialCameraPosition: CameraPosition(
        target: LatLng(center.latitude, center.longitude),
        zoom: 20,
      ),
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onTap: (position) => onMapTap(
        GeoPoint(latitude: position.latitude, longitude: position.longitude),
      ),
      polygons: points.length < 3
          ? const <Polygon>{}
          : <Polygon>{
              Polygon(
                polygonId: const PolygonId('active-trace'),
                points: polygonPoints,
                strokeColor: const Color(0xFFCC2000),
                strokeWidth: 4,
                fillColor: const Color(0x33CC2000),
              ),
            },
      polylines: points.length < 2
          ? const <Polyline>{}
          : <Polyline>{
              Polyline(
                polylineId: const PolylineId('active-trace-line'),
                points: polygonPoints,
                color: const Color(0xFFCC2000),
                width: 4,
              ),
            },
      markers: <Marker>{
        for (var index = 0; index < points.length; index += 1)
          Marker(
            markerId: MarkerId('trace-vertex-$index'),
            position: polygonPoints[index],
            draggable: true,
            onDragEnd: (position) => onVertexMoved(
              index,
              GeoPoint(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
          ),
      },
    );
  }
}

@JS('google.maps')
external JSObject? get _googleMaps;

@JS('google.maps.Geocoder')
extension type _GoogleGeocoder._(JSObject _) implements JSObject {
  external factory _GoogleGeocoder();
  external JSPromise<_GoogleGeocoderResponse> geocode(JSObject request);
}

extension type _GoogleGeocoderResponse._(JSObject _) implements JSObject {
  external JSArray<_GoogleGeocoderResult> get results;
}

extension type _GoogleGeocoderResult._(JSObject _) implements JSObject {
  external _GoogleGeometry get geometry;
}

extension type _GoogleGeometry._(JSObject _) implements JSObject {
  external _GoogleLatLng get location;
}

extension type _GoogleLatLng._(JSObject _) implements JSObject {
  external double lat();
  external double lng();
}
