import 'package:bugman_graphs/editor/editor_interaction_controller.dart';
import 'package:bugman_graphs/models/graph_annotation.dart';
import 'package:bugman_graphs/models/graph_point.dart';
import 'package:bugman_graphs/models/graph_shape.dart';
import 'package:bugman_graphs/models/wall_segment.dart';
import 'package:bugman_graphs/widgets/wall_segments_painter.dart';
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
}
