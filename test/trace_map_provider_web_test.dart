import 'package:bugman_graphs/models/trace_geometry.dart';
import 'package:bugman_graphs/services/trace_map_provider_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'trace map offers closer display zoom while retaining native imagery and compact pins',
    (tester) async {
      final provider = NorthCarolinaTraceMapProvider();
      final points = <GeoPoint>[
        const GeoPoint(latitude: 35.0, longitude: -78.0),
        const GeoPoint(latitude: 35.0001, longitude: -78.0001),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: provider.buildMap(
                center: points.first,
                selectedAddress: points.first,
                points: points,
                onMapTap: (_) {},
                onVertexMoved: (_, __) {},
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options.maxZoom,
        22,
      );
      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(tileLayer.maxNativeZoom, 20);
      expect(tileLayer.maxZoom, 22);
      expect(find.byKey(const ValueKey('trace-map-zoom-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-map-zoom-out')), findsOneWidget);

      final markers =
          tester.widget<DragMarkers>(find.byType(DragMarkers)).markers;
      expect(markers, hasLength(2));
      for (final marker in markers) {
        expect(marker.size, const Size(32, 32));
      }
    },
  );
}
