import 'package:flutter/material.dart';

import '../editor/editor_interaction_controller.dart';
import '../models/graph_annotation.dart';
import '../models/graph_shape.dart';
import 'graph_marker_visual.dart';

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    required this.selectedTool,
    required this.selectedMarkerType,
    required this.selectedDrawingPreset,
    required this.onToolSelected,
    required this.onMarkerSelected,
    required this.onDrawingPresetSelected,
    required this.traceLayerVisible,
    required this.onToggleTraceLayer,
    super.key,
  });

  final CanvasTool selectedTool;
  final GraphMarkerType selectedMarkerType;
  final GraphDrawingPreset? selectedDrawingPreset;
  final ValueChanged<CanvasTool> onToolSelected;
  final ValueChanged<GraphMarkerType> onMarkerSelected;
  final ValueChanged<GraphDrawingPreset> onDrawingPresetSelected;
  final bool traceLayerVisible;
  final VoidCallback onToggleTraceLayer;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const _ToolbarGroupLabel(label: 'Drawing Tools'),
              for (final tool in const [
                CanvasTool.select,
                CanvasTool.pan,
                CanvasTool.wall,
                CanvasTool.arrow,
                CanvasTool.curve,
                CanvasTool.freehand,
                CanvasTool.rectangle,
                CanvasTool.circle,
                CanvasTool.ellipse,
                CanvasTool.triangle,
              ]) ...[
                _ToolButton(
                  icon: tool.icon,
                  label: tool.label,
                  shortcut: tool.shortcut,
                  selected: selectedTool == tool,
                  onPressed: () => onToolSelected(tool),
                ),
                const SizedBox(height: 8),
              ],
              _DrawingPresetPickerButton(
                selectedPreset: selectedDrawingPreset,
                active: selectedTool == CanvasTool.structure &&
                    selectedDrawingPreset != null &&
                    _drawingToolPresets.contains(selectedDrawingPreset),
                onSelected: onDrawingPresetSelected,
              ),
              const SizedBox(height: 8),
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Structures'),
              _StructurePickerButton(
                selectedPreset:
                    selectedDrawingPreset ?? GraphDrawingPreset.mainStructure,
                active: selectedTool == CanvasTool.structure,
                onSelected: onDrawingPresetSelected,
              ),
              const SizedBox(height: 8),
              _MarkerToolButton(
                markerType: GraphMarkerType.pier,
                selected: selectedTool == CanvasTool.marker &&
                    selectedMarkerType == GraphMarkerType.pier,
                onPressed: () => onMarkerSelected(GraphMarkerType.pier),
              ),
              const SizedBox(height: 8),
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Inspection Markers'),
              _MarkerPickerButton(
                tooltipLabel: 'Inspection Marker',
                selectedMarker: selectedMarkerType,
                active: selectedTool == CanvasTool.marker,
                markers: _inspectionMarkers,
                onSelected: onMarkerSelected,
              ),
              const SizedBox(height: 8),
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Treatment Markers'),
              _MarkerPickerButton(
                tooltipLabel: 'Treatment Marker',
                selectedMarker: selectedMarkerType,
                active: selectedTool == CanvasTool.marker &&
                    _treatmentMarkers.contains(selectedMarkerType),
                markers: _treatmentMarkers,
                onSelected: onMarkerSelected,
              ),
              const SizedBox(height: 8),
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Review'),
              for (final tool in const [
                CanvasTool.text,
                CanvasTool.photo,
              ]) ...[
                _ToolButton(
                  icon: tool.icon,
                  label: tool.label,
                  shortcut: tool.shortcut,
                  selected: selectedTool == tool,
                  onPressed: () => onToolSelected(tool),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 18),
              _ToolButton(
                icon: traceLayerVisible ? Icons.layers : Icons.layers_outlined,
                label: 'Trace',
                shortcut: '',
                selected: traceLayerVisible,
                onPressed: onToggleTraceLayer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _drawingToolPresets = <GraphDrawingPreset>[
  GraphDrawingPreset.propertyLine,
  GraphDrawingPreset.fenceLine,
  GraphDrawingPreset.measurementLine,
];

final _structurePresets = GraphDrawingPreset.values
    .where((preset) =>
        preset.kind == GraphDrawingPresetKind.area &&
        preset != GraphDrawingPreset.treatmentArea)
    .toList(growable: false);

final _inspectionMarkers = GraphMarkerType.values
    .where((marker) =>
        marker.availableForNewPlacement &&
        marker.category != GraphMarkerCategory.treatment &&
        marker.category != GraphMarkerCategory.review &&
        marker != GraphMarkerType.pier)
    .toList(growable: false);

final _treatmentMarkers = <GraphMarkerType>[
  GraphMarkerType.treatmentArea,
  ...GraphMarkerType.values.where((marker) =>
      marker.availableForNewPlacement &&
      marker.category == GraphMarkerCategory.treatment &&
      marker != GraphMarkerType.treatmentArea),
  GraphMarkerType.treatmentNote,
];

@visibleForTesting
List<GraphMarkerType> get availableInspectionMarkers => _inspectionMarkers;

@visibleForTesting
List<GraphMarkerType> get availableTreatmentMarkers => _treatmentMarkers;

@visibleForTesting
List<GraphDrawingPreset> get structureToolbarPresets => _structurePresets;

@visibleForTesting
List<GraphDrawingPreset> get drawingToolbarPresets => _drawingToolPresets;

class _DrawingPresetPickerButton extends StatelessWidget {
  const _DrawingPresetPickerButton({
    required this.selectedPreset,
    required this.active,
    required this.onSelected,
  });

  final GraphDrawingPreset? selectedPreset;
  final bool active;
  final ValueChanged<GraphDrawingPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final displayed = _drawingToolPresets.contains(selectedPreset)
        ? selectedPreset!
        : GraphDrawingPreset.measurementLine;
    return _PresetPickerButton(
      tooltip: 'Drawing Tools',
      displayedPreset: displayed,
      presets: _drawingToolPresets,
      active: active,
      onSelected: onSelected,
    );
  }
}

class _StructurePickerButton extends StatelessWidget {
  const _StructurePickerButton({
    required this.selectedPreset,
    required this.active,
    required this.onSelected,
  });

  final GraphDrawingPreset selectedPreset;
  final bool active;
  final ValueChanged<GraphDrawingPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final displayed = _structurePresets.contains(selectedPreset)
        ? selectedPreset
        : GraphDrawingPreset.mainStructure;
    return _PresetPickerButton(
      tooltip: 'Draw Structure',
      displayedPreset: displayed,
      presets: _structurePresets,
      active: active,
      onSelected: onSelected,
    );
  }
}

class _PresetPickerButton extends StatelessWidget {
  const _PresetPickerButton({
    required this.tooltip,
    required this.displayedPreset,
    required this.presets,
    required this.active,
    required this.onSelected,
  });

  final String tooltip;
  final GraphDrawingPreset displayedPreset;
  final List<GraphDrawingPreset> presets;
  final bool active;
  final ValueChanged<GraphDrawingPreset> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        height: 62,
        child: PopupMenuButton<GraphDrawingPreset>(
          tooltip: '$tooltip: ${displayedPreset.label}',
          onSelected: onSelected,
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          itemBuilder: (context) => [
            for (final preset in presets)
              PopupMenuItem(
                value: preset,
                child: Row(
                  children: [
                    _StructureSwatch(preset: preset),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        preset.label,
                        style: TextStyle(
                          fontWeight: preset == displayedPreset
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (preset == displayedPreset)
                      const Icon(Icons.check, size: 20),
                  ],
                ),
              ),
          ],
          child: _PickerFace(
            icon: Icons.account_tree_outlined,
            label: displayedPreset.shortLabel,
            color: displayedPreset.defaultBorderColor,
            active: active,
          ),
        ),
      );
}

class _StructureSwatch extends StatelessWidget {
  const _StructureSwatch({required this.preset});
  final GraphDrawingPreset preset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: preset.defaultFillColor?.withValues(
              alpha: preset.defaultFillOpacity,
            ) ??
            Colors.white,
        border: Border.all(
          color: preset.defaultBorderColor,
          width: preset.defaultBorderWidth.clamp(1, 4),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: preset.defaultPattern == GraphShapePattern.none
          ? Icon(_iconForPreset(preset), size: 18)
          : const Icon(Icons.texture, size: 18),
    );
  }
}

class _MarkerPickerButton extends StatelessWidget {
  const _MarkerPickerButton({
    required this.tooltipLabel,
    required this.selectedMarker,
    required this.active,
    required this.markers,
    required this.onSelected,
  });

  final String tooltipLabel;
  final GraphMarkerType selectedMarker;
  final bool active;
  final List<GraphMarkerType> markers;
  final ValueChanged<GraphMarkerType> onSelected;

  @override
  Widget build(BuildContext context) {
    final displayedMarker =
        markers.contains(selectedMarker) ? selectedMarker : markers.first;
    return SizedBox(
      width: 56,
      height: 62,
      child: PopupMenuButton<GraphMarkerType>(
        tooltip: '$tooltipLabel: ${displayedMarker.label}',
        onSelected: onSelected,
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
        itemBuilder: (context) => [
          for (final marker in markers)
            PopupMenuItem(
              value: marker,
              child: Row(
                children: [
                  Icon(
                    iconForGraphMarker(marker),
                    color: marker.defaultColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(marker.label)),
                  if (marker == selectedMarker)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
        ],
        child: _PickerFace(
          icon: iconForGraphMarker(displayedMarker),
          label: displayedMarker.shortLabel,
          color: displayedMarker.defaultColor,
          active: active,
        ),
      ),
    );
  }
}

class _PickerFace extends StatelessWidget {
  const _PickerFace({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.18) : Colors.white,
        border: Border.all(color: active ? color : const Color(0xFFE3E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForPreset(GraphDrawingPreset preset) => switch (preset) {
      GraphDrawingPreset.mainStructure => Icons.home_work_outlined,
      GraphDrawingPreset.slab => Icons.grid_on,
      GraphDrawingPreset.crawlspace => Icons.foundation_outlined,
      GraphDrawingPreset.basement => Icons.layers_outlined,
      GraphDrawingPreset.woodDeck => Icons.deck_outlined,
      GraphDrawingPreset.openPorch => Icons.meeting_room_outlined,
      GraphDrawingPreset.dirtFilledPorch => Icons.terrain_outlined,
      GraphDrawingPreset.dirtArea => Icons.landscape_outlined,
      GraphDrawingPreset.garage => Icons.garage_outlined,
      GraphDrawingPreset.detachedStructure => Icons.other_houses_outlined,
      GraphDrawingPreset.propertyLine => Icons.border_style,
      GraphDrawingPreset.fenceLine => Icons.fence,
      GraphDrawingPreset.measurementLine => Icons.straighten,
      GraphDrawingPreset.treatmentArea => Icons.select_all_outlined,
    };

class _ToolbarGroupLabel extends StatelessWidget {
  const _ToolbarGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF666B62),
              fontSize: 9,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _MarkerToolButton extends StatelessWidget {
  const _MarkerToolButton({
    required this.markerType,
    required this.selected,
    required this.onPressed,
  });

  final GraphMarkerType markerType;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 56,
      height: 58,
      child: Tooltip(
        message: markerType.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? markerType.defaultColor.withValues(alpha: 0.18)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? markerType.defaultColor
                    : const Color(0xFFE3E0D8),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconForGraphMarker(markerType),
                  color: markerType.defaultColor,
                  size: 25,
                ),
                const SizedBox(height: 3),
                Text(
                  markerType.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? markerType.defaultColor
                            : colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String shortcut;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 56,
      height: 58,
      child: Tooltip(
        message: shortcut.isEmpty ? label : '$label ($shortcut)',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colorScheme.primary : colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? colorScheme.primary : const Color(0xFFE3E0D8),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? colorScheme.onPrimary : colorScheme.primary,
                ),
                const SizedBox(height: 3),
                Text(
                  shortcut.isEmpty ? label : '$label $shortcut',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
