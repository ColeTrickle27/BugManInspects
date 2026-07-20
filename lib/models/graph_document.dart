import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'freehand_stroke.dart';
import 'graph_annotation.dart';
import 'graph_point.dart';
import 'graph_shape.dart';
import 'job.dart';
import 'wall_segment.dart';
import 'trace_geometry.dart';

/// The durable, serializable source of truth for one inspection graph.
///
/// UI-only state such as the selected tool and current zoom deliberately stays
/// in the editor. Everything that belongs in a saved inspection lives here.
class GraphDocument extends ChangeNotifier {
  GraphDocument({
    String? id,
    required this.customer,
    List<WallSegment> wallSegments = const <WallSegment>[],
    List<GraphAnnotation> annotations = const <GraphAnnotation>[],
    List<GraphShape> shapes = const <GraphShape>[],
    List<FreehandStroke> freehandStrokes = const <FreehandStroke>[],
    Map<String, GraphLayerState>? layers,
    List<GraphAttachment> attachments = const <GraphAttachment>[],
    List<TraceGeometry> traces = const <TraceGeometry>[],
    MeasurementCalibration? measurementCalibration,
    Map<String, Object?> metadata = const <String, Object?>{},
    Map<String, Object?> extraProperties = const <String, Object?>{},
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newGraphId(),
        _wallSegments = List<WallSegment>.of(wallSegments),
        _annotations = List<GraphAnnotation>.of(annotations),
        _shapes = List<GraphShape>.of(shapes),
        _freehandStrokes = List<FreehandStroke>.of(freehandStrokes),
        _layers = <String, GraphLayerState>{
          ...defaultLayers,
          ...?layers,
        },
        _attachments = List<GraphAttachment>.of(attachments),
        _traces = List<TraceGeometry>.of(traces),
        _measurementCalibration =
            measurementCalibration ?? MeasurementCalibration.legacy(),
        _metadata = Map<String, Object?>.of(metadata),
        _extraProperties = Map<String, Object?>.of(extraProperties),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  factory GraphDocument.forJob(Job job) {
    return GraphDocument(
      id: job.id,
      customer: GraphCustomerInfo.fromJob(job),
      createdAt: job.createdDate,
    );
  }

  /// Reads both the document format and the original flat graph payload.
  factory GraphDocument.fromJson(Map<String, Object?> json) {
    final graphObjects = _map(json['graphObjects']);
    final job = _map(json['job']);
    final customerJson = _map(json['customer']);
    final objectSource = graphObjects.isEmpty ? json : graphObjects;

    return GraphDocument(
      id: _string(json['id']).isEmpty ? null : _string(json['id']),
      customer: GraphCustomerInfo.fromJson(
        customerJson.isNotEmpty ? customerJson : job,
      ),
      wallSegments: _list(objectSource['wallSegments'])
          .map((value) => _wallSegmentFromJson(_map(value)))
          .toList(),
      annotations: _list(objectSource['annotations'])
          .map((value) => _annotationFromJson(_map(value)))
          .toList(),
      shapes: _list(objectSource['shapes'])
          .map((value) => _shapeFromJson(_map(value)))
          .toList(),
      freehandStrokes: _list(objectSource['freehandStrokes'])
          .map((value) => _freehandFromJson(_map(value)))
          .toList(),
      layers: _migrateLayers(_map(json['layers'])).map(
        (key, value) => MapEntry(
          key,
          GraphLayerState.fromJson(_map(value)),
        ),
      ),
      attachments: _list(json['attachments'])
          .map((value) => GraphAttachment.fromJson(_map(value)))
          .toList(),
      traces: _list(json['traces'])
          .map((value) => TraceGeometry.fromJson(_map(value)))
          .toList(),
      measurementCalibration: _map(json['measurementCalibration']).isEmpty
          ? MeasurementCalibration.legacy()
          : MeasurementCalibration.fromJson(
              _map(json['measurementCalibration']),
            ),
      metadata: _map(json['metadata']),
      extraProperties: _unknownFields(json, const {
        'schemaVersion',
        'id',
        'customer',
        'job',
        'graphObjects',
        'wallSegments',
        'annotations',
        'shapes',
        'freehandStrokes',
        'layers',
        'attachments',
        'traces',
        'measurementCalibration',
        'metadata',
        'createdAt',
        'updatedAt',
      }),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    )..markClean();
  }

  static const int schemaVersion = 4;

  static const Map<String, GraphLayerState> defaultLayers = {
    'structure': GraphLayerState(),
    'shapes': GraphLayerState(),
    'inspections': GraphLayerState(),
    'treatment': GraphLayerState(),
    'photos': GraphLayerState(),
    'trace': GraphLayerState(visible: false),
  };

  final String id;
  GraphCustomerInfo customer;
  final DateTime createdAt;
  DateTime updatedAt;

  List<WallSegment> _wallSegments;
  List<GraphAnnotation> _annotations;
  List<GraphShape> _shapes;
  List<FreehandStroke> _freehandStrokes;
  Map<String, GraphLayerState> _layers;
  List<GraphAttachment> _attachments;
  List<TraceGeometry> _traces;
  MeasurementCalibration _measurementCalibration;
  Map<String, Object?> _metadata;
  Map<String, Object?> _extraProperties;
  bool _isDirty = false;
  int _revision = 0;

  UnmodifiableListView<WallSegment> get wallSegments =>
      UnmodifiableListView(_wallSegments);
  UnmodifiableListView<GraphAnnotation> get annotations =>
      UnmodifiableListView(_annotations);
  UnmodifiableListView<GraphShape> get shapes => UnmodifiableListView(_shapes);
  UnmodifiableListView<FreehandStroke> get freehandStrokes =>
      UnmodifiableListView(_freehandStrokes);
  UnmodifiableMapView<String, GraphLayerState> get layers =>
      UnmodifiableMapView(_layers);
  UnmodifiableListView<GraphAttachment> get attachments =>
      UnmodifiableListView(_attachments);
  UnmodifiableListView<TraceGeometry> get traces =>
      UnmodifiableListView(_traces);
  MeasurementCalibration get measurementCalibration => _measurementCalibration;
  UnmodifiableMapView<String, Object?> get metadata =>
      UnmodifiableMapView(_metadata);
  UnmodifiableMapView<String, Object?> get extraProperties =>
      UnmodifiableMapView(_extraProperties);

  List<GraphAnnotation> get photos => _annotations
      .where((item) => item.kind == GraphAnnotationKind.photo)
      .toList(growable: false);
  List<GraphAnnotation> get notes => _annotations
      .where((item) => item.note.trim().isNotEmpty)
      .toList(growable: false);

  bool get isDirty => _isDirty;
  int get revision => _revision;

  GraphLayerState layer(String id) => _layers[id] ?? const GraphLayerState();

  void replaceWallSegments(Iterable<WallSegment> value) {
    _wallSegments = List<WallSegment>.of(value);
    _changed();
  }

  void replaceAnnotations(Iterable<GraphAnnotation> value) {
    _annotations = List<GraphAnnotation>.of(value);
    _changed();
  }

  void replaceShapes(Iterable<GraphShape> value) {
    _shapes = List<GraphShape>.of(value);
    _changed();
  }

  void replaceFreehandStrokes(Iterable<FreehandStroke> value) {
    _freehandStrokes = List<FreehandStroke>.of(value);
    _changed();
  }

  void setLayer(String id, GraphLayerState value) {
    _layers = <String, GraphLayerState>{..._layers, id: value};
    _changed();
  }

  void replaceAttachments(Iterable<GraphAttachment> value) {
    _attachments = List<GraphAttachment>.of(value);
    _changed();
  }

  void replaceTraces(Iterable<TraceGeometry> value) {
    _traces = List<TraceGeometry>.of(value);
    _changed();
  }

  void setMeasurementCalibration(MeasurementCalibration value) {
    _measurementCalibration = value;
    _changed();
  }

  void replaceMetadata(Map<String, Object?> value) {
    _metadata = Map<String, Object?>.of(value);
    _changed();
  }

  void updateCustomer(GraphCustomerInfo value) {
    customer = value;
    _changed();
  }

  void markClean() {
    _isDirty = false;
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
        ..._extraProperties,
        'id': id,
        'schemaVersion': schemaVersion,
        'customer': customer.toJson(),
        'graphObjects': {
          'wallSegments': _wallSegments.map(_wallSegmentToJson).toList(),
          'annotations': _annotations.map(_annotationToJson).toList(),
          'shapes': _shapes.map(_shapeToJson).toList(),
          'freehandStrokes': _freehandStrokes.map(_freehandToJson).toList(),
        },
        'layers': _layers.map((key, value) => MapEntry(key, value.toJson())),
        'attachments': _attachments.map((item) => item.toJson()).toList(),
        'traces': _traces.map((item) => item.toJson()).toList(),
        'measurementCalibration': _measurementCalibration.toJson(),
        'metadata': _metadata,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  void _changed() {
    _isDirty = true;
    _revision += 1;
    updatedAt = DateTime.now();
    notifyListeners();
  }
}

class GraphCustomerInfo {
  const GraphCustomerInfo({
    required this.name,
    required this.serviceAddress,
    required this.pestPacLocationNumber,
    required this.pestPacBillToNumber,
    required this.serviceType,
    required this.createdBy,
  });

  factory GraphCustomerInfo.fromJob(Job job) => GraphCustomerInfo(
        name: job.customerName,
        serviceAddress: job.serviceAddress,
        pestPacLocationNumber: job.pestPacLocationNumber,
        pestPacBillToNumber: job.pestPacBillToNumber,
        serviceType: job.serviceType,
        createdBy: job.createdBy,
      );

  factory GraphCustomerInfo.fromJson(Map<String, Object?> json) {
    final legacyAccountNumber = _string(json['pestPacAccountNumber']);

    return GraphCustomerInfo(
      name: _string(json['name'] ?? json['customerName']),
      serviceAddress: _string(json['serviceAddress']),
      pestPacLocationNumber: json.containsKey('pestPacLocationNumber')
          ? _string(json['pestPacLocationNumber'])
          : legacyAccountNumber,
      pestPacBillToNumber: _string(json['pestPacBillToNumber']),
      serviceType: _string(json['serviceType']),
      createdBy: _string(json['createdBy']),
    );
  }

  final String name;
  final String serviceAddress;
  final String pestPacLocationNumber;
  final String pestPacBillToNumber;
  final String serviceType;
  final String createdBy;

  String get displayName => name.trim().isEmpty ? 'Untitled Job' : name;

  Map<String, Object?> toJson() => {
        'name': name,
        'serviceAddress': serviceAddress,
        'pestPacLocationNumber': pestPacLocationNumber,
        'pestPacBillToNumber': pestPacBillToNumber,
        'pestPacAccountNumber': pestPacLocationNumber,
        'serviceType': serviceType,
        'createdBy': createdBy,
      };
}

class GraphLayerState {
  const GraphLayerState({this.visible = true, this.locked = false});

  factory GraphLayerState.fromJson(Map<String, Object?> json) =>
      GraphLayerState(
        visible: json['visible'] as bool? ?? true,
        locked: json['locked'] as bool? ?? false,
      );

  final bool visible;
  final bool locked;

  GraphLayerState copyWith({bool? visible, bool? locked}) => GraphLayerState(
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
      );

  Map<String, Object?> toJson() => {'visible': visible, 'locked': locked};
}

class GraphAttachment {
  const GraphAttachment({
    required this.id,
    required this.name,
    this.annotationId = '',
    this.mimeType = '',
    this.byteSize = 0,
    this.width = 0,
    this.height = 0,
    this.blobKey = '',
    this.thumbnailKey = '',
    this.uri,
  });

  factory GraphAttachment.fromJson(Map<String, Object?> json) =>
      GraphAttachment(
        id: _string(json['id']),
        name: _string(json['name']),
        annotationId: _string(json['annotationId']),
        mimeType: _string(json['mimeType']),
        byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        blobKey: _string(json['blobKey']).isEmpty
            ? _string(json['id'])
            : _string(json['blobKey']),
        thumbnailKey: _string(json['thumbnailKey']).isEmpty
            ? '${_string(json['id'])}-thumb'
            : _string(json['thumbnailKey']),
        uri: json['uri'] as String?,
      );

  final String id;
  final String name;
  final String annotationId;
  final String mimeType;
  final int byteSize;
  final int width;
  final int height;
  final String blobKey;
  final String thumbnailKey;
  final String? uri;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'annotationId': annotationId,
        'mimeType': mimeType,
        'byteSize': byteSize,
        'width': width,
        'height': height,
        'blobKey': blobKey,
        'thumbnailKey': thumbnailKey,
        'uri': uri,
      };
}

String newGraphId() {
  final random = math.Random.secure();
  final suffix = List.generate(
    12,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
}

Map<String, Object?> _migrateLayers(Map<String, Object?> layers) {
  if (!layers.containsKey('findings')) {
    return layers;
  }
  final legacyFindings = layers['findings'];
  return <String, Object?>{
    ...layers,
    'inspections': layers['inspections'] ?? legacyFindings,
    'treatment': layers['treatment'] ?? legacyFindings,
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, Object?>{};
}

Map<String, Object?> _unknownFields(
  Map<String, Object?> source,
  Set<String> knownKeys,
) =>
    Map<String, Object?>.fromEntries(
      source.entries.where((entry) => !knownKeys.contains(entry.key)),
    );

List<Object?> _list(Object? value) => value is List ? value : const [];
String _string(Object? value) => value?.toString() ?? '';
double _double(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;
int _color(Color value) => value.toARGB32();
Color _readColor(Object? value, Color fallback) =>
    value is num ? Color(value.toInt()) : fallback;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
T _enum<T extends Enum>(Iterable<T> values, Object? value, T fallback) =>
    values.cast<T?>().firstWhere(
          (item) => item?.name == value,
          orElse: () => fallback,
        ) ??
    fallback;

Map<String, Object?> _pointToJson(GraphPoint point) =>
    {'x': point.x, 'y': point.y};
GraphPoint _pointFromJson(Map<String, Object?> json) =>
    GraphPoint(x: _double(json['x']), y: _double(json['y']));

Map<String, Object?> _wallSegmentToJson(WallSegment item) => {
      'start': _pointToJson(item.start),
      'end': _pointToJson(item.end),
      'controlPoint':
          item.controlPoint == null ? null : _pointToJson(item.controlPoint!),
      'color': _color(item.color),
      'strokeWidth': item.strokeWidth,
      'pattern': item.pattern.name,
      'hasArrow': item.hasArrow,
    };
WallSegment _wallSegmentFromJson(Map<String, Object?> json) => WallSegment(
      start: _pointFromJson(_map(json['start'])),
      end: _pointFromJson(_map(json['end'])),
      controlPoint: json['controlPoint'] == null
          ? null
          : _pointFromJson(_map(json['controlPoint'])),
      color: _readColor(json['color'], const Color(0xFF214D38)),
      strokeWidth: _double(json['strokeWidth'], 5),
      pattern: _enum(LinePattern.values, json['pattern'], LinePattern.solid),
      hasArrow: json['hasArrow'] as bool? ?? false,
    );

Map<String, Object?> _annotationToJson(GraphAnnotation item) => {
      ...item.extraProperties,
      'id': item.id,
      'kind': item.kind.name,
      'point': _pointToJson(item.point),
      'label': item.label,
      'markerType': item.markerType.name,
      'color': item.color == null ? null : _color(item.color!),
      'size': item.size,
      'rotationDegrees': item.rotationDegrees,
      'note': item.note,
      'fontSize': item.fontSize,
      'bold': item.bold,
      'italic': item.italic,
      'textColor': _color(item.textColor),
      'backgroundColor': _color(item.backgroundColor),
      'borderColor': _color(item.borderColor),
      'attachmentIds': item.attachmentIds,
    };
GraphAnnotation _annotationFromJson(Map<String, Object?> json) =>
    GraphAnnotation(
      id: _string(json['id']).isEmpty ? newGraphId() : _string(json['id']),
      kind: _enum(
        GraphAnnotationKind.values,
        json['kind'],
        GraphAnnotationKind.marker,
      ),
      point: _pointFromJson(_map(json['point'])),
      label: _string(json['label']),
      markerType: _enum(
        GraphMarkerType.values,
        json['markerType'],
        GraphMarkerType.damage,
      ),
      color: json['color'] == null
          ? null
          : _readColor(json['color'], const Color(0xFFD33A2C)),
      size: _double(json['size'], 1),
      rotationDegrees: _double(json['rotationDegrees']),
      note: _string(json['note']),
      fontSize: _double(json['fontSize'], 16),
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      textColor: _readColor(json['textColor'], const Color(0xFF1C2B22)),
      backgroundColor:
          _readColor(json['backgroundColor'], const Color(0xFFFFF2B8)),
      borderColor: _readColor(json['borderColor'], const Color(0xFFC7A93C)),
      attachmentIds: _list(json['attachmentIds'])
          .map((value) => value.toString())
          .toList(),
      extraProperties: _unknownFields(json, const {
        'kind',
        'point',
        'label',
        'markerType',
        'color',
        'size',
        'rotationDegrees',
        'note',
        'fontSize',
        'bold',
        'italic',
        'textColor',
        'backgroundColor',
        'borderColor',
        'id',
        'attachmentIds',
      }),
    );

Map<String, Object?> _shapeToJson(GraphShape item) => {
      ...item.extraProperties,
      'name': item.name,
      'segmentIndexes': item.segmentIndexes,
      'fillColor': item.fillColor == null ? null : _color(item.fillColor!),
      'fillOpacity': item.fillOpacity,
      'borderColor': _color(item.borderColor),
      'borderWidth': item.borderWidth,
      'pattern': item.pattern.name,
      'closed': item.closed,
      'rotationDegrees': item.rotationDegrees,
      'preset': item.preset?.name,
      'text': item.text,
    };
GraphShape _shapeFromJson(Map<String, Object?> json) => GraphShape(
      name: _string(json['name']),
      segmentIndexes: _list(json['segmentIndexes'])
          .whereType<num>()
          .map((v) => v.toInt())
          .toList(),
      fillColor: json['fillColor'] == null
          ? null
          : _readColor(json['fillColor'], Colors.transparent),
      fillOpacity: _double(json['fillOpacity'], 0.3),
      borderColor: _readColor(json['borderColor'], const Color(0xFF214D38)),
      borderWidth: _double(json['borderWidth'], 3),
      pattern: _enum(
        GraphShapePattern.values,
        json['pattern'],
        GraphShapePattern.none,
      ),
      closed: json['closed'] as bool? ?? true,
      rotationDegrees: _double(json['rotationDegrees']),
      preset: json['preset'] == null
          ? null
          : _enum(
              GraphDrawingPreset.values,
              json['preset'],
              GraphDrawingPreset.mainStructure,
            ),
      text: _string(json['text']),
      extraProperties: _unknownFields(json, const {
        'name',
        'segmentIndexes',
        'fillColor',
        'fillOpacity',
        'borderColor',
        'borderWidth',
        'pattern',
        'closed',
        'rotationDegrees',
        'preset',
        'text',
      }),
    );

Map<String, Object?> _freehandToJson(FreehandStroke item) => {
      'points': item.points.map(_pointToJson).toList(),
      'color': _color(item.color),
      'strokeWidth': item.strokeWidth,
      'opacity': item.opacity,
    };
FreehandStroke _freehandFromJson(Map<String, Object?> json) => FreehandStroke(
      points: _list(json['points'])
          .map((value) => _pointFromJson(_map(value)))
          .toList(),
      color: _readColor(json['color'], const Color(0xFF1C2B22)),
      strokeWidth: _double(json['strokeWidth'], 4),
      opacity: _double(json['opacity'], 0.85),
    );
