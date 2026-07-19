import 'package:bugman_graphs/editor/editor_interaction_controller.dart';
import 'package:bugman_graphs/models/graph_annotation.dart';
import 'package:bugman_graphs/models/graph_point.dart';
import 'package:bugman_graphs/models/graph_shape.dart';
import 'package:bugman_graphs/models/wall_segment.dart';
import 'package:bugman_graphs/widgets/wall_segments_painter.dart';
import 'package:bugman_graphs/widgets/canvas_toolbar.dart';
import 'package:bugman_graphs/widgets/graph_marker_visual.dart';
import 'package:bugman_graphs/widgets/graph_shapes_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interaction controller keeps tool, structure, and marker intent', () {
    final controller = EditorInteractionController();
    addTearDown(controller.dispose);

    controller.selectStructure(GraphDrawingPreset.detachedStructure);
    expect(controller.primaryTool, CanvasTool.structure);
    expect(controller.structureType, GraphDrawingPreset.detachedStructure);

    controller.selectTool(CanvasTool.rectangle);
    expect(controller.primaryTool, CanvasTool.rectangle);
    expect(controller.structureType, GraphDrawingPreset.detachedStructure);

    controller.selectMarker(GraphMarkerType.verticalDrill);
    expect(controller.primaryTool, CanvasTool.marker);
    expect(controller.markerType.category, GraphMarkerCategory.treatment);
  });

  test('line and arrow use one continuous shaft geometry', () {
    const line = WallSegment(
      start: GraphPoint(x: 20, y: 40),
      end: GraphPoint(x: 220, y: 40),
    );
    const arrow = WallSegment(
      start: GraphPoint(x: 220, y: 180),
      end: GraphPoint(x: 40, y: 60),
      hasArrow: true,
    );

    final lineMetrics = buildWallSegmentPath(line).computeMetrics().toList();
    final arrowMetrics = buildWallSegmentPath(arrow).computeMetrics().toList();

    expect(lineMetrics, hasLength(1));
    expect(lineMetrics.single.length, closeTo(200, 0.01));
    expect(arrowMetrics, hasLength(1));
    expect(arrowMetrics.single.length, closeTo(216.33, 0.1));
  });

  test('toolbar cleanup preserves legacy enums but hides removed entries', () {
    const removed = <GraphMarkerType>{
      GraphMarkerType.carpenterAntEvidence,
      GraphMarkerType.carpenterBeeEvidence,
      GraphMarkerType.roachActivity,
      GraphMarkerType.otherPestEvidence,
      GraphMarkerType.conduciveCondition,
      GraphMarkerType.crawlspaceIssue,
      GraphMarkerType.woodDecay,
      GraphMarkerType.entryPoint,
      GraphMarkerType.termiteActivity,
      GraphMarkerType.termiteDamage,
      GraphMarkerType.activeTermites,
      GraphMarkerType.oldTermiteActivity,
      GraphMarkerType.oldDamage,
      GraphMarkerType.damage,
      GraphMarkerType.foundationCrack,
      GraphMarkerType.plumbingPenetration,
      GraphMarkerType.utilityPenetration,
      GraphMarkerType.expansionJoint,
      GraphMarkerType.pestEntryPoint,
      GraphMarkerType.highMoisture,
      GraphMarkerType.activeLeak,
      GraphMarkerType.condensation,
      GraphMarkerType.drainageConcern,
      GraphMarkerType.accessPoint,
      GraphMarkerType.vent,
      GraphMarkerType.door,
      GraphMarkerType.window,
      GraphMarkerType.garageDoor,
      GraphMarkerType.deckSupport,
      GraphMarkerType.foundationVent,
      GraphMarkerType.photoPoint,
      GraphMarkerType.camera,
      GraphMarkerType.notePoint,
    };

    expect(availableInspectionMarkers, isNot(containsAll(removed)));
    expect(availableInspectionMarkers.where(removed.contains), isEmpty);
    expect(availableInspectionMarkers, contains(GraphMarkerType.woodFungi));
    expect(availableInspectionMarkers, contains(GraphMarkerType.rot));
    expect(GraphMarkerType.rot.label, 'Wood Rot');
    expect(GraphMarkerType.woodFungi.label, 'Wood Destroying Fungi');
    expect(availableTreatmentMarkers, contains(GraphMarkerType.treatmentArea));
    expect(availableTreatmentMarkers, contains(GraphMarkerType.rodentBox));
    expect(availableTreatmentMarkers, contains(GraphMarkerType.rodentTrap));
    expect(availableTreatmentMarkers, contains(GraphMarkerType.treatmentNote));
    expect(availableTreatmentMarkers, isNot(contains(GraphMarkerType.circle)));
    expect(drawingToolbarPresets, contains(GraphDrawingPreset.measurementLine));
    expect(structureToolbarPresets,
        isNot(contains(GraphDrawingPreset.measurementLine)));
    expect(structureToolbarPresets,
        isNot(contains(GraphDrawingPreset.treatmentArea)));
  });

  test('completed fence uses its saved X-mark segment styling', () {
    const fence = GraphShape(
      name: 'Fence Line',
      segmentIndexes: [0],
      fillColor: null,
      fillOpacity: 0,
      borderColor: Color(0xFF795548),
      borderWidth: 2,
      pattern: GraphShapePattern.none,
      closed: false,
      rotationDegrees: 0,
      preset: GraphDrawingPreset.fenceLine,
    );
    const segment = WallSegment(
      start: GraphPoint(x: 10, y: 10),
      end: GraphPoint(x: 200, y: 10),
      pattern: LinePattern.xMarks,
    );

    expect(usesStyledSegmentRendering(fence), isTrue);
    expect(segment.pattern, LinePattern.xMarks);
    expect(GraphDrawingPreset.fenceLine.defaultLinePattern,
        LinePatternValue.xMarks);
  });

  test('canvas markers use the same recognizable icon mapping as toolbar', () {
    for (final marker in {
      ...availableInspectionMarkers,
      ...availableTreatmentMarkers,
      GraphMarkerType.pier,
    }) {
      expect(iconForGraphMarker(marker).codePoint, isPositive);
    }
    expect(iconForGraphMarker(GraphMarkerType.rodentBox),
        isNot(iconForGraphMarker(GraphMarkerType.rodentTrap)));
  });
}
