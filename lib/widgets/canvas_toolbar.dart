import 'package:flutter/material.dart';

import '../editor/editor_interaction_controller.dart';
import '../models/graph_annotation.dart';
import '../models/graph_shape.dart';
import 'graph_marker_visual.dart';

enum CanvasToolbarActionKind { tool, preset, marker }

@immutable
class CanvasToolbarAction {
  const CanvasToolbarAction.tool(this.tool)
      : kind = CanvasToolbarActionKind.tool,
        preset = null,
        marker = null;

  const CanvasToolbarAction.preset(this.preset)
      : kind = CanvasToolbarActionKind.preset,
        tool = null,
        marker = null;

  const CanvasToolbarAction.marker(this.marker)
      : kind = CanvasToolbarActionKind.marker,
        tool = null,
        preset = null;

  final CanvasToolbarActionKind kind;
  final CanvasTool? tool;
  final GraphDrawingPreset? preset;
  final GraphMarkerType? marker;

  String get label => switch (kind) {
        CanvasToolbarActionKind.tool => tool!.label,
        CanvasToolbarActionKind.preset =>
          preset == GraphDrawingPreset.propertyLine
              ? 'Property Line (acres)'
              : preset!.label,
        CanvasToolbarActionKind.marker => marker!.label,
      };

  String get shortLabel => switch (kind) {
        CanvasToolbarActionKind.tool => tool!.label,
        CanvasToolbarActionKind.preset => preset!.shortLabel,
        CanvasToolbarActionKind.marker => marker!.shortLabel,
      };

  String get shortcut => tool?.shortcut ?? '';

  IconData get icon => switch (kind) {
        CanvasToolbarActionKind.tool => tool!.icon,
        CanvasToolbarActionKind.preset => iconForDrawingPreset(preset!),
        CanvasToolbarActionKind.marker => iconForGraphMarker(marker!),
      };

  Color get color => switch (kind) {
        CanvasToolbarActionKind.tool => const Color(0xFFCC2000),
        CanvasToolbarActionKind.preset => preset!.defaultBorderColor,
        CanvasToolbarActionKind.marker => marker!.defaultColor,
      };

  String get tooltip => shortcut.isEmpty ? label : '$label ($shortcut)';

  bool isSelected({
    required CanvasTool selectedTool,
    required GraphDrawingPreset? selectedPreset,
    required GraphMarkerType selectedMarker,
  }) =>
      switch (kind) {
        CanvasToolbarActionKind.tool => selectedTool == tool,
        CanvasToolbarActionKind.preset =>
          selectedTool == CanvasTool.structure && selectedPreset == preset,
        CanvasToolbarActionKind.marker =>
          selectedTool == CanvasTool.marker && selectedMarker == marker,
      };

  @override
  bool operator ==(Object other) =>
      other is CanvasToolbarAction &&
      other.kind == kind &&
      other.tool == tool &&
      other.preset == preset &&
      other.marker == marker;

  @override
  int get hashCode => Object.hash(kind, tool, preset, marker);
}

const basicLineToolbarActions = <CanvasToolbarAction>[
  CanvasToolbarAction.tool(CanvasTool.wall),
  CanvasToolbarAction.tool(CanvasTool.arrow),
  CanvasToolbarAction.tool(CanvasTool.curve),
  CanvasToolbarAction.tool(CanvasTool.freehand),
];

const basicShapeToolbarActions = <CanvasToolbarAction>[
  CanvasToolbarAction.tool(CanvasTool.rectangle),
  CanvasToolbarAction.tool(CanvasTool.circle),
  CanvasToolbarAction.tool(CanvasTool.ellipse),
  CanvasToolbarAction.tool(CanvasTool.triangle),
];

const buildingFeatureToolbarActions = <CanvasToolbarAction>[
  CanvasToolbarAction.preset(GraphDrawingPreset.slab),
  CanvasToolbarAction.preset(GraphDrawingPreset.crawlspace),
  CanvasToolbarAction.preset(GraphDrawingPreset.woodDeck),
  CanvasToolbarAction.preset(GraphDrawingPreset.openPorch),
  CanvasToolbarAction.preset(GraphDrawingPreset.dirtFilledPorch),
  CanvasToolbarAction.preset(GraphDrawingPreset.garage),
  CanvasToolbarAction.preset(GraphDrawingPreset.detachedStructure),
];

const propertyToolbarActions = <CanvasToolbarAction>[
  CanvasToolbarAction.preset(GraphDrawingPreset.driveway),
  CanvasToolbarAction.preset(GraphDrawingPreset.walkway),
  CanvasToolbarAction.preset(GraphDrawingPreset.propertyLine),
];

const utilityToolbarActions = <CanvasToolbarAction>[
  CanvasToolbarAction.marker(GraphMarkerType.hvacUnit),
  CanvasToolbarAction.marker(GraphMarkerType.pier),
  CanvasToolbarAction.marker(GraphMarkerType.steps),
  CanvasToolbarAction.marker(GraphMarkerType.crawlspaceAccess),
  CanvasToolbarAction.marker(GraphMarkerType.gasLine),
  CanvasToolbarAction.marker(GraphMarkerType.waterLine),
];

const _utilityMarkers = <GraphMarkerType>{
  GraphMarkerType.hvacUnit,
  GraphMarkerType.pier,
  GraphMarkerType.steps,
  GraphMarkerType.crawlspaceAccess,
  GraphMarkerType.gasLine,
  GraphMarkerType.waterLine,
};

final _inspectionMarkers = GraphMarkerType.values
    .where((marker) =>
        marker.availableForNewPlacement &&
        marker.category != GraphMarkerCategory.treatment &&
        marker.category != GraphMarkerCategory.review &&
        !_utilityMarkers.contains(marker))
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
List<GraphDrawingPreset> get structureToolbarPresets => [
      GraphDrawingPreset.mainStructure,
      ...buildingFeatureToolbarActions.map((action) => action.preset!),
      ...propertyToolbarActions.map((action) => action.preset!),
    ];

@visibleForTesting
List<GraphDrawingPreset> get drawingToolbarPresets => const [
      GraphDrawingPreset.measurementLine,
    ];

@visibleForTesting
List<GraphMarkerType> get utilityToolbarMarkers =>
    utilityToolbarActions.map((action) => action.marker!).toList();

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
    required this.onCollapse,
    required this.onActionDoubleTapped,
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
  final VoidCallback onCollapse;
  final ValueChanged<CanvasToolbarAction> onActionDoubleTapped;

  void _activate(CanvasToolbarAction action) {
    switch (action.kind) {
      case CanvasToolbarActionKind.tool:
        onToolSelected(action.tool!);
      case CanvasToolbarActionKind.preset:
        onDrawingPresetSelected(action.preset!);
      case CanvasToolbarActionKind.marker:
        onMarkerSelected(action.marker!);
    }
  }

  CanvasToolbarAction _displayedAction(
    List<CanvasToolbarAction> actions,
  ) {
    for (final action in actions) {
      if (action.isSelected(
        selectedTool: selectedTool,
        selectedPreset: selectedDrawingPreset,
        selectedMarker: selectedMarkerType,
      )) {
        return action;
      }
    }
    return actions.first;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _ToolbarHeader(label: 'Basic', onCollapse: onCollapse),
              _ActionButton(
                action: const CanvasToolbarAction.preset(
                  GraphDrawingPreset.measurementLine,
                ),
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onPressed: _activate,
                onDoubleTap: () => onActionDoubleTapped(
                  const CanvasToolbarAction.preset(
                    GraphDrawingPreset.measurementLine,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ActionPicker(
                groupLabel: 'Lines',
                displayedAction: _displayedAction(basicLineToolbarActions),
                actions: basicLineToolbarActions,
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onSelected: _activate,
              ),
              const SizedBox(height: 8),
              _ActionPicker(
                groupLabel: 'Basic Shapes',
                displayedAction: _displayedAction(basicShapeToolbarActions),
                actions: basicShapeToolbarActions,
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onSelected: _activate,
              ),
              const Divider(height: 22),
              const _ToolbarGroupLabel(label: 'Structures'),
              _ActionButton(
                action: const CanvasToolbarAction.preset(
                  GraphDrawingPreset.mainStructure,
                ),
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onPressed: _activate,
                onDoubleTap: () => onActionDoubleTapped(
                  const CanvasToolbarAction.preset(
                    GraphDrawingPreset.mainStructure,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ActionPicker(
                groupLabel: 'Building Features',
                displayedAction:
                    _displayedAction(buildingFeatureToolbarActions),
                actions: buildingFeatureToolbarActions,
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onSelected: _activate,
              ),
              const SizedBox(height: 8),
              _ActionPicker(
                groupLabel: 'Property',
                displayedAction: _displayedAction(propertyToolbarActions),
                actions: propertyToolbarActions,
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onSelected: _activate,
              ),
              const SizedBox(height: 8),
              _ActionPicker(
                groupLabel: 'Utility',
                displayedAction: _displayedAction(utilityToolbarActions),
                actions: utilityToolbarActions,
                selectedTool: selectedTool,
                selectedPreset: selectedDrawingPreset,
                selectedMarker: selectedMarkerType,
                onSelected: _activate,
              ),
              const SizedBox(height: 8),
              for (final action in const [
                CanvasToolbarAction.tool(CanvasTool.text),
                CanvasToolbarAction.tool(CanvasTool.photo),
              ]) ...[
                _ActionButton(
                  action: action,
                  selectedTool: selectedTool,
                  selectedPreset: selectedDrawingPreset,
                  selectedMarker: selectedMarkerType,
                  onPressed: _activate,
                  onDoubleTap: () => onActionDoubleTapped(action),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 22),
              const _ToolbarGroupLabel(label: 'Inspection Markers'),
              _MarkerPickerButton(
                tooltipLabel: 'Inspection Marker',
                selectedMarker: selectedMarkerType,
                active: selectedTool == CanvasTool.marker,
                markers: _inspectionMarkers,
                onSelected: onMarkerSelected,
              ),
              const SizedBox(height: 8),
              const Divider(height: 22),
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
              const Divider(height: 22),
              _PlainToolButton(
                icon: traceLayerVisible ? Icons.layers : Icons.layers_outlined,
                label: 'Trace',
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

class CanvasQuickToolbar extends StatelessWidget {
  const CanvasQuickToolbar({
    required this.actions,
    required this.selectedTool,
    required this.selectedMarkerType,
    required this.selectedDrawingPreset,
    required this.onActionSelected,
    required this.onActionAdded,
    required this.onReset,
    required this.onCollapse,
    required this.onToggleProperties,
    required this.onToggleLayers,
    required this.onDeleteSelection,
    required this.propertiesSelected,
    required this.layersSelected,
    super.key,
  });

  final List<CanvasToolbarAction> actions;
  final CanvasTool selectedTool;
  final GraphMarkerType selectedMarkerType;
  final GraphDrawingPreset? selectedDrawingPreset;
  final ValueChanged<CanvasToolbarAction> onActionSelected;
  final ValueChanged<CanvasToolbarAction> onActionAdded;
  final VoidCallback onReset;
  final VoidCallback onCollapse;
  final VoidCallback onToggleProperties;
  final VoidCallback onToggleLayers;
  final VoidCallback onDeleteSelection;
  final bool propertiesSelected;
  final bool layersSelected;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CanvasToolbarAction>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onActionAdded(details.data),
      builder: (context, candidates, rejected) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 440;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Material(
              key: const ValueKey('canvas-quick-toolbar'),
              elevation: 10,
              color:
                  candidates.isEmpty ? Colors.white : const Color(0xFFFFE7E2),
              shape: StadiumBorder(
                side: BorderSide(
                  color: candidates.isEmpty
                      ? const Color(0xFF6D6E71)
                      : const Color(0xFFCC2000),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Hide quick toolbar',
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: onCollapse,
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    const SizedBox(height: 34, child: VerticalDivider()),
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _QuickActionButton(
                          action: action,
                          compact: compact,
                          selected: action.isSelected(
                            selectedTool: selectedTool,
                            selectedPreset: selectedDrawingPreset,
                            selectedMarker: selectedMarkerType,
                          ),
                          onPressed: () => onActionSelected(action),
                        ),
                      ),
                    const SizedBox(height: 34, child: VerticalDivider()),
                    _QuickUtilityButton(
                      icon: Icons.tune,
                      tooltip: 'Properties panel',
                      selected: propertiesSelected,
                      onPressed: onToggleProperties,
                    ),
                    _QuickUtilityButton(
                      icon: Icons.layers_outlined,
                      tooltip: 'Layers panel',
                      selected: layersSelected,
                      onPressed: onToggleLayers,
                    ),
                    _QuickUtilityButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete selection',
                      selected: false,
                      onPressed: onDeleteSelection,
                    ),
                    if (actions.length > 2) ...[
                      const SizedBox(height: 34, child: VerticalDivider()),
                      IconButton(
                        tooltip: 'Reset quick toolbar',
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 34,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: onReset,
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionPicker extends StatelessWidget {
  const _ActionPicker({
    required this.groupLabel,
    required this.displayedAction,
    required this.actions,
    required this.selectedTool,
    required this.selectedPreset,
    required this.selectedMarker,
    required this.onSelected,
  });

  final String groupLabel;
  final CanvasToolbarAction displayedAction;
  final List<CanvasToolbarAction> actions;
  final CanvasTool selectedTool;
  final GraphDrawingPreset? selectedPreset;
  final GraphMarkerType selectedMarker;
  final ValueChanged<CanvasToolbarAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = displayedAction.isSelected(
      selectedTool: selectedTool,
      selectedPreset: selectedPreset,
      selectedMarker: selectedMarker,
    );
    final picker = SizedBox(
      width: 56,
      height: 62,
      child: PopupMenuButton<CanvasToolbarAction>(
        tooltip: '$groupLabel: ${displayedAction.tooltip}',
        onSelected: onSelected,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 340),
        itemBuilder: (context) => [
          for (final action in actions)
            PopupMenuItem(
              value: action,
              child: Row(
                children: [
                  Icon(action.icon, color: action.color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(action.label)),
                  if (action.isSelected(
                    selectedTool: selectedTool,
                    selectedPreset: selectedPreset,
                    selectedMarker: selectedMarker,
                  ))
                    const Icon(Icons.check, size: 20),
                ],
              ),
            ),
        ],
        child: _PickerFace(
          icon: displayedAction.icon,
          label: groupLabel,
          color: displayedAction.color,
          active: selected,
        ),
      ),
    );
    return _DraggableAction(action: displayedAction, child: picker);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.selectedTool,
    required this.selectedPreset,
    required this.selectedMarker,
    required this.onPressed,
    this.onDoubleTap,
  });

  final CanvasToolbarAction action;
  final CanvasTool selectedTool;
  final GraphDrawingPreset? selectedPreset;
  final GraphMarkerType selectedMarker;
  final ValueChanged<CanvasToolbarAction> onPressed;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final child = _ActionFace(
      action: action,
      selected: action.isSelected(
        selectedTool: selectedTool,
        selectedPreset: selectedPreset,
        selectedMarker: selectedMarker,
      ),
      onPressed: () => onPressed(action),
      onDoubleTap: onDoubleTap,
    );
    return _DraggableAction(action: action, child: child);
  }
}

class _DraggableAction extends StatelessWidget {
  const _DraggableAction({
    required this.action,
    required this.child,
  });

  final CanvasToolbarAction action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Draggable<CanvasToolbarAction>(
      data: action,
      feedback: Material(
        color: Colors.transparent,
        child: _DragFeedback(action: action),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }
}

class _QuickUtilityButton extends StatelessWidget {
  const _QuickUtilityButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          constraints: const BoxConstraints.tightFor(width: 38, height: 34),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: selected ? const Color(0xFFCC2000) : Colors.black87,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
        ),
      );
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.action});
  final CanvasToolbarAction action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCC2000), width: 2),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, color: action.color),
            const SizedBox(width: 8),
            Text(action.label),
          ],
        ),
      );
}

class _ActionFace extends StatelessWidget {
  const _ActionFace({
    required this.action,
    required this.selected,
    required this.onPressed,
    this.onDoubleTap,
  });

  final CanvasToolbarAction action;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        height: 62,
        child: Tooltip(
          message: '${action.tooltip}\nHold and drag to customize quick tools',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            onDoubleTap: onDoubleTap,
            child: _PickerFace(
              icon: action.icon,
              label: action.shortLabel,
              color: action.color,
              active: selected,
            ),
          ),
        ),
      );
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.action,
    required this.compact,
    required this.selected,
    required this.onPressed,
  });

  final CanvasToolbarAction action;
  final bool compact;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: action.tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: BoxConstraints(minWidth: compact ? 36 : 58),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFCC2000) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  size: 20,
                  color: selected ? Colors.white : action.color,
                ),
                if (!compact) ...[
                  const SizedBox(width: 5),
                  Text(
                    action.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
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
    final action = CanvasToolbarAction.marker(displayedMarker);
    final picker = SizedBox(
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
          active: active && displayedMarker == selectedMarker,
        ),
      ),
    );
    return _DraggableAction(action: action, child: picker);
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
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : Colors.white,
          border: Border.all(
            color: active ? color : const Color(0xFFD8D8D8),
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PlainToolButton extends StatelessWidget {
  const _PlainToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        height: 58,
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: _PickerFace(
              icon: icon,
              label: label,
              color: const Color(0xFFCC2000),
              active: selected,
            ),
          ),
        ),
      );
}

class _ToolbarHeader extends StatelessWidget {
  const _ToolbarHeader({required this.label, required this.onCollapse});

  final String label;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          IconButton(
            tooltip: 'Hide main toolbar',
            visualDensity: VisualDensity.compact,
            onPressed: onCollapse,
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          _ToolbarGroupLabel(label: label),
        ],
      );
}

class _ToolbarGroupLabel extends StatelessWidget {
  const _ToolbarGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF6D6E71),
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
        ),
      );
}

IconData iconForDrawingPreset(GraphDrawingPreset preset) => switch (preset) {
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
      GraphDrawingPreset.driveway => Icons.drive_eta_outlined,
      GraphDrawingPreset.walkway => Icons.directions_walk_outlined,
      GraphDrawingPreset.propertyLine => Icons.border_style,
      GraphDrawingPreset.fenceLine => Icons.fence,
      GraphDrawingPreset.measurementLine => Icons.straighten,
      GraphDrawingPreset.treatmentArea => Icons.select_all_outlined,
    };
