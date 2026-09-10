import '../models/trace_geometry.dart';

String traceWorkspaceAddress(
  List<TraceGeometry> traces,
  String jobAddress, {
  TraceGeometry? editingTrace,
}) {
  if (editingTrace != null) {
    final address = editingTrace.address.trim();
    return address.isEmpty ? jobAddress.trim() : address;
  }
  for (final trace in traces.reversed) {
    if (trace.address.trim().isNotEmpty) return trace.address.trim();
  }
  return jobAddress.trim();
}
