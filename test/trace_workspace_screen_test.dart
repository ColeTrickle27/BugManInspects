import 'package:bugman_graphs/models/trace_geometry.dart';
import 'package:bugman_graphs/screens/trace_workspace_screen.dart';
import 'package:bugman_graphs/services/trace_map_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trace workspace geocodes saved address and returns scaled trace',
      (tester) async {
    final provider = _FakeTraceMapProvider();
    TraceGeometry? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.push<TraceGeometry>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TraceWorkspaceScreen(
                        address: '123 Main Street',
                        canvasSize: const Size(3600, 2600),
                        traceLabel: 'Property Trace 1',
                        provider: provider,
                      ),
                    ),
                  );
                },
                child: const Text('Open Trace'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Trace'));
    await tester.pumpAndSettle();
    expect(provider.lastAddress, '123 Main Street');
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('trace-address-field')),
    );
    expect(field.controller?.text, '123 Main Street');

    await tester.tap(find.byKey(const ValueKey('fake-trace-map')));
    await tester.tap(find.byKey(const ValueKey('fake-trace-map')));
    await tester.tap(find.byKey(const ValueKey('fake-trace-map')));
    await tester.pump();
    final finish = tester.widget<FilledButton>(
      find.byKey(const ValueKey('finish-trace-button')),
    );
    expect(finish.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('finish-trace-button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.geoPoints, hasLength(3));
    expect(result!.canvasPoints, hasLength(3));
    expect(result!.metersPerCanvasUnit, greaterThan(0));
  });
}

class _FakeTraceMapProvider implements TraceMapProvider {
  String? lastAddress;

  @override
  Future<void> initialize() async {}

  @override
  Future<GeoPoint?> geocode(String address) async {
    lastAddress = address;
    return const GeoPoint(latitude: 35, longitude: -86);
  }

  @override
  Widget buildMap({
    required GeoPoint center,
    required List<GeoPoint> points,
    required ValueChanged<GeoPoint> onMapTap,
    required void Function(int index, GeoPoint point) onVertexMoved,
  }) =>
      GestureDetector(
        key: const ValueKey('fake-trace-map'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final offset = points.length * 0.0001;
          onMapTap(
            GeoPoint(
              latitude: center.latitude + (points.length == 2 ? offset : 0),
              longitude: center.longitude + offset,
            ),
          );
        },
        child: const ColoredBox(color: Colors.blueGrey),
      );
}
