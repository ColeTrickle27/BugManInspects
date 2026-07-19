import 'package:bugman_graphs/models/freehand_stroke.dart';
import 'package:bugman_graphs/models/graph_annotation.dart';
import 'package:bugman_graphs/models/graph_document.dart';
import 'package:bugman_graphs/models/graph_point.dart';
import 'package:bugman_graphs/models/graph_shape.dart';
import 'package:bugman_graphs/models/job.dart';
import 'package:bugman_graphs/models/wall_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final job = Job(
    customerName: 'Ada Customer',
    serviceAddress: '1 Graph Lane',
    pestPacLocationNumber: 'LOC-100',
    pestPacBillToNumber: 'BILL-200',
    serviceType: 'Inspection',
    createdBy: 'Inspector',
    createdDate: DateTime(2026, 7, 14),
  );

  test('tracks dirty state for graph and layer changes', () {
    final document = GraphDocument.forJob(job);

    expect(document.isDirty, isFalse);
    expect(document.revision, 0);
    expect(document.createdAt, job.createdDate);
    expect(document.customer.pestPacLocationNumber, 'LOC-100');
    expect(document.customer.pestPacBillToNumber, 'BILL-200');

    document.replaceWallSegments(const [
      WallSegment(
        start: GraphPoint(x: 10, y: 20),
        end: GraphPoint(x: 80, y: 20),
      ),
    ]);

    expect(document.isDirty, isTrue);
    expect(document.revision, 1);

    document.markClean();
    expect(document.isDirty, isFalse);

    document.setLayer(
      'findings',
      document.layer('findings').copyWith(locked: true),
    );
    expect(document.isDirty, isTrue);
    expect(document.layer('findings').locked, isTrue);
  });

  test('round-trips every graph object through the document format', () {
    final document = GraphDocument(
      customer: GraphCustomerInfo.fromJob(job),
      wallSegments: const [
        WallSegment(
          start: GraphPoint(x: 1, y: 2),
          end: GraphPoint(x: 40, y: 45),
          controlPoint: GraphPoint(x: 20, y: 5),
          color: Color(0xFF245BDB),
          hasArrow: true,
        ),
      ],
      annotations: const [
        GraphAnnotation(
          kind: GraphAnnotationKind.marker,
          point: GraphPoint(x: 12, y: 18),
          label: 'Active termites',
          markerType: GraphMarkerType.activeTermites,
          note: 'Photo 1',
        ),
      ],
      shapes: const [
        GraphShape(
          name: 'Circle 1',
          segmentIndexes: [0],
          fillColor: Color(0xFFB6D94C),
          fillOpacity: 0.3,
          borderColor: Color(0xFF214D38),
          borderWidth: 3,
          pattern: GraphShapePattern.dots,
          closed: true,
          rotationDegrees: 15,
          text: 'Kitchen',
        ),
      ],
      freehandStrokes: const [
        FreehandStroke(
          points: [GraphPoint(x: 3, y: 4), GraphPoint(x: 9, y: 12)],
        ),
      ],
      metadata: const {'inspectionId': 'I-42'},
    );

    final restored = GraphDocument.fromJson(document.toJson());

    expect(restored.customer.name, 'Ada Customer');
    expect(restored.customer.pestPacLocationNumber, 'LOC-100');
    expect(restored.customer.pestPacBillToNumber, 'BILL-200');
    expect(restored.wallSegments.single.isCurve, isTrue);
    expect(restored.wallSegments.single.hasArrow, isTrue);
    expect(
        restored.annotations.single.markerType, GraphMarkerType.activeTermites);
    expect(restored.shapes.single.pattern, GraphShapePattern.dots);
    expect(restored.shapes.single.text, 'Kitchen');
    expect(restored.freehandStrokes.single.points, hasLength(2));
    expect(restored.metadata['inspectionId'], 'I-42');
    expect(restored.isDirty, isFalse);
  });

  test('loads the original flat graph payload', () {
    final restored = GraphDocument.fromJson({
      'legacyVendorField': 'keep-me',
      'job': {
        'customerName': 'Legacy Customer',
        'serviceAddress': 'Old Format Road',
        'pestPacAccountNumber': 'LEGACY-300',
      },
      'wallSegments': [
        {
          'start': {'x': 0, 'y': 0},
          'end': {'x': 24, 'y': 0},
        },
      ],
      'annotations': <Object?>[],
      'shapes': [
        {
          'name': 'Legacy Main',
          'segmentIndexes': [0],
          'closed': true,
          'legacyShapeField': 42,
        },
      ],
      'freehandStrokes': <Object?>[],
    });

    expect(restored.customer.name, 'Legacy Customer');
    expect(restored.customer.pestPacLocationNumber, 'LEGACY-300');
    expect(restored.customer.pestPacBillToNumber, isEmpty);
    expect(restored.wallSegments.single.measurementLabel, '1.0 lf');
    expect(restored.shapes.single.name, 'Legacy Main');
    expect(restored.shapes.single.extraProperties['legacyShapeField'], 42);
    expect(restored.toJson()['legacyVendorField'], 'keep-me');
    final customerJson = restored.toJson()['customer'] as Map<String, Object?>;
    expect(customerJson['pestPacLocationNumber'], 'LEGACY-300');
    expect(customerJson['pestPacBillToNumber'], '');
    expect(customerJson['pestPacAccountNumber'], 'LEGACY-300');
  });

  test('retains marker category and type in saved documents', () {
    final document = GraphDocument(
      customer: GraphCustomerInfo.fromJob(job),
      annotations: const [
        GraphAnnotation(
          kind: GraphAnnotationKind.marker,
          point: GraphPoint(x: 20, y: 30),
          label: 'VD',
          markerType: GraphMarkerType.verticalDrill,
        ),
      ],
    );

    final restored = GraphDocument.fromJson(document.toJson());
    expect(
        restored.annotations.single.markerType, GraphMarkerType.verticalDrill);
    expect(restored.annotations.single.markerType.category,
        GraphMarkerCategory.treatment);
  });

  test('older graphs retain marker types removed from new-placement UI', () {
    final restored = GraphDocument.fromJson({
      'schemaVersion': 2,
      'customer': GraphCustomerInfo.fromJob(job).toJson(),
      'annotations': [
        {
          'kind': 'marker',
          'point': {'x': 42, 'y': 64},
          'label': 'AT',
          'markerType': 'activeTermites',
        },
        {
          'kind': 'marker',
          'point': {'x': 80, 'y': 96},
          'label': 'CAM',
          'markerType': 'camera',
        },
      ],
    });

    expect(restored.annotations.map((item) => item.markerType), [
      GraphMarkerType.activeTermites,
      GraphMarkerType.camera,
    ]);
    final roundTripped = GraphDocument.fromJson(restored.toJson());
    expect(roundTripped.annotations, hasLength(2));
  });
}
