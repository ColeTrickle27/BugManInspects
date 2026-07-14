import 'package:flutter/material.dart';

import '../models/graph_annotation.dart';
import '../models/graph_shape.dart';

enum CanvasTool {
  select(Icons.mouse_outlined, 'Select', 'V'),
  pan(Icons.pan_tool_alt_outlined, 'Pan', 'H'),
  rectangle(Icons.crop_square, 'Rect', 'R'),
  square(Icons.check_box_outline_blank, 'Square', 'S'),
  circle(Icons.circle_outlined, 'Circle', 'C'),
  ellipse(Icons.radio_button_unchecked, 'Ellipse', 'E'),
  triangle(Icons.change_history, 'Tri', 'G'),
  wall(Icons.polyline_outlined, 'Line', 'L'),
  arrow(Icons.arrow_forward, 'Arrow', 'A'),
  curve(Icons.timeline, 'Curve', 'U'),
  freehand(Icons.gesture, 'Draw', 'F'),
  marker(Icons.place_outlined, 'Marker', 'M'),
  photo(Icons.add_a_photo_outlined, 'Photo', 'P'),
  text(Icons.text_fields, 'Text', 'T');

  const CanvasTool(this.icon, this.label, this.shortcut);

  final IconData icon;
  final String label;
  final String shortcut;
}

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
              const _ToolbarGroupLabel(label: 'Drawing'),
              for (final tool in const [
                CanvasTool.select,
                CanvasTool.pan,
                CanvasTool.wall,
                CanvasTool.arrow,
                CanvasTool.curve,
                CanvasTool.freehand,
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
              for (final preset in GraphDrawingPreset.values) ...[
                _DrawingPresetButton(
                  preset: preset,
                  selected: selectedDrawingPreset == preset,
                  onPressed: () => onDrawingPresetSelected(preset),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Shapes'),
              for (final tool in const [
                CanvasTool.rectangle,
                CanvasTool.square,
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
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Inspection\nMarkers'),
              for (final markerType in _inspectionMarkerTypes) ...[
                _MarkerToolButton(
                  markerType: markerType,
                  selected: selectedTool == CanvasTool.marker &&
                      selectedMarkerType == markerType,
                  onPressed: () => onMarkerSelected(markerType),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Treatment\nMarkers'),
              for (final markerType in _treatmentMarkerTypes) ...[
                _MarkerToolButton(
                  markerType: markerType,
                  selected: selectedTool == CanvasTool.marker &&
                      selectedMarkerType == markerType,
                  onPressed: () => onMarkerSelected(markerType),
                ),
                const SizedBox(height: 8),
              ],
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
              for (final markerType in const [
                GraphMarkerType.notePoint,
                GraphMarkerType.photoPoint,
                GraphMarkerType.recommendationPoint,
              ]) ...[
                _MarkerToolButton(
                  markerType: markerType,
                  selected: selectedTool == CanvasTool.marker &&
                      selectedMarkerType == markerType,
                  onPressed: () => onMarkerSelected(markerType),
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

const List<GraphMarkerType> _inspectionMarkerTypes = [
  GraphMarkerType.termiteActivity,
  GraphMarkerType.activeTermites,
  GraphMarkerType.termiteDamage,
  GraphMarkerType.moisture,
  GraphMarkerType.standingWater,
  GraphMarkerType.conduciveCondition,
  GraphMarkerType.crawlspaceIssue,
  GraphMarkerType.plumbingLeak,
  GraphMarkerType.hvacCondensation,
  GraphMarkerType.insulationIssue,
  GraphMarkerType.woodDecay,
  GraphMarkerType.accessPoint,
  GraphMarkerType.entryPoint,
  GraphMarkerType.rodentActivity,
  GraphMarkerType.generalPestActivity,
  GraphMarkerType.oldDamage,
  GraphMarkerType.oldTermiteActivity,
  GraphMarkerType.damage,
  GraphMarkerType.woodFungi,
  GraphMarkerType.oldHouseBorers,
  GraphMarkerType.powderPostBeetles,
];

const List<GraphMarkerType> _treatmentMarkerTypes = [
  GraphMarkerType.treatmentArea,
  GraphMarkerType.baitStation,
  GraphMarkerType.treatmentNote,
  GraphMarkerType.circle,
  GraphMarkerType.triangle,
  GraphMarkerType.square,
];

class _DrawingPresetButton extends StatelessWidget {
  const _DrawingPresetButton({
    required this.preset,
    required this.selected,
    required this.onPressed,
  });

  final GraphDrawingPreset preset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = preset.kind == GraphDrawingPresetKind.line
        ? preset.defaultLineColor
        : preset.defaultBorderColor;

    return SizedBox(
      width: 56,
      height: 58,
      child: Tooltip(
        message: preset.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.16)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? color : const Color(0xFFE3E0D8),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _iconForPreset(preset),
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  preset.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? color : colorScheme.primary,
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

  IconData _iconForPreset(GraphDrawingPreset preset) {
    return switch (preset) {
      GraphDrawingPreset.mainStructure => Icons.home_work_outlined,
      GraphDrawingPreset.slab => Icons.grid_on,
      GraphDrawingPreset.crawlspace => Icons.foundation_outlined,
      GraphDrawingPreset.basement => Icons.layers_outlined,
      GraphDrawingPreset.woodDeck => Icons.deck_outlined,
      GraphDrawingPreset.openPorch => Icons.meeting_room_outlined,
      GraphDrawingPreset.dirtFilledPorch => Icons.terrain_outlined,
      GraphDrawingPreset.garage => Icons.garage_outlined,
      GraphDrawingPreset.detachedStructure => Icons.other_houses_outlined,
      GraphDrawingPreset.propertyLine => Icons.border_style,
      GraphDrawingPreset.fenceLine => Icons.fence,
      GraphDrawingPreset.measurementLine => Icons.straighten,
    };
  }
}

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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF666B62),
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
                Container(
                  width: 26,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: markerType.defaultColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      markerType.shortLabel,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
