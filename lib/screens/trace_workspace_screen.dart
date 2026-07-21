import 'package:flutter/material.dart';

import '../models/graph_document.dart';
import '../models/trace_geometry.dart';
import '../services/measurement_format.dart';
import '../services/measurement_service.dart';
import '../services/trace_map_provider.dart';
import '../services/trace_map_provider_factory.dart';
import '../services/trace_projection_service.dart';

class TraceWorkspaceScreen extends StatefulWidget {
  const TraceWorkspaceScreen({
    required this.address,
    required this.canvasSize,
    required this.traceLabel,
    this.provider,
    this.initialTrace,
    super.key,
  });

  final String address;
  final Size canvasSize;
  final String traceLabel;
  final TraceMapProvider? provider;
  final TraceGeometry? initialTrace;

  @override
  State<TraceWorkspaceScreen> createState() => _TraceWorkspaceScreenState();
}

class _TraceWorkspaceScreenState extends State<TraceWorkspaceScreen> {
  late final TraceMapProvider _provider;
  late final TextEditingController _addressController;
  final List<GeoPoint> _points = <GeoPoint>[];
  GeoPoint? _center;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? createTraceMapProvider();
    _addressController = TextEditingController(text: widget.address);
    _points.addAll(widget.initialTrace?.geoPoints ?? const <GeoPoint>[]);
    _loadAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Enter a Location Address to open the trace map.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _provider.initialize();
      final center = await _provider.geocode(address);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _center = center;
        _error = center == null
            ? 'That address could not be located. Edit it and search again.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  MeasurementResult get _measurement => MeasurementService.measureTrace(
        TraceGeometry(
          id: 'preview',
          label: widget.traceLabel,
          geoPoints: _points,
          canvasPoints: const [],
        ),
        status: MeasurementAccuracyStatus.estimated,
      );

  void _finish() {
    if (_points.length < 3) return;
    final projection = TraceProjectionService.projectToCanvas(
      _points,
      canvasSize: widget.canvasSize,
    );
    Navigator.pop(
      context,
      TraceGeometry(
        id: widget.initialTrace?.id ?? newGraphId(),
        label: widget.initialTrace?.label ?? widget.traceLabel,
        geoPoints: List<GeoPoint>.of(_points),
        canvasPoints: projection.canvasPoints,
        metersPerCanvasUnit: projection.metersPerCanvasUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final measurement = _measurement;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satellite Trace'),
        actions: [
          IconButton(
            tooltip: 'Undo last trace point',
            onPressed: _points.isEmpty
                ? null
                : () => setState(() => _points.removeLast()),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Clear trace',
            onPressed:
                _points.isEmpty ? null : () => setState(() => _points.clear()),
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('trace-address-field'),
                      controller: _addressController,
                      onSubmitted: (_) => _loadAddress(),
                      decoration: const InputDecoration(
                        labelText: 'Location Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _loadAddress,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildMapBody()),
          Material(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 4,
                      children: [
                        Text('${_points.length} points'),
                        Text(MeasurementFormat.linearFeet(
                          measurement.linearFeet,
                        )),
                        Text(MeasurementFormat.squareFeet(
                          measurement.squareFeet,
                        )),
                        Text(MeasurementFormat.acres(measurement.acres)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('finish-trace-button'),
                    onPressed: _points.length >= 3 ? _finish : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Finish Trace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final center = _center;
    if (_error != null || center == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 54),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'The map is unavailable.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Google key must enable Maps JavaScript and Geocoding '
                  'and be restricted to this app’s web origins.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: _provider.buildMap(
            center: center,
            points: _points,
            onMapTap: (point) => setState(() => _points.add(point)),
            onVertexMoved: (index, point) => setState(() {
              if (index >= 0 && index < _points.length) {
                _points[index] = point;
              }
            }),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _points.isEmpty
                    ? 'Tap each property corner.'
                    : 'Tap to add points. Drag a numbered pin to adjust it.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
