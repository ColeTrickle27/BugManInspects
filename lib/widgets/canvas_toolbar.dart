import 'package:flutter/material.dart';

import '../editor/editor_interaction_controller.dart';
import '../models/graph_annotation.dart';
import '../models/graph_shape.dart';

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
              const Divider(height: 18),
              const _ToolbarGroupLabel(label: 'Structures'),
              _StructurePickerButton(
                selectedPreset:
                    selectedDrawingPreset ?? GraphDrawingPreset.mainStructure,
                active: selectedTool == CanvasTool.structure,
                onSelected: onDrawingPresetSelected,
              ),
              const SizedBox(height: 8),
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
              const _ToolbarGroupLabel(label: 'Markers'),
              _MarkerPickerButton(
                selectedMarker: selectedMarkerType,
                active: selectedTool == CanvasTool.marker,
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
              _QuickReviewButton(
                markerType: GraphMarkerType.treatmentNote,
                selected: selectedTool == CanvasTool.marker &&
                    selectedMarkerType == GraphMarkerType.treatmentNote,
                onPressed: () =>
                    onMarkerSelected(GraphMarkerType.treatmentNote),
              ),
              const SizedBox(height: 8),
              _QuickReviewButton(
                markerType: GraphMarkerType.notePoint,
                selected: selectedTool == CanvasTool.marker &&
                    selectedMarkerType == GraphMarkerType.notePoint,
                onPressed: () => onMarkerSelected(GraphMarkerType.notePoint),
              ),
              const SizedBox(height: 8),
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
    return SizedBox(
      width: 56,
      height: 62,
      child: PopupMenuButton<GraphDrawingPreset>(
        tooltip: 'Draw Structure: ${selectedPreset.label}',
        onSelected: onSelected,
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
        itemBuilder: (context) => [
          for (final preset in GraphDrawingPreset.values)
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
                        fontWeight: preset == selectedPreset
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (preset == selectedPreset)
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
        ],
        child: _PickerFace(
          icon: Icons.account_tree_outlined,
          label: selectedPreset.shortLabel,
          color: selectedPreset.defaultBorderColor,
          active: active,
        ),
      ),
    );
  }
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
    required this.selectedMarker,
    required this.active,
    required this.onSelected,
  });

  final GraphMarkerType selectedMarker;
  final bool active;
  final ValueChanged<GraphMarkerType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 62,
      child: PopupMenuButton<GraphMarkerType>(
        tooltip: 'Marker: ${selectedMarker.label}',
        onSelected: onSelected,
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
        itemBuilder: (context) => [
          for (final category in GraphMarkerCategory.values) ...[
            PopupMenuItem<GraphMarkerType>(
              enabled: false,
              height: 34,
              child: Text(
                category.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final marker in GraphMarkerType.values
                .where((item) => item.category == category))
              PopupMenuItem(
                value: marker,
                child: Row(
                  children: [
                    Icon(
                      _iconForMarker(marker),
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
        ],
        child: _PickerFace(
          icon: _iconForMarker(selectedMarker),
          label: selectedMarker.shortLabel,
          color: selectedMarker.defaultColor,
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

class _QuickReviewButton extends StatelessWidget {
  const _QuickReviewButton({
    required this.markerType,
    required this.selected,
    required this.onPressed,
  });

  final GraphMarkerType markerType;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _MarkerToolButton(
        markerType: markerType,
        selected: selected,
        onPressed: onPressed,
      );
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
    };

IconData _iconForMarker(GraphMarkerType marker) => switch (marker.symbol) {
      GraphMarkerSymbol.termite => Icons.pest_control_outlined,
      GraphMarkerSymbol.damage => Icons.handyman_outlined,
      GraphMarkerSymbol.mudTube => Icons.route_outlined,
      GraphMarkerSymbol.insect => Icons.bug_report_outlined,
      GraphMarkerSymbol.rodent => Icons.pets_outlined,
      GraphMarkerSymbol.moisture => Icons.water_drop_outlined,
      GraphMarkerSymbol.water => Icons.water_outlined,
      GraphMarkerSymbol.leak => Icons.plumbing_outlined,
      GraphMarkerSymbol.fungi => Icons.grass_outlined,
      GraphMarkerSymbol.crack => Icons.warning_amber_outlined,
      GraphMarkerSymbol.penetration => Icons.adjust_outlined,
      GraphMarkerSymbol.access => Icons.meeting_room_outlined,
      GraphMarkerSymbol.vent => Icons.air_outlined,
      GraphMarkerSymbol.door => Icons.door_front_door_outlined,
      GraphMarkerSymbol.window => Icons.window_outlined,
      GraphMarkerSymbol.steps => Icons.stairs_outlined,
      GraphMarkerSymbol.hvac => Icons.ac_unit_outlined,
      GraphMarkerSymbol.utility => Icons.cable_outlined,
      GraphMarkerSymbol.support => Icons.foundation_outlined,
      GraphMarkerSymbol.drillVertical => Icons.south_outlined,
      GraphMarkerSymbol.drillHorizontal => Icons.east_outlined,
      GraphMarkerSymbol.trench => Icons.linear_scale_outlined,
      GraphMarkerSymbol.injection => Icons.colorize_outlined,
      GraphMarkerSymbol.foam => Icons.bubble_chart_outlined,
      GraphMarkerSymbol.treatment => Icons.science_outlined,
      GraphMarkerSymbol.bait => Icons.location_on_outlined,
      GraphMarkerSymbol.dust => Icons.blur_on_outlined,
      GraphMarkerSymbol.exclusion => Icons.block_outlined,
      GraphMarkerSymbol.camera => Icons.photo_camera_outlined,
      GraphMarkerSymbol.note => Icons.note_alt_outlined,
      GraphMarkerSymbol.alert => Icons.report_problem_outlined,
      GraphMarkerSymbol.generic => Icons.place_outlined,
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
