import 'package:bugman_graphs/models/trace_geometry.dart';
import 'package:bugman_graphs/services/trace_workspace_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trace = TraceGeometry(
    id: 'trace-1',
    label: 'Property trace',
    address: '123 Standardized Street',
    geoPoints: [],
    canvasPoints: [],
  );
  test('trace address survives save, reload and geometry changes', () {
    final restored = TraceGeometry.fromJson(trace.toJson());
    expect(restored.address, trace.address);
    expect(restored.copyWith(label: 'Updated trace').address, trace.address);
  });
  test('old traces without address still load and use the job address', () {
    final oldJson = trace.toJson()..remove('address');
    final oldTrace = TraceGeometry.fromJson(oldJson);
    expect(oldTrace.address, isEmpty);
    expect(traceWorkspaceAddress([oldTrace], 'Job address'), 'Job address');
  });
  test('new trace defaults to the last saved property address', () {
    final second =
        trace.copyWith(id: 'trace-2', address: '456 Selected Street');
    expect(traceWorkspaceAddress([trace, second], 'Stale job address'),
        '456 Selected Street');
    expect(traceWorkspaceAddress([trace], ''), trace.address);
  });
  test('editing retains that trace address instead of the newest trace address',
      () {
    final second =
        trace.copyWith(id: 'trace-2', address: '456 Selected Street');
    expect(
        traceWorkspaceAddress([trace, second], 'Job address',
            editingTrace: trace),
        trace.address);
  });
}
