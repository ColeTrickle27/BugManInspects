import 'package:flutter/material.dart';

import '../models/graph_annotation.dart';
import '../models/graph_marker_catalog.dart';
import '../models/graph_point.dart';
import '../models/graph_shape.dart';
import '../widgets/graph_marker_visual.dart';

class GraphLegendEntry {
  const GraphLegendEntry({
    required this.markerType,
    required this.color,
    required this.icon,
  });

  final GraphMarkerType markerType;
  final Color color;
  final IconData icon;
}

class GraphLegendSection {
  const GraphLegendSection({required this.title, required this.entries});

  final String title;
  final List<GraphLegendEntry> entries;
}

List<GraphLegendSection> buildGraphLegend(
  Iterable<GraphAnnotation> annotations, {
  Iterable<GraphShape> shapes = const [],
  bool inspectionsVisible = true,
  bool treatmentVisible = true,
}) {
  final placed = <GraphMarkerType, GraphAnnotation>{};
  for (final annotation in annotations) {
    if (annotation.kind == GraphAnnotationKind.marker &&
        ((isTreatmentMarker(annotation.markerType) && treatmentVisible) ||
            (!isTreatmentMarker(annotation.markerType) &&
                inspectionsVisible))) {
      placed.putIfAbsent(annotation.markerType, () => annotation);
    }
  }
  if (treatmentVisible &&
      shapes.any(
        (shape) => shape.preset == GraphDrawingPreset.treatmentArea,
      )) {
    placed.putIfAbsent(
      GraphMarkerType.treatmentArea,
      () => const GraphAnnotation(
        kind: GraphAnnotationKind.marker,
        point: GraphPoint(x: 0, y: 0),
        label: 'Treatment Area',
        markerType: GraphMarkerType.treatmentArea,
      ),
    );
  }
  GraphLegendEntry entry(GraphMarkerType type) => GraphLegendEntry(
        markerType: type,
        color: placed[type]?.color ?? type.defaultColor,
        icon: iconForGraphMarker(type),
      );

  final inspectionOrder = <GraphMarkerType>[
    ...inspectionMarkerTypes,
    ...placed.keys.where(
      (type) =>
          !inspectionMarkerTypes.contains(type) &&
          !isTreatmentMarker(type) &&
          !utilityMarkerTypes.contains(type) &&
          type.category != GraphMarkerCategory.review,
    ),
  ];
  final treatmentOrder = <GraphMarkerType>[
    ...treatmentMarkerTypes,
    ...placed.keys.where(
      (type) =>
          !treatmentMarkerTypes.contains(type) &&
          type.category == GraphMarkerCategory.treatment,
    ),
  ];
  final sections = <GraphLegendSection>[];
  final inspectionEntries = inspectionOrder
      .where(placed.containsKey)
      .map(entry)
      .toList(growable: false);
  final treatmentEntries = treatmentOrder
      .where(placed.containsKey)
      .map(entry)
      .toList(growable: false);
  if (inspectionsVisible && inspectionEntries.isNotEmpty) {
    sections.add(
      GraphLegendSection(
        title: 'Inspection Markers',
        entries: inspectionEntries,
      ),
    );
  }
  if (treatmentVisible && treatmentEntries.isNotEmpty) {
    sections.add(
      GraphLegendSection(
        title: 'Treatment Markers',
        entries: treatmentEntries,
      ),
    );
  }
  return sections;
}
