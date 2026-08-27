import 'dart:async';

import 'package:bugman_graphs/models/trace_geometry.dart';
import 'package:bugman_graphs/screens/trace_workspace_screen.dart';
import 'package:bugman_graphs/services/address_suggestion_service.dart';
import 'package:bugman_graphs/services/trace_map_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'trace workspace requires a selected address and returns scaled trace',
      (tester) async {
    final provider = _FakeTraceMapProvider();
    final addressService = _FakeAddressSuggestionService();
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
                        addressService: addressService,
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
    expect(addressService.lastQuery, '123 Main Street');
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('trace-address-field')),
    );
    expect(field.controller?.text, '123 Main Street');
    expect(find.byKey(const ValueKey('trace-address-suggestions')),
        findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('trace-address-suggestion-test-address')),
    );
    await tester.pumpAndSettle();
    expect(
        provider.selectedAddress, const GeoPoint(latitude: 35, longitude: -86));
    expect(find.text('Property-level location'), findsOneWidget);

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

  testWidgets('trace workspace ignores a stale suggestion request',
      (tester) async {
    final service = _DelayedAddressSuggestionService();
    await tester.pumpWidget(
      MaterialApp(
        home: TraceWorkspaceScreen(
          address: '',
          canvasSize: const Size(3600, 2600),
          traceLabel: 'Property Trace 1',
          provider: _FakeTraceMapProvider(),
          addressService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('trace-address-field')),
      'Old address',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.requests, ['Old address']);

    await tester.enterText(
      find.byKey(const ValueKey('trace-address-field')),
      'New address',
    );
    service.complete('Old address', 'old-address');
    await tester.pump();
    expect(find.byKey(const ValueKey('trace-address-suggestion-old-address')),
        findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    service.complete('New address', 'new-address');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trace-address-suggestion-new-address')),
        findsOneWidget);
  });
}

class _FakeTraceMapProvider implements TraceMapProvider {
  GeoPoint? selectedAddress;

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
    this.selectedAddress = selectedAddress;
    return GestureDetector(
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
}

class _FakeAddressSuggestionService implements AddressSuggestionService {
  String? lastQuery;
  String? lastSessionToken;

  @override
  Future<AddressSelection> select(
    AddressSuggestion suggestion, {
    required String sessionToken,
  }) async {
    lastSessionToken = sessionToken;
    return const AddressSelection(
      standardizedAddress: '123 Main Street, Raleigh, NC 27601',
      coordinate: GeoPoint(latitude: 35, longitude: -86),
      quality: AddressQuality(
        geocodeGranularity: 'PREMISE',
        validationGranularity: 'PREMISE',
        isPropertyLevel: true,
        addressComplete: true,
        requiresReview: false,
      ),
    );
  }

  @override
  Future<List<AddressSuggestion>> suggest(
    String query, {
    required String sessionToken,
  }) async {
    lastQuery = query;
    lastSessionToken = sessionToken;
    return const [
      AddressSuggestion(
        id: 'test-address',
        address: '123 Main Street, Raleigh, NC',
        primaryText: '123 Main Street',
        secondaryText: 'Raleigh, NC',
      ),
    ];
  }
}

class _DelayedAddressSuggestionService implements AddressSuggestionService {
  final Map<String, Completer<List<AddressSuggestion>>> _pending = {};
  final List<String> requests = [];

  @override
  Future<AddressSelection> select(
    AddressSuggestion suggestion, {
    required String sessionToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<AddressSuggestion>> suggest(
    String query, {
    required String sessionToken,
  }) {
    requests.add(query);
    return (_pending[query] ??= Completer<List<AddressSuggestion>>()).future;
  }

  void complete(String query, String id) {
    _pending[query]!.complete([
      AddressSuggestion(
        id: id,
        address: '$query, Raleigh, NC',
        primaryText: query,
        secondaryText: 'Raleigh, NC',
      ),
    ]);
  }
}
