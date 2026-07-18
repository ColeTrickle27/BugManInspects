import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editor_interaction_controller.dart';
import '../models/graph_annotation.dart';
import '../models/graph_document.dart';
import '../models/freehand_stroke.dart';
import '../models/graph_point.dart';
import '../models/graph_shape.dart';
import '../models/job.dart';
import '../models/wall_segment.dart';
import '../widgets/canvas_toolbar.dart';
import '../widgets/freehand_strokes_painter.dart';
import '../widgets/graph_annotations_painter.dart';
import '../widgets/graph_grid_painter.dart';
import '../widgets/graph_shapes_painter.dart';
import '../widgets/wall_segments_painter.dart';

class GraphCanvasScreen extends StatefulWidget {
  const GraphCanvasScreen({
    required this.job,
    super.key,
  });

  static const String routeName = '/graph-canvas';

  final Job job;

  @override
  State<GraphCanvasScreen> createState() => _GraphCanvasScreenState();
}

class _GraphCanvasScreenState extends State<GraphCanvasScreen> {
  static const Size _canvasSize = Size(3600, 2600);
  static const double _endpointSnapDistance = 22;
  static const double _gridSnapSize = 12;
  static const double _minimumWallLength = 6;
  static const double _tapMovementLimit = 10;
  static const Duration _doubleClickWindow = Duration(milliseconds: 360);
  static const double _angleSnapToleranceRadians = math.pi / 18;
  static const double _dragHitDistance = 34;

  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'Graph editor');
  final TransformationController _transformationController =
      TransformationController();
  late final GraphDocument _document;
  late final EditorInteractionController _interaction;
  final List<_UndoEntry> _undoStack = <_UndoEntry>[];
  final List<_RedoEntry> _redoStack = <_RedoEntry>[];
  bool _applyingHistory = false;
  GraphPoint? _activeWallStart;
  GraphPoint? _activePathStartPoint;
  GraphPoint? _pendingCurveControlPoint;
  WallSegment? _previewSegment;
  int? _activePathStartSegmentIndex;
  _EditorSnapshot? _structureStartSnapshot;
  String _canvasStatus = 'Select selected: click an object';
  _Selection? _selection;
  bool _gridVisible = true;
  bool _snapToGrid = true;
  bool _snapToObjects = true;
  bool _propertiesCollapsed = false;
  bool _layersCollapsed = false;
  String _scaleLabel = '1:1';
  Offset? _pointerDownPosition;
  _Selection? _pointerDownHitSelection;
  _Selection? _hoverSelection;
  double _pointerTravel = 0;
  int _activePointerCount = 0;
  GraphPoint? _pointerDownActiveWallStart;
  GraphPoint? _pointerDownActivePathStartPoint;
  int? _pointerDownActivePathStartSegmentIndex;
  DateTime? _lastTapTime;
  Offset? _lastTapSceneOffset;
  _DragTarget? _activeDragTarget;
  List<WallSegment>? _dragOriginalWallSegments;
  List<GraphAnnotation>? _dragOriginalAnnotations;
  List<GraphShape>? _dragOriginalShapes;
  List<FreehandStroke>? _dragOriginalFreehandStrokes;
  GraphPoint? _dragOriginalActiveWallStart;
  GraphPoint? _dragOriginalActivePathStartPoint;
  int? _dragOriginalActivePathStartSegmentIndex;
  bool _dragMoved = false;
  Offset? _shapeDrawStart;
  Offset? _shapeDrawCurrent;
  List<GraphPoint> _draftFreehandPoints = <GraphPoint>[];
  _ClipboardItem? _clipboardItem;
  bool _draggingLineTool = false;
  bool _lineDragStartedNewPath = false;
  Color _selectedMarkerColor = GraphMarkerType.activeTermites.defaultColor;
  double _selectedMarkerSize = 1;
  final Map<GraphDrawingPreset, _DrawingStyleDefaults> _drawingPresetDefaults =
      {
    for (final preset in GraphDrawingPreset.values)
      preset: _DrawingStyleDefaults.fromPreset(preset),
  };
  final Map<GraphMarkerType, _MarkerStyleDefaults> _markerDefaults = {
    for (final markerType in GraphMarkerType.values)
      markerType: _MarkerStyleDefaults.fromMarkerType(markerType),
  };
  Color? _defaultShapeFillColor = _ShapeFillChoice.lime.color;
  double _defaultShapeFillOpacity = _ShapeFillChoice.lime.opacity;
  Color _defaultShapeBorderColor = _ShapeBorderChoice.darkGreen.color;
  double _defaultShapeBorderWidth = 3;
  GraphShapePattern _defaultShapePattern = GraphShapePattern.none;
  Color _defaultLineColor = const Color(0xFF214D38);
  double _defaultLineWidth = 5;
  LinePattern _defaultLinePattern = LinePattern.solid;
  Color _defaultArrowColor = const Color(0xFF214D38);
  double _defaultArrowWidth = 5;
  LinePattern _defaultArrowPattern = LinePattern.solid;
  double _defaultTextFontSize = 16;
  Color _defaultTextColor = const Color(0xFF1C2B22);
  Color _defaultTextBackground = const Color(0xFFFFF2B8);
  Color _defaultTextBorder = const Color(0xFFC7A93C);
  Color _defaultFreehandColor = const Color(0xFF214D38);
  double _defaultFreehandWidth = 4;
  double _defaultFreehandOpacity = 0.95;
  CanvasTool get _selectedTool => _interaction.primaryTool;
  GraphMarkerType get _selectedMarkerType => _interaction.markerType;
  GraphDrawingPreset get _selectedStructureType => _interaction.structureType;
  GraphDrawingPreset? get _selectedDrawingPreset =>
      _selectedTool == CanvasTool.structure ? _selectedStructureType : null;
  List<WallSegment> get _wallSegments => _document.wallSegments;
  set _wallSegments(List<WallSegment> value) =>
      _document.replaceWallSegments(value);

  List<GraphAnnotation> get _annotations => _document.annotations;
  set _annotations(List<GraphAnnotation> value) =>
      _document.replaceAnnotations(value);

  List<GraphShape> get _shapes => _document.shapes;
  set _shapes(List<GraphShape> value) => _document.replaceShapes(value);

  List<FreehandStroke> get _freehandStrokes => _document.freehandStrokes;
  set _freehandStrokes(List<FreehandStroke> value) =>
      _document.replaceFreehandStrokes(value);

  bool get _traceLayerVisible => _document.layer('trace').visible;

  Map<_GraphLayer, _LayerSettings> get _layerSettings => {
        for (final layer in _GraphLayer.values)
          layer: _LayerSettings(
            visible: _document.layer(layer.name).visible,
            locked: _document.layer(layer.name).locked,
          ),
      };

  @override
  void initState() {
    super.initState();
    _document = GraphDocument.forJob(widget.job);
    _interaction = EditorInteractionController();
    _document.addListener(_handleDocumentChanged);
  }

  void _handleDocumentChanged() {
    if (!_applyingHistory && _document.isDirty && _redoStack.isNotEmpty) {
      _redoStack.clear();
    }
  }

  @override
  void dispose() {
    _document.removeListener(_handleDocumentChanged);
    _document.dispose();
    _interaction.dispose();
    _editorFocusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _selectTool(CanvasTool tool) {
    if (_selectedTool == CanvasTool.structure &&
        _interaction.drawingSession == EditorDrawingSession.plottingStructure) {
      _cancelActiveStructure();
    }
    setState(() {
      _interaction.selectTool(tool);
      _canvasStatus = _toolStatus(tool);
      _previewSegment = null;
    });
    _editorFocusNode.requestFocus();
  }

  void _selectMarker(GraphMarkerType markerType) {
    final markerDefault = _markerDefaultsFor(markerType);
    setState(() {
      _interaction.selectMarker(markerType);
      _selectedMarkerColor = markerDefault.color;
      _selectedMarkerSize = markerDefault.size;
      _canvasStatus = '${markerType.label}: tap to place';
      _previewSegment = null;
    });
    _editorFocusNode.requestFocus();
  }

  void _selectDrawingPreset(GraphDrawingPreset preset) {
    if (_selectedTool == CanvasTool.structure &&
        _interaction.drawingSession == EditorDrawingSession.plottingStructure) {
      _cancelActiveStructure();
    }
    setState(() {
      _interaction.selectStructure(preset);
      _activeWallStart = null;
      _activePathStartPoint = null;
      _activePathStartSegmentIndex = null;
      _pendingCurveControlPoint = null;
      _previewSegment = null;
      _canvasStatus = '${preset.label}: click each corner, then Finish';
    });
    _editorFocusNode.requestFocus();
  }

  _MarkerStyleDefaults _markerDefaultsFor(GraphMarkerType markerType) {
    return _markerDefaults[markerType] ??
        _MarkerStyleDefaults.fromMarkerType(markerType);
  }

  _DrawingStyleDefaults _drawingDefaultsFor(GraphDrawingPreset preset) {
    return _drawingPresetDefaults[preset] ??
        _DrawingStyleDefaults.fromPreset(preset);
  }

  _DrawingStyleDefaults? get _selectedDrawingDefaults {
    final preset = _selectedDrawingPreset;
    return preset == null ? null : _drawingDefaultsFor(preset);
  }

  Color get _currentLineColor =>
      _selectedDrawingDefaults?.lineColor ??
      (_selectedTool == CanvasTool.arrow
          ? _defaultArrowColor
          : _defaultLineColor);

  double get _currentLineWidth =>
      _selectedDrawingDefaults?.lineWidth ??
      (_selectedTool == CanvasTool.arrow
          ? _defaultArrowWidth
          : _defaultLineWidth);

  LinePattern get _currentLinePattern =>
      _selectedDrawingDefaults?.linePattern ??
      (_selectedTool == CanvasTool.arrow
          ? _defaultArrowPattern
          : _defaultLinePattern);

  Color? get _currentShapeFillColor =>
      _selectedDrawingDefaults?.fillColor ?? _defaultShapeFillColor;

  double get _currentShapeFillOpacity =>
      _selectedDrawingDefaults?.fillOpacity ?? _defaultShapeFillOpacity;

  Color get _currentShapeBorderColor =>
      _selectedDrawingDefaults?.borderColor ?? _defaultShapeBorderColor;

  double get _currentShapeBorderWidth =>
      _selectedDrawingDefaults?.borderWidth ?? _defaultShapeBorderWidth;

  GraphShapePattern get _currentShapePattern =>
      _selectedDrawingDefaults?.pattern ?? _defaultShapePattern;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    if (isControlPressed && key == LogicalKeyboardKey.keyZ) {
      if (!HardwareKeyboard.instance.isShiftPressed &&
          _selectedTool == CanvasTool.structure &&
          _interaction.drawingSession ==
              EditorDrawingSession.plottingStructure) {
        _removeLastStructurePoint();
        return KeyEventResult.handled;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        _redoLastAction();
      } else {
        _undoLastAction();
      }
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyY) {
      _redoLastAction();
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyD) {
      _duplicateSelection();
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyC) {
      _copySelection();
      return KeyEventResult.handled;
    }

    if (isControlPressed && key == LogicalKeyboardKey.keyV) {
      _pasteClipboard();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _deleteSelection();
      return KeyEventResult.handled;
    }

    if (isControlPressed) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.enter &&
        _selectedTool == CanvasTool.structure) {
      _finishStructurePath();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      _cancelActiveDrawing();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      _selectTool(CanvasTool.select);
    } else if (key == LogicalKeyboardKey.keyH) {
      _selectTool(CanvasTool.pan);
    } else if (key == LogicalKeyboardKey.keyB) {
      _selectDrawingPreset(_selectedStructureType);
    } else if (key == LogicalKeyboardKey.keyR) {
      _selectTool(CanvasTool.rectangle);
    } else if (key == LogicalKeyboardKey.keyS) {
      _selectTool(CanvasTool.square);
    } else if (key == LogicalKeyboardKey.keyC) {
      _selectTool(CanvasTool.circle);
    } else if (key == LogicalKeyboardKey.keyE) {
      _selectTool(CanvasTool.ellipse);
    } else if (key == LogicalKeyboardKey.keyG) {
      _selectTool(CanvasTool.triangle);
    } else if (key == LogicalKeyboardKey.keyL) {
      _selectTool(CanvasTool.wall);
    } else if (key == LogicalKeyboardKey.keyA) {
      _selectTool(CanvasTool.arrow);
    } else if (key == LogicalKeyboardKey.keyF) {
      _selectTool(CanvasTool.freehand);
    } else if (key == LogicalKeyboardKey.keyM) {
      _selectTool(CanvasTool.marker);
    } else if (key == LogicalKeyboardKey.keyT) {
      _selectTool(CanvasTool.text);
    } else if (key == LogicalKeyboardKey.keyP) {
      _selectTool(CanvasTool.photo);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _cancelActiveDrawing() {
    if (_selectedTool == CanvasTool.structure &&
        _interaction.drawingSession == EditorDrawingSession.plottingStructure) {
      _cancelActiveStructure();
      return;
    }

    setState(() {
      _shapeDrawStart = null;
      _shapeDrawCurrent = null;
      _draftFreehandPoints = <GraphPoint>[];
      _activeWallStart = null;
      _activePathStartPoint = null;
      _activePathStartSegmentIndex = null;
      _pendingCurveControlPoint = null;
      _previewSegment = null;
      _interaction.setDrawingSession(EditorDrawingSession.idle);
      _canvasStatus = 'Drawing cancelled';
    });
  }

  String _toolStatus(CanvasTool tool) {
    switch (tool) {
      case CanvasTool.select:
        return 'Select selected: click or drag objects';
      case CanvasTool.pan:
        return 'Pan selected: drag the canvas';
      case CanvasTool.structure:
        return _activeWallStart == null
            ? '${_selectedStructureType.label}: click the first corner'
            : '${_selectedStructureType.label}: click the next corner';
      case CanvasTool.rectangle:
        return 'Rectangle selected: tap or drag on the graph';
      case CanvasTool.square:
        return 'Square selected: tap or drag on the graph';
      case CanvasTool.circle:
        return 'Circle selected: tap or drag on the graph';
      case CanvasTool.ellipse:
        return 'Ellipse selected: tap or drag on the graph';
      case CanvasTool.triangle:
        return 'Triangle selected: tap or drag on the graph';
      case CanvasTool.wall:
        return _activeWallStart == null
            ? 'Line selected: tap a start point'
            : 'Line selected: tap the next point';
      case CanvasTool.arrow:
        return _activeWallStart == null
            ? 'Arrow selected: tap a start point'
            : 'Arrow selected: tap the arrow end';
      case CanvasTool.curve:
        return _activeWallStart == null
            ? 'Curve selected: tap a start point'
            : _pendingCurveControlPoint == null
                ? 'Curve selected: tap the bend point'
                : 'Curve selected: tap the curve end';
      case CanvasTool.freehand:
        return 'Freehand selected: drag to sketch';
      case CanvasTool.marker:
        return 'Marker selected: tap the graph';
      case CanvasTool.photo:
        return 'Photo selected: tap the graph';
      case CanvasTool.text:
        return 'Text selected: tap the graph';
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _editorFocusNode.requestFocus();
    if (event.buttons == kSecondaryMouseButton) {
      final sceneOffset =
          _transformationController.toScene(event.localPosition);
      _showContextMenu(event.position, sceneOffset);
      return;
    }

    _activePointerCount += 1;

    if (_activePointerCount == 1) {
      _pointerDownPosition = event.localPosition;
      _pointerTravel = 0;
      _pointerDownActiveWallStart = _activeWallStart;
      _pointerDownActivePathStartPoint = _activePathStartPoint;
      _pointerDownActivePathStartSegmentIndex = _activePathStartSegmentIndex;
      final sceneOffset =
          _transformationController.toScene(event.localPosition);
      _interaction.pointerDown(sceneOffset);
      _pointerDownHitSelection =
          _selectionAt(GraphPoint.fromOffset(sceneOffset));

      final hitSelection = _pointerDownHitSelection;
      if (hitSelection != null) {
        setState(() {
          _selection = hitSelection;
          _interaction.setSelected(_interactionReference(hitSelection));
          _canvasStatus = _selectionStatus(hitSelection);
        });
        if (_isSelectionEditable(hitSelection)) {
          _startDragForSelection(
              hitSelection, GraphPoint.fromOffset(sceneOffset));
        }
        return;
      }

      if (_isPresetShapeTool(_selectedTool)) {
        _shapeDrawStart = sceneOffset;
        _shapeDrawCurrent = sceneOffset;
      } else if (_selectedTool == CanvasTool.freehand) {
        _startFreehandStroke(sceneOffset);
      } else if (_selectedTool == CanvasTool.wall ||
          _selectedTool == CanvasTool.arrow) {
        _startLineDrag(sceneOffset);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _pointerDownPosition;
    if (start == null) {
      return;
    }

    final distance = (event.localPosition - start).distance;
    if (distance > _pointerTravel) {
      _pointerTravel = distance;
    }

    if (_activeDragTarget != null) {
      if (_pointerTravel <= _tapMovementLimit) {
        return;
      }
      _interaction.beginDrag();
      final sceneOffset =
          _transformationController.toScene(event.localPosition);
      if (_isInsideCanvas(sceneOffset)) {
        _moveActiveTarget(GraphPoint.fromOffset(sceneOffset));
      }
    } else if (_isPresetShapeTool(_selectedTool) &&
        _shapeDrawStart != null &&
        _pointerTravel > _tapMovementLimit) {
      final sceneOffset =
          _transformationController.toScene(event.localPosition);
      if (_isInsideCanvas(sceneOffset)) {
        setState(() {
          _shapeDrawCurrent = sceneOffset;
        });
      }
    } else if (_selectedTool == CanvasTool.freehand &&
        _draftFreehandPoints.isNotEmpty) {
      final sceneOffset =
          _transformationController.toScene(event.localPosition);
      if (_isInsideCanvas(sceneOffset)) {
        _appendFreehandPoint(sceneOffset);
      }
    } else {
      final sceneOffset =
          _transformationController.toScene(event.localPosition);
      if (_isInsideCanvas(sceneOffset)) {
        _updatePreviewSegment(sceneOffset);
      }
    }
  }

  void _handlePointerHover(PointerHoverEvent event) {
    final sceneOffset = _transformationController.toScene(event.localPosition);
    if (_isInsideCanvas(sceneOffset)) {
      final nextHover = _selectionAt(GraphPoint.fromOffset(sceneOffset));
      if (nextHover != _hoverSelection) {
        setState(() {
          _hoverSelection = nextHover;
          _interaction.setHovered(
            nextHover == null ? null : _interactionReference(nextHover),
          );
        });
      }
      if (nextHover != null) {
        if (_previewSegment != null) {
          setState(() => _previewSegment = null);
        }
        return;
      }
      _updatePreviewSegment(sceneOffset);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final start = _pointerDownPosition;
    final wasSinglePointerTap = _activePointerCount == 1 &&
        start != null &&
        _pointerTravel <= _tapMovementLimit &&
        (event.localPosition - start).distance <= _tapMovementLimit;

    if (_activePointerCount > 0) {
      _activePointerCount -= 1;
    }

    final sceneOffset = _transformationController.toScene(event.localPosition);

    if (_pointerDownHitSelection != null) {
      if (wasSinglePointerTap &&
          _isDoubleClickNearLastTap(sceneOffset) &&
          _editSelectedObjectText()) {
        _resetPointerGesture();
        _rememberTap(sceneOffset);
        return;
      }
      if (_dragMoved) {
        _finishActiveDrag();
      }
      _cancelDrawingGestureForSelection();
      _resetPointerGesture();
      _rememberTap(sceneOffset);
      return;
    }

    if (_isPresetShapeTool(_selectedTool) && _shapeDrawStart != null) {
      if (_isInsideCanvas(sceneOffset) && !wasSinglePointerTap) {
        _finishPresetShape(sceneOffset);
      }
      _shapeDrawStart = null;
      _shapeDrawCurrent = null;
      _pointerDownPosition = null;
      _pointerTravel = 0;
      _rememberTap(sceneOffset);
      return;
    }

    if (_selectedTool == CanvasTool.freehand &&
        _draftFreehandPoints.isNotEmpty) {
      _finishFreehandStroke();
      _pointerDownPosition = null;
      _pointerTravel = 0;
      _rememberTap(sceneOffset);
      return;
    }

    if (_draggingLineTool &&
        (_selectedTool == CanvasTool.wall ||
            _selectedTool == CanvasTool.arrow)) {
      if (_isInsideCanvas(sceneOffset) && _pointerTravel > _tapMovementLimit) {
        _finishDraggedLine(sceneOffset);
        _pointerDownPosition = null;
        _pointerTravel = 0;
        _draggingLineTool = false;
        _lineDragStartedNewPath = false;
        _rememberTap(sceneOffset);
        return;
      }
      final shouldHandleTap = !_lineDragStartedNewPath;
      _draggingLineTool = false;
      _lineDragStartedNewPath = false;
      if (shouldHandleTap &&
          _isInsideCanvas(sceneOffset) &&
          _shouldFinishFromDoubleClick(sceneOffset)) {
        _finishWallPath(closeShapeDefault: true);
        _rememberTap(sceneOffset);
        return;
      }
      if (shouldHandleTap && _isInsideCanvas(sceneOffset)) {
        _handleCanvasTap(sceneOffset);
      }
      _rememberTap(sceneOffset);
      return;
    }

    if (wasSinglePointerTap) {
      if (_isInsideCanvas(sceneOffset)) {
        if (_selectedTool == CanvasTool.select &&
            _isDoubleClickNearLastTap(sceneOffset) &&
            _editTextAt(sceneOffset)) {
          _rememberTap(sceneOffset);
          return;
        }

        if (_shouldFinishFromDoubleClick(sceneOffset)) {
          _finishWallPath(closeShapeDefault: true);
          _rememberTap(sceneOffset);
          return;
        }

        _handleCanvasTap(sceneOffset);
        _rememberTap(sceneOffset);
      }
    }

    if (_activePointerCount == 0) {
      _resetPointerGesture();
    }
  }

  void _resetPointerGesture() {
    _pointerDownPosition = null;
    _pointerDownHitSelection = null;
    _pointerTravel = 0;
    _activeDragTarget = null;
    _dragOriginalWallSegments = null;
    _dragOriginalAnnotations = null;
    _dragOriginalShapes = null;
    _dragOriginalFreehandStrokes = null;
    _dragOriginalActiveWallStart = null;
    _dragOriginalActivePathStartPoint = null;
    _dragOriginalActivePathStartSegmentIndex = null;
    _dragMoved = false;
    _interaction.pointerUp();
  }

  void _rememberTap(Offset sceneOffset) {
    _lastTapTime = DateTime.now();
    _lastTapSceneOffset = sceneOffset;
  }

  bool _shouldFinishFromDoubleClick(Offset sceneOffset) {
    if (_activeWallStart == null ||
        (_selectedTool != CanvasTool.structure &&
            _selectedTool != CanvasTool.wall &&
            _selectedTool != CanvasTool.arrow &&
            _selectedTool != CanvasTool.curve)) {
      return false;
    }

    return _isDoubleClickNearLastTap(sceneOffset);
  }

  bool _isDoubleClickNearLastTap(Offset sceneOffset) {
    final lastTapTime = _lastTapTime;
    final lastTapSceneOffset = _lastTapSceneOffset;
    if (lastTapTime == null || lastTapSceneOffset == null) {
      return false;
    }

    final withinTime =
        DateTime.now().difference(lastTapTime) <= _doubleClickWindow;
    final nearLastTap = (sceneOffset - lastTapSceneOffset).distance <= 18;

    return withinTime && nearLastTap;
  }

  bool _editTextAt(Offset sceneOffset) {
    final textIndex = _findTextAnnotationIndex(sceneOffset);
    if (textIndex == null) {
      return false;
    }

    if (_isLayerLocked(_GraphLayer.findings)) {
      _showCanvasMessage('Findings layer is locked');
      return true;
    }

    _editTextAnnotation(textIndex);
    return true;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointerCount > 0) {
      _activePointerCount -= 1;
    }

    if (_activePointerCount == 0) {
      _cancelDrawingGestureForSelection();
      _resetPointerGesture();
    }
  }

  void _cancelDrawingGestureForSelection() {
    setState(() {
      _shapeDrawStart = null;
      _shapeDrawCurrent = null;
      _draftFreehandPoints = <GraphPoint>[];
      _draggingLineTool = false;
      _lineDragStartedNewPath = false;
      _activeWallStart = _pointerDownActiveWallStart;
      _activePathStartPoint = _pointerDownActivePathStartPoint;
      _activePathStartSegmentIndex = _pointerDownActivePathStartSegmentIndex;
      _previewSegment = null;
    });
  }

  bool _isInsideCanvas(Offset sceneOffset) {
    return sceneOffset.dx >= 0 &&
        sceneOffset.dy >= 0 &&
        sceneOffset.dx <= _canvasSize.width &&
        sceneOffset.dy <= _canvasSize.height;
  }

  bool _isLayerVisible(_GraphLayer layer) {
    if (layer == _GraphLayer.trace) {
      return _traceLayerVisible;
    }

    return _layerSettings[layer]?.visible ?? true;
  }

  bool _isLayerLocked(_GraphLayer layer) {
    return _layerSettings[layer]?.locked ?? false;
  }

  bool _isAnnotationVisible(GraphAnnotation annotation) {
    return _isLayerVisible(_layerForAnnotation(annotation));
  }

  bool _isAnnotationLocked(GraphAnnotation annotation) {
    return _isLayerLocked(_layerForAnnotation(annotation));
  }

  _GraphLayer _layerForAnnotation(GraphAnnotation annotation) {
    return annotation.kind == GraphAnnotationKind.photo
        ? _GraphLayer.photos
        : _GraphLayer.findings;
  }

  _GraphLayer _layerForSelection(_Selection selection) {
    return switch (selection.kind) {
      _SelectionKind.annotation => _layerForAnnotation(
          _annotations[selection.index],
        ),
      _SelectionKind.segment => _GraphLayer.structure,
      _SelectionKind.shape => _GraphLayer.shapes,
      _SelectionKind.freehand => _GraphLayer.structure,
    };
  }

  bool _isSelectionEditable(_Selection selection) {
    if (selection.kind == _SelectionKind.annotation &&
        (selection.index < 0 || selection.index >= _annotations.length)) {
      return false;
    }

    if (selection.kind == _SelectionKind.shape) {
      return !_isLayerLocked(_GraphLayer.shapes) &&
          !_isLayerLocked(_GraphLayer.structure);
    }

    return !_isLayerLocked(_layerForSelection(selection));
  }

  void _updatePreviewSegment(Offset sceneOffset) {
    final activeStart = _activeWallStart;
    if (activeStart == null ||
        (_selectedTool != CanvasTool.structure &&
            _selectedTool != CanvasTool.wall &&
            _selectedTool != CanvasTool.arrow &&
            _selectedTool != CanvasTool.curve)) {
      if (_previewSegment != null) {
        setState(() {
          _previewSegment = null;
        });
      }
      return;
    }

    final rawPoint = GraphPoint.fromOffset(sceneOffset);
    final endpointSnap = _findNearbyEndpoint(rawPoint);
    final previewEnd = _selectedTool == CanvasTool.structure ||
            _selectedTool == CanvasTool.wall ||
            _selectedTool == CanvasTool.arrow
        ? endpointSnap ?? _snapWallPoint(rawPoint, activeStart)
        : endpointSnap ?? (_snapToGrid ? _snapPointToGrid(rawPoint) : rawPoint);
    final previewSegment =
        _selectedTool == CanvasTool.curve && _pendingCurveControlPoint != null
            ? WallSegment(
                start: activeStart,
                end: previewEnd,
                controlPoint: _pendingCurveControlPoint,
                color: _currentLineColor,
                strokeWidth: _currentLineWidth,
                pattern: _currentLinePattern,
              )
            : WallSegment(
                start: activeStart,
                end: previewEnd,
                color: _currentLineColor,
                strokeWidth: _currentLineWidth,
                pattern: _currentLinePattern,
                hasArrow: _selectedTool == CanvasTool.arrow,
              );

    setState(() {
      _previewSegment = previewSegment;
    });
  }

  void _handleCanvasTap(Offset sceneOffset) {
    if (_selectedTool == CanvasTool.select) {
      _selectObjectAt(sceneOffset);
      return;
    }

    if (_selectedTool == CanvasTool.pan) {
      _showCanvasMessage('Pan selected: drag to move around canvas');
      return;
    }

    if (_selectedTool == CanvasTool.structure) {
      _addStructurePoint(sceneOffset);
      return;
    }

    if (_selectedTool == CanvasTool.wall) {
      _addWallPoint(sceneOffset);
      return;
    }

    if (_selectedTool == CanvasTool.arrow) {
      _addArrowPoint(sceneOffset);
      return;
    }

    if (_selectedTool == CanvasTool.curve) {
      _addCurvePoint(sceneOffset);
      return;
    }

    if (_selectedTool == CanvasTool.text) {
      _handleTextTap(sceneOffset);
      return;
    }

    _addPlaceholderAnnotation(sceneOffset);
  }

  Future<void> _showContextMenu(
      Offset globalPosition, Offset sceneOffset) async {
    _selectObjectAt(sceneOffset);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selectedAction = await showMenu<_ContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _ContextAction.copy, child: Text('Copy')),
        PopupMenuItem(value: _ContextAction.paste, child: Text('Paste')),
        PopupMenuItem(
            value: _ContextAction.duplicate, child: Text('Duplicate')),
        PopupMenuItem(value: _ContextAction.delete, child: Text('Delete')),
        PopupMenuDivider(),
        PopupMenuItem(
            value: _ContextAction.bringForward, child: Text('Bring Forward')),
        PopupMenuItem(
            value: _ContextAction.sendBackward, child: Text('Send Backward')),
        PopupMenuItem(
            value: _ContextAction.bringToFront, child: Text('Bring to Front')),
        PopupMenuItem(
            value: _ContextAction.sendToBack, child: Text('Send to Back')),
        PopupMenuDivider(),
        PopupMenuItem(value: _ContextAction.lock, child: Text('Lock Layer')),
        PopupMenuItem(
            value: _ContextAction.unlock, child: Text('Unlock Layer')),
        PopupMenuItem(value: _ContextAction.group, child: Text('Group')),
        PopupMenuItem(value: _ContextAction.ungroup, child: Text('Ungroup')),
        PopupMenuItem(
            value: _ContextAction.properties, child: Text('Properties')),
      ],
    );

    if (selectedAction == null || !mounted) {
      return;
    }

    _runContextAction(selectedAction);
  }

  void _runContextAction(_ContextAction action) {
    switch (action) {
      case _ContextAction.copy:
        _copySelection();
        return;
      case _ContextAction.paste:
        _pasteClipboard();
        return;
      case _ContextAction.duplicate:
        _duplicateSelection();
        return;
      case _ContextAction.delete:
        _deleteSelection();
        return;
      case _ContextAction.bringForward:
        _reorderSelection(_ReorderDirection.forward);
        return;
      case _ContextAction.sendBackward:
        _reorderSelection(_ReorderDirection.backward);
        return;
      case _ContextAction.bringToFront:
        _reorderSelection(_ReorderDirection.front);
        return;
      case _ContextAction.sendToBack:
        _reorderSelection(_ReorderDirection.back);
        return;
      case _ContextAction.lock:
        _setSelectedLayerLocked(true);
        return;
      case _ContextAction.unlock:
        _setSelectedLayerLocked(false);
        return;
      case _ContextAction.group:
      case _ContextAction.ungroup:
        _showCanvasMessage(
            'Grouping will apply to multi-select in the next pass');
        return;
      case _ContextAction.properties:
        _showCanvasMessage('Properties shown in the right panel');
        return;
    }
  }

  bool _isPresetShapeTool(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.rectangle ||
      CanvasTool.square ||
      CanvasTool.circle ||
      CanvasTool.ellipse ||
      CanvasTool.triangle =>
        true,
      _ => false,
    };
  }

  void _finishPresetShape(Offset endOffset) {
    final start = _shapeDrawStart ?? endOffset;
    final distance = (endOffset - start).distance;
    if (distance <= _tapMovementLimit) {
      _showCanvasMessage('Drag to create a shape');
      return;
    }

    final rect = _rectFromDrag(
      start,
      endOffset,
      forceSquare: _selectedTool == CanvasTool.square ||
          _selectedTool == CanvasTool.circle,
    );

    _addPresetShape(rect);
  }

  Rect _rectFromDrag(
    Offset start,
    Offset end, {
    required bool forceSquare,
  }) {
    final normalized = Rect.fromPoints(start, end);
    if (!forceSquare) {
      return normalized;
    }

    final size = math.max(normalized.width, normalized.height);
    final dx = end.dx >= start.dx ? size : -size;
    final dy = end.dy >= start.dy ? size : -size;
    return Rect.fromPoints(start, Offset(start.dx + dx, start.dy + dy));
  }

  void _addPresetShape(Rect rawRect) {
    if (_isLayerLocked(_GraphLayer.structure) ||
        _isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Unlock Structure and Shapes to add shapes');
      return;
    }

    final rect = _normalizeMinimumRect(rawRect);
    final newSegments = _segmentsForPresetShapeTool(_selectedTool, rect);

    if (newSegments.isEmpty) {
      return;
    }

    final startIndex = _wallSegments.length;
    final shape = GraphShape(
      name: _defaultShapeName(_selectedTool),
      segmentIndexes: [
        for (var i = 0; i < newSegments.length; i += 1) startIndex + i,
      ],
      fillColor: _currentShapeFillColor,
      fillOpacity: _currentShapeFillOpacity,
      borderColor: _currentShapeBorderColor,
      borderWidth: _currentShapeBorderWidth,
      pattern: _currentShapePattern,
      closed: true,
      rotationDegrees: 0,
      preset: _selectedDrawingPreset,
    );

    setState(() {
      _wallSegments = <WallSegment>[..._wallSegments, ...newSegments];
      _shapes = <GraphShape>[..._shapes, shape];
      _selection = _Selection.shape(_shapes.length - 1);
      _undoStack.add(
        _UndoEntry(
          _UndoKind.shapeFinish,
          shapeIndex: _shapes.length - 1,
          addedSegmentCount: newSegments.length,
        ),
      );
      _canvasStatus = '${shape.name} added';
    });
  }

  Rect _normalizeMinimumRect(Rect rect) {
    final normalized = Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );

    return Rect.fromCenter(
      center: normalized.center,
      width: math.max(normalized.width, 48),
      height: math.max(normalized.height, 48),
    );
  }

  String _defaultShapeName(CanvasTool tool) {
    final preset = _selectedDrawingPreset;
    if (preset != null && preset.kind == GraphDrawingPresetKind.area) {
      final samePresetCount =
          _shapes.where((shape) => shape.preset == preset).length;
      return samePresetCount == 0
          ? preset.label
          : '${preset.label} ${samePresetCount + 1}';
    }

    return switch (tool) {
      CanvasTool.rectangle => 'Rectangle ${_shapes.length + 1}',
      CanvasTool.square => 'Square ${_shapes.length + 1}',
      CanvasTool.circle => 'Circle ${_shapes.length + 1}',
      CanvasTool.ellipse => 'Ellipse ${_shapes.length + 1}',
      CanvasTool.triangle => 'Triangle ${_shapes.length + 1}',
      _ => 'Shape ${_shapes.length + 1}',
    };
  }

  List<WallSegment> _segmentsForPresetShapeTool(CanvasTool tool, Rect rect) {
    return switch (tool) {
      CanvasTool.rectangle || CanvasTool.square => _rectangleSegments(rect),
      CanvasTool.circle || CanvasTool.ellipse => _ellipseSegments(rect),
      CanvasTool.triangle => _triangleSegments(rect),
      _ => <WallSegment>[],
    };
  }

  List<WallSegment> _rectangleSegments(Rect rect) {
    final topLeft = GraphPoint.fromOffset(rect.topLeft);
    final topRight = GraphPoint.fromOffset(rect.topRight);
    final bottomRight = GraphPoint.fromOffset(rect.bottomRight);
    final bottomLeft = GraphPoint.fromOffset(rect.bottomLeft);

    return [
      WallSegment(start: topLeft, end: topRight),
      WallSegment(start: topRight, end: bottomRight),
      WallSegment(start: bottomRight, end: bottomLeft),
      WallSegment(start: bottomLeft, end: topLeft),
    ];
  }

  List<WallSegment> _triangleSegments(Rect rect) {
    final top = GraphPoint.fromOffset(rect.topCenter);
    final bottomRight = GraphPoint.fromOffset(rect.bottomRight);
    final bottomLeft = GraphPoint.fromOffset(rect.bottomLeft);

    return [
      WallSegment(start: top, end: bottomRight),
      WallSegment(start: bottomRight, end: bottomLeft),
      WallSegment(start: bottomLeft, end: top),
    ];
  }

  List<WallSegment> _ellipseSegments(Rect rect) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    const segmentCount = 8;
    const startAngle = -math.pi / 2;
    const step = (math.pi * 2) / segmentCount;
    final controlScale = 1 / math.cos(step / 2);

    return [
      for (var i = 0; i < segmentCount; i += 1)
        WallSegment(
          start: GraphPoint(
            x: cx + (rx * math.cos(startAngle + (step * i))),
            y: cy + (ry * math.sin(startAngle + (step * i))),
          ),
          end: GraphPoint(
            x: cx + (rx * math.cos(startAngle + (step * (i + 1)))),
            y: cy + (ry * math.sin(startAngle + (step * (i + 1)))),
          ),
          controlPoint: GraphPoint(
            x: cx +
                (rx * controlScale * math.cos(startAngle + (step * (i + 0.5)))),
            y: cy +
                (ry * controlScale * math.sin(startAngle + (step * (i + 0.5)))),
          ),
        ),
    ];
  }

  bool _editSelectedObjectText() {
    final selection = _selection;
    if (selection == null) {
      return false;
    }
    if (selection.kind == _SelectionKind.shape) {
      final shape = _shapes[selection.index];
      if (shape.isStructure) {
        return false;
      }
      _editShapeText(selection.index);
      return true;
    }
    if (selection.kind == _SelectionKind.annotation &&
        _annotations[selection.index].kind == GraphAnnotationKind.text) {
      _editTextAnnotation(selection.index);
      return true;
    }
    return false;
  }

  void _addStructurePoint(Offset canvasOffset) {
    if (_isLayerLocked(_GraphLayer.structure) ||
        _isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Unlock Structure and Shapes to draw a structure');
      return;
    }

    final tappedPoint = GraphPoint.fromOffset(canvasOffset);
    final activeStart = _activeWallStart;
    final endpointSnap = _findNearbyEndpoint(tappedPoint);
    final nextPoint = endpointSnap ?? _snapWallPoint(tappedPoint, activeStart);

    if (activeStart == null) {
      setState(() {
        _structureStartSnapshot = _EditorSnapshot.capture(this);
        _activeWallStart = nextPoint;
        _activePathStartPoint = nextPoint;
        _activePathStartSegmentIndex = _wallSegments.length;
        _interaction.setDrawingSession(EditorDrawingSession.plottingStructure);
        _canvasStatus = '${_selectedStructureType.label}: first corner placed';
      });
      return;
    }

    if (activeStart.distanceTo(nextPoint) < _minimumWallLength) {
      _showCanvasMessage('Place the next corner farther away');
      return;
    }

    final segment = WallSegment(
      start: activeStart,
      end: nextPoint,
      color: _currentShapeBorderColor,
      strokeWidth: _currentShapeBorderWidth,
      pattern: _currentLinePattern,
    );

    setState(() {
      _wallSegments = <WallSegment>[..._wallSegments, segment];
      _activeWallStart = nextPoint;
      _canvasStatus =
          '${_selectedStructureType.label}: corner placed â€¢ Finish, Enter, or double-click';
    });
  }

  void _cancelActiveStructure() {
    final snapshot = _structureStartSnapshot;
    setState(() {
      if (snapshot != null) {
        _applyingHistory = true;
        snapshot.restore(this);
        _applyingHistory = false;
      } else {
        _activeWallStart = null;
        _activePathStartPoint = null;
        _activePathStartSegmentIndex = null;
        _previewSegment = null;
      }
      _structureStartSnapshot = null;
      _interaction.setDrawingSession(EditorDrawingSession.idle);
      _canvasStatus = 'Unfinished structure cancelled';
    });
  }

  void _removeLastStructurePoint() {
    final startIndex = _activePathStartSegmentIndex;
    if (startIndex == null) {
      return;
    }
    if (_wallSegments.length <= startIndex) {
      _cancelActiveStructure();
      return;
    }

    final removed = _wallSegments.last;
    setState(() {
      _wallSegments = _wallSegments.sublist(0, _wallSegments.length - 1);
      _activeWallStart = removed.start;
      _previewSegment = null;
      _canvasStatus = 'Last structure point removed';
    });
  }

  void _finishStructurePath() {
    final preset = _selectedStructureType;
    final startIndex = _activePathStartSegmentIndex;
    final pathStart = _activePathStartPoint;
    final pathEnd = _activeWallStart;
    final before = _structureStartSnapshot;
    if (startIndex == null ||
        pathStart == null ||
        pathEnd == null ||
        before == null) {
      _showCanvasMessage('Place the first structure point before finishing');
      return;
    }

    final segmentCount = _wallSegments.length - startIndex;
    final isArea = preset.kind == GraphDrawingPresetKind.area;
    if (segmentCount < (isArea ? 2 : 1)) {
      _showCanvasMessage(
        isArea
            ? 'A structure needs at least three plotted corners'
            : 'Plot at least two points before finishing',
      );
      return;
    }

    setState(() {
      final segmentIndexes = <int>[
        for (var i = startIndex; i < _wallSegments.length; i += 1) i,
      ];
      if (isArea && pathEnd.distanceTo(pathStart) > _minimumWallLength) {
        segmentIndexes.add(_wallSegments.length);
        _wallSegments = <WallSegment>[
          ..._wallSegments,
          WallSegment(
            start: pathEnd,
            end: pathStart,
            color: _currentShapeBorderColor,
            strokeWidth: _currentShapeBorderWidth,
            pattern: _currentLinePattern,
          ),
        ];
      }

      final defaults = _drawingDefaultsFor(preset);
      final shape = GraphShape(
        name: preset.label,
        segmentIndexes: segmentIndexes,
        fillColor: isArea ? defaults.fillColor : null,
        fillOpacity: isArea ? defaults.fillOpacity : 0,
        borderColor: defaults.borderColor,
        borderWidth: defaults.borderWidth,
        pattern: isArea ? defaults.pattern : GraphShapePattern.none,
        closed: isArea,
        rotationDegrees: 0,
        preset: preset,
      );
      _shapes = <GraphShape>[..._shapes, shape];
      _selection = _Selection.shape(_shapes.length - 1);
      _interaction.setSelected(_interactionReference(_selection!));
      _undoStack.add(
        _UndoEntry(_UndoKind.snapshot, previousSnapshot: before),
      );
      _activeWallStart = null;
      _activePathStartPoint = null;
      _activePathStartSegmentIndex = null;
      _previewSegment = null;
      _structureStartSnapshot = null;
      _interaction.setDrawingSession(EditorDrawingSession.idle);
      _canvasStatus = '${preset.label} finished';
    });
  }

  void _addWallPoint(Offset canvasOffset) {
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    final tappedPoint = GraphPoint.fromOffset(canvasOffset);
    final activeStart = _activeWallStart;
    final endpointSnap = _findNearbyEndpoint(tappedPoint);
    final nextPoint = endpointSnap ?? _snapWallPoint(tappedPoint, activeStart);

    if (activeStart == null) {
      setState(() {
        _activeWallStart = nextPoint;
        _activePathStartPoint = nextPoint;
        _activePathStartSegmentIndex = _wallSegments.length;
        _undoStack.add(const _UndoEntry(_UndoKind.wallStart));
        _canvasStatus = endpointSnap == null
            ? 'Wall start set on grid'
            : 'Wall start snapped to endpoint';
      });
      return;
    }

    if (activeStart.distanceTo(nextPoint) < _minimumWallLength) {
      _showCanvasMessage('Tap farther away to create a wall');
      return;
    }

    final segment = WallSegment(
      start: activeStart,
      end: nextPoint,
      color: _currentLineColor,
      strokeWidth: _currentLineWidth,
      pattern: _currentLinePattern,
    );

    setState(() {
      _wallSegments = <WallSegment>[..._wallSegments, segment];
      _activeWallStart = nextPoint;
      _undoStack.add(const _UndoEntry(_UndoKind.wallSegment));
      _canvasStatus = endpointSnap == null
          ? 'Wall added with angle snap: ${segment.measurementLabel}'
          : 'Wall added and snapped: ${segment.measurementLabel}';
    });
  }

  void _startLineDrag(Offset sceneOffset) {
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    final point = GraphPoint.fromOffset(sceneOffset);
    final startPoint =
        _findNearbyEndpoint(point) ?? _snapWallPoint(point, null);

    setState(() {
      _draggingLineTool = true;
      _lineDragStartedNewPath = _activeWallStart == null;
      _activeWallStart ??= startPoint;
      _activePathStartPoint ??= _activeWallStart;
      _activePathStartSegmentIndex ??= _wallSegments.length;
      _canvasStatus =
          '${_selectedTool == CanvasTool.arrow ? 'Arrow' : 'Line'} preview';
    });
  }

  void _finishDraggedLine(Offset sceneOffset) {
    final activeStart = _activeWallStart;
    if (activeStart == null) {
      return;
    }

    final rawPoint = GraphPoint.fromOffset(sceneOffset);
    final endpointSnap = _findNearbyEndpoint(rawPoint);
    final nextPoint = endpointSnap ?? _snapWallPoint(rawPoint, activeStart);

    if (activeStart.distanceTo(nextPoint) < _minimumWallLength) {
      _showCanvasMessage('Drag farther to create a line');
      return;
    }

    final isArrow = _selectedTool == CanvasTool.arrow;
    final segment = WallSegment(
      start: activeStart,
      end: nextPoint,
      color: _currentLineColor,
      strokeWidth: _currentLineWidth,
      pattern: _currentLinePattern,
      hasArrow: isArrow,
    );

    setState(() {
      _wallSegments = <WallSegment>[..._wallSegments, segment];
      _previewSegment = null;
      _pendingCurveControlPoint = null;
      _activeWallStart = isArrow ? null : nextPoint;
      _activePathStartPoint = isArrow ? null : _activePathStartPoint;
      _activePathStartSegmentIndex =
          isArrow ? null : _activePathStartSegmentIndex;
      _undoStack.add(const _UndoEntry(_UndoKind.wallSegment));
      _canvasStatus =
          '${isArrow ? 'Arrow' : 'Line'} added: ${segment.measurementLabel}';
    });
  }

  void _addArrowPoint(Offset canvasOffset) {
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    final tappedPoint = GraphPoint.fromOffset(canvasOffset);
    final activeStart = _activeWallStart;
    final endpointSnap = _findNearbyEndpoint(tappedPoint);
    final nextPoint = endpointSnap ?? _snapWallPoint(tappedPoint, activeStart);

    if (activeStart == null) {
      setState(() {
        _activeWallStart = nextPoint;
        _activePathStartPoint = nextPoint;
        _activePathStartSegmentIndex = _wallSegments.length;
        _undoStack.add(const _UndoEntry(_UndoKind.wallStart));
        _canvasStatus = 'Arrow start set';
      });
      return;
    }

    if (activeStart.distanceTo(nextPoint) < _minimumWallLength) {
      _showCanvasMessage('Tap farther away to create an arrow');
      return;
    }

    final segment = WallSegment(
      start: activeStart,
      end: nextPoint,
      hasArrow: true,
      color: _currentLineColor,
      strokeWidth: _currentLineWidth,
      pattern: _currentLinePattern,
    );

    setState(() {
      _wallSegments = <WallSegment>[..._wallSegments, segment];
      _activeWallStart = null;
      _activePathStartPoint = null;
      _activePathStartSegmentIndex = null;
      _undoStack.add(const _UndoEntry(_UndoKind.wallSegment));
      _canvasStatus = 'Arrow added: ${segment.measurementLabel}';
    });
  }

  void _addCurvePoint(Offset canvasOffset) {
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    final tappedPoint = GraphPoint.fromOffset(canvasOffset);
    final activeStart = _activeWallStart;
    final endpointSnap = _findNearbyEndpoint(tappedPoint);
    final nextPoint = endpointSnap ??
        (_snapToGrid ? _snapPointToGrid(tappedPoint) : tappedPoint);

    if (activeStart == null) {
      setState(() {
        _activeWallStart = nextPoint;
        _activePathStartPoint = nextPoint;
        _activePathStartSegmentIndex = _wallSegments.length;
        _pendingCurveControlPoint = null;
        _undoStack.add(const _UndoEntry(_UndoKind.wallStart));
        _canvasStatus = endpointSnap == null
            ? 'Curve start set'
            : 'Curve start snapped to endpoint';
      });
      return;
    }

    if (_pendingCurveControlPoint == null) {
      final controlPoint =
          _snapToGrid ? _snapPointToGrid(tappedPoint) : tappedPoint;

      setState(() {
        _pendingCurveControlPoint = controlPoint;
        _canvasStatus = 'Curve bend set: tap the end point';
      });
      return;
    }

    if (activeStart.distanceTo(nextPoint) < _minimumWallLength) {
      _showCanvasMessage('Tap farther away to create a curve');
      return;
    }

    final segment = WallSegment(
      start: activeStart,
      end: nextPoint,
      controlPoint: _pendingCurveControlPoint,
      color: _currentLineColor,
      strokeWidth: _currentLineWidth,
      pattern: _currentLinePattern,
    );

    setState(() {
      _wallSegments = <WallSegment>[..._wallSegments, segment];
      _activeWallStart = nextPoint;
      _pendingCurveControlPoint = null;
      _undoStack.add(const _UndoEntry(_UndoKind.wallSegment));
      _canvasStatus = 'Curve added: ${segment.measurementLabel}';
    });
  }

  void _startFreehandStroke(Offset sceneOffset) {
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    setState(() {
      _draftFreehandPoints = [GraphPoint.fromOffset(sceneOffset)];
      _canvasStatus = 'Sketching freehand';
    });
  }

  void _appendFreehandPoint(Offset sceneOffset) {
    final point = GraphPoint.fromOffset(sceneOffset);
    if (_draftFreehandPoints.isNotEmpty &&
        _draftFreehandPoints.last.distanceTo(point) < 4) {
      return;
    }

    setState(() {
      _draftFreehandPoints = <GraphPoint>[..._draftFreehandPoints, point];
    });
  }

  void _finishFreehandStroke() {
    if (_draftFreehandPoints.length < 2) {
      setState(() {
        _draftFreehandPoints = <GraphPoint>[];
        _canvasStatus = 'Freehand stroke cancelled';
      });
      return;
    }

    final stroke = FreehandStroke(
      points: _draftFreehandPoints,
      color: _defaultFreehandColor,
      strokeWidth: _defaultFreehandWidth,
      opacity: _defaultFreehandOpacity,
    );

    setState(() {
      _freehandStrokes = <FreehandStroke>[..._freehandStrokes, stroke];
      _draftFreehandPoints = <GraphPoint>[];
      _undoStack.add(const _UndoEntry(_UndoKind.freehand));
      _selection = _Selection.freehand(_freehandStrokes.length - 1);
      _canvasStatus = 'Freehand stroke added';
    });
  }

  GraphPoint _snapWallPoint(GraphPoint point, GraphPoint? activeStart) {
    final gridPoint = _snapToGrid ? _snapPointToGrid(point) : point;

    if (activeStart == null) {
      return gridPoint;
    }

    return _snapPointToAngle(activeStart, gridPoint);
  }

  GraphPoint _snapPointToGrid(GraphPoint point) {
    return GraphPoint(
      x: (point.x / _gridSnapSize).round() * _gridSnapSize,
      y: (point.y / _gridSnapSize).round() * _gridSnapSize,
    );
  }

  GraphPoint _snapPointToAngle(GraphPoint start, GraphPoint rawEnd) {
    final dx = rawEnd.x - start.x;
    final dy = rawEnd.y - start.y;
    final absDx = dx.abs();
    final absDy = dy.abs();
    final longestDelta = math.max(absDx, absDy);

    if (longestDelta < _minimumWallLength) {
      return rawEnd;
    }

    final angle = math.atan2(dy, dx);
    const snapStep = math.pi / 4;
    final snappedAngle = (angle / snapStep).round() * snapStep;
    final angleDifference = _smallestAngleDifference(angle, snappedAngle);

    if (angleDifference > _angleSnapToleranceRadians) {
      return rawEnd;
    }

    final sector = (snappedAngle / snapStep).round() % 8;

    switch (sector) {
      case 0:
        return GraphPoint(x: start.x + absDx, y: start.y);
      case 1:
        return GraphPoint(
          x: start.x + longestDelta,
          y: start.y + longestDelta,
        );
      case 2:
        return GraphPoint(x: start.x, y: start.y + absDy);
      case 3:
        return GraphPoint(
          x: start.x - longestDelta,
          y: start.y + longestDelta,
        );
      case 4:
        return GraphPoint(x: start.x - absDx, y: start.y);
      case 5:
        return GraphPoint(
          x: start.x - longestDelta,
          y: start.y - longestDelta,
        );
      case 6:
        return GraphPoint(x: start.x, y: start.y - absDy);
      case 7:
        return GraphPoint(
          x: start.x + longestDelta,
          y: start.y - longestDelta,
        );
    }

    return rawEnd;
  }

  double _smallestAngleDifference(double a, double b) {
    final difference = (a - b).abs() % (math.pi * 2);
    return difference > math.pi ? (math.pi * 2) - difference : difference;
  }

  GraphPoint? _findNearbyEndpoint(GraphPoint point) {
    if (!_snapToObjects) {
      return null;
    }

    GraphPoint? nearestEndpoint;
    var nearestDistance = _endpointSnapDistance;

    for (final endpoint in _existingEndpoints) {
      final distance = point.distanceTo(endpoint);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestEndpoint = endpoint;
      }
    }

    return nearestEndpoint;
  }

  Iterable<GraphPoint> get _existingEndpoints sync* {
    for (final segment in _wallSegments) {
      yield segment.start;
      yield segment.end;
    }
  }

  Set<int> get _shapeSegmentIndexSet {
    return {
      for (final shape in _shapes)
        for (final index in shape.segmentIndexes)
          if (index >= 0 && index < _wallSegments.length) index,
    };
  }

  bool _selectExistingObjectAt(Offset canvasOffset) {
    final point = GraphPoint.fromOffset(canvasOffset);
    final selection = _selectionAt(point);
    if (selection == null) {
      return false;
    }

    setState(() {
      _selection = selection;
      _interaction.setSelected(_interactionReference(selection));
      _canvasStatus = _selectionStatus(selection);
    });
    return true;
  }

  void _selectObjectAt(Offset canvasOffset) {
    if (_selectExistingObjectAt(canvasOffset)) {
      return;
    }

    setState(() {
      _selection = null;
      _interaction.setSelected(null);
      _canvasStatus = 'Selection cleared';
    });
  }

  String _selectionStatus(_Selection selection) => switch (selection.kind) {
        _SelectionKind.annotation =>
          '${_annotations[selection.index].label} selected',
        _SelectionKind.shape => '${_shapes[selection.index].name} selected',
        _SelectionKind.freehand => 'Freehand stroke selected',
        _SelectionKind.segment => 'Line or arrow selected',
      };

  EditorObjectReference _interactionReference(_Selection selection) =>
      EditorObjectReference(
        switch (selection.kind) {
          _SelectionKind.annotation => EditorObjectKind.annotation,
          _SelectionKind.shape => EditorObjectKind.shape,
          _SelectionKind.freehand => EditorObjectKind.freehand,
          _SelectionKind.segment => EditorObjectKind.segment,
        },
        selection.index,
      );

  _Selection? _selectionAt(GraphPoint point) {
    final annotationIndex = _nearestAnnotationIndex(point);
    if (annotationIndex != null) {
      return _Selection.annotation(annotationIndex);
    }

    final shapeIndex = _shapeIndexAt(point);
    if (shapeIndex != null) {
      return _Selection.shape(shapeIndex);
    }

    final freehandIndex = _nearestFreehandIndex(point);
    if (freehandIndex != null) {
      return _Selection.freehand(freehandIndex);
    }

    final segmentIndex = _nearestSegmentIndex(point);
    return segmentIndex == null ? null : _Selection.segment(segmentIndex);
  }

  int? _nearestAnnotationIndex(GraphPoint point) {
    for (var i = _annotations.length - 1; i >= 0; i -= 1) {
      if (!_isAnnotationVisible(_annotations[i])) {
        continue;
      }

      final distance = _annotations[i].point.distanceTo(point);
      if (distance <= _dragHitDistance) {
        return i;
      }
    }

    return null;
  }

  int? _nearestSegmentIndex(GraphPoint point) {
    if (!_isLayerVisible(_GraphLayer.structure)) {
      return null;
    }

    final shapeSegmentIndexes = _shapeSegmentIndexSet;
    final draftStart =
        _interaction.drawingSession == EditorDrawingSession.plottingStructure
            ? _activePathStartSegmentIndex
            : null;

    for (var i = _wallSegments.length - 1; i >= 0; i -= 1) {
      if (shapeSegmentIndexes.contains(i) ||
          (draftStart != null && i >= draftStart)) {
        continue;
      }

      final segment = _wallSegments[i];
      final distance = _distanceToSegment(point, segment);

      if (distance <= _dragHitDistance) {
        return i;
      }
    }

    return null;
  }

  double _distanceToSegment(GraphPoint point, WallSegment segment) {
    final a = segment.start.offset;
    final b = segment.end.offset;
    final p = point.offset;
    final ab = b - a;
    final ap = p - a;
    final abLengthSquared = (ab.dx * ab.dx) + (ab.dy * ab.dy);

    if (abLengthSquared == 0) {
      return (p - a).distance;
    }

    final t =
        (((ap.dx * ab.dx) + (ap.dy * ab.dy)) / abLengthSquared).clamp(0.0, 1.0);
    final projection = Offset(a.dx + (ab.dx * t), a.dy + (ab.dy * t));

    return (p - projection).distance;
  }

  int? _nearestFreehandIndex(GraphPoint point) {
    if (!_isLayerVisible(_GraphLayer.structure)) {
      return null;
    }

    for (var i = _freehandStrokes.length - 1; i >= 0; i -= 1) {
      final stroke = _freehandStrokes[i];
      for (var p = 1; p < stroke.points.length; p += 1) {
        final distance = _distanceToLinePoints(
          point,
          stroke.points[p - 1],
          stroke.points[p],
        );
        if (distance <= _dragHitDistance) {
          return i;
        }
      }
    }

    return null;
  }

  double _distanceToLinePoints(
      GraphPoint point, GraphPoint start, GraphPoint end) {
    return _distanceToSegment(point, WallSegment(start: start, end: end));
  }

  int? _shapeIndexAt(GraphPoint point) {
    if (!_isLayerVisible(_GraphLayer.shapes)) {
      return null;
    }

    for (var i = _shapes.length - 1; i >= 0; i -= 1) {
      final shape = _shapes[i];
      final path = _shapePath(shape);
      if (path == null) {
        continue;
      }

      final containsPoint = shape.closed
          ? path.contains(point.offset)
          : path.getBounds().inflate(12).contains(point.offset);
      if (containsPoint) {
        return i;
      }
    }

    return null;
  }

  Rect? _shapeBounds(GraphShape shape) {
    final path = _shapePath(shape);
    if (path == null) {
      return null;
    }

    return path.getBounds();
  }

  Path? _shapePath(GraphShape shape) {
    final shapeSegments = <WallSegment>[];

    for (final index in shape.segmentIndexes) {
      if (index < 0 || index >= _wallSegments.length) {
        continue;
      }

      shapeSegments.add(_wallSegments[index]);
    }

    if (shapeSegments.isEmpty) {
      return null;
    }

    final path = Path()
      ..moveTo(shapeSegments.first.start.x, shapeSegments.first.start.y);

    for (final segment in shapeSegments) {
      final controlPoint = segment.controlPoint;
      if (controlPoint == null) {
        path.lineTo(segment.end.x, segment.end.y);
      } else {
        path.quadraticBezierTo(
          controlPoint.x,
          controlPoint.y,
          segment.end.x,
          segment.end.y,
        );
      }
    }

    if (shape.closed) {
      path.close();
    }

    return path;
  }

  void _startDragForSelection(_Selection selection, GraphPoint point) {
    final target = _dragTargetForSelection(selection, point);
    if (target == null) {
      return;
    }

    _activeDragTarget = target;
    _dragOriginalWallSegments = <WallSegment>[..._wallSegments];
    _dragOriginalAnnotations = <GraphAnnotation>[..._annotations];
    _dragOriginalShapes = <GraphShape>[..._shapes];
    _dragOriginalFreehandStrokes = <FreehandStroke>[..._freehandStrokes];
    _dragOriginalActiveWallStart = _activeWallStart;
    _dragOriginalActivePathStartPoint = _activePathStartPoint;
    _dragOriginalActivePathStartSegmentIndex = _activePathStartSegmentIndex;
    _dragMoved = false;
    _interaction.setDrawingSession(EditorDrawingSession.movingObject);
  }

  _DragTarget? _dragTargetForSelection(
    _Selection selection,
    GraphPoint point,
  ) {
    if (!_isSelectionEditable(selection)) {
      return null;
    }

    return switch (selection.kind) {
      _SelectionKind.annotation => _DragTarget.annotation(
          annotationIndex: selection.index,
          distance: _annotations[selection.index].point.distanceTo(point),
        ),
      _SelectionKind.shape => _nearestShapeResizeTarget(point) ??
          _nearestShapeRotationTarget(point) ??
          _DragTarget.shape(
            shapeIndex: selection.index,
            distance: 0,
            originalPoint: point,
          ),
      _SelectionKind.freehand => _DragTarget.freehand(
          freehandIndex: selection.index,
          distance: 0,
          originalPoint: point,
        ),
      _SelectionKind.segment => _nearestEndpointTarget(point) ??
          _DragTarget.segment(
            segmentIndex: selection.index,
            distance: _distanceToSegment(point, _wallSegments[selection.index]),
            originalPoint: point,
          ),
    };
  }

  _DragTarget? _nearestShapeResizeTarget(GraphPoint point) {
    if (!_isLayerVisible(_GraphLayer.shapes) ||
        _isLayerLocked(_GraphLayer.shapes) ||
        _isLayerLocked(_GraphLayer.structure)) {
      return null;
    }

    final selectedShapeIndex = _selection?.shapeIndex;
    if (selectedShapeIndex == null ||
        selectedShapeIndex < 0 ||
        selectedShapeIndex >= _shapes.length) {
      return null;
    }

    final bounds = _shapeBounds(_shapes[selectedShapeIndex]);
    if (bounds == null) {
      return null;
    }

    final handles = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomRight,
      bounds.bottomLeft,
    ];

    for (var i = 0; i < handles.length; i += 1) {
      final distance = (point.offset - handles[i]).distance;
      if (distance <= _dragHitDistance) {
        return _DragTarget.shapeResize(
          shapeIndex: selectedShapeIndex,
          distance: distance,
          originalPoint: point,
          originalBounds: bounds,
          resizeHandleIndex: i,
        );
      }
    }

    return null;
  }

  _DragTarget? _nearestShapeRotationTarget(GraphPoint point) {
    if (!_isLayerVisible(_GraphLayer.shapes) ||
        _isLayerLocked(_GraphLayer.shapes) ||
        _isLayerLocked(_GraphLayer.structure)) {
      return null;
    }

    final selectedShapeIndex = _selection?.shapeIndex;
    if (selectedShapeIndex == null ||
        selectedShapeIndex < 0 ||
        selectedShapeIndex >= _shapes.length) {
      return null;
    }

    final bounds = _shapeBounds(_shapes[selectedShapeIndex]);
    if (bounds == null) {
      return null;
    }

    final handleCenter = bounds.topCenter - const Offset(0, 28);
    final distance = (point.offset - handleCenter).distance;
    if (distance > _dragHitDistance) {
      return null;
    }

    return _DragTarget.shapeRotation(
      shapeIndex: selectedShapeIndex,
      distance: distance,
      originalPoint: point,
      shapeCenter: GraphPoint.fromOffset(bounds.center),
      initialAngleRadians: math.atan2(
        point.y - bounds.center.dy,
        point.x - bounds.center.dx,
      ),
      originalRotationDegrees: _shapes[selectedShapeIndex].rotationDegrees,
    );
  }

  _DragTarget? _nearestEndpointTarget(GraphPoint point) {
    if (!_isLayerVisible(_GraphLayer.structure)) {
      return null;
    }

    GraphPoint? nearestPoint;
    var nearestDistance = _dragHitDistance;

    for (final endpoint in _allMoveableEndpoints) {
      final distance = endpoint.distanceTo(point);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPoint = endpoint;
      }
    }

    if (nearestPoint == null) {
      return null;
    }

    return _DragTarget.wallEndpoint(
      endpointRefs: _endpointRefsForPoint(nearestPoint),
      movesActiveWallStart: _pointMatches(_activeWallStart, nearestPoint),
      movesActivePathStart: _pointMatches(_activePathStartPoint, nearestPoint),
      originalPoint: nearestPoint,
      distance: nearestDistance,
    );
  }

  Iterable<GraphPoint> get _allMoveableEndpoints sync* {
    final shapeSegmentIndexes = _shapeSegmentIndexSet;

    for (var i = 0; i < _wallSegments.length; i += 1) {
      if (shapeSegmentIndexes.contains(i)) {
        continue;
      }

      final segment = _wallSegments[i];
      yield segment.start;
      yield segment.end;
    }

    final activeWallStart = _activeWallStart;
    if (activeWallStart != null) {
      yield activeWallStart;
    }
  }

  List<_SegmentEndpointRef> _endpointRefsForPoint(GraphPoint point) {
    final refs = <_SegmentEndpointRef>[];
    final shapeSegmentIndexes = _shapeSegmentIndexSet;

    for (var i = 0; i < _wallSegments.length; i += 1) {
      if (shapeSegmentIndexes.contains(i)) {
        continue;
      }

      final segment = _wallSegments[i];

      if (_pointMatches(segment.start, point)) {
        refs.add(_SegmentEndpointRef(segmentIndex: i, isStart: true));
      }

      if (_pointMatches(segment.end, point)) {
        refs.add(_SegmentEndpointRef(segmentIndex: i, isStart: false));
      }
    }

    return refs;
  }

  bool _pointMatches(GraphPoint? a, GraphPoint b) {
    return a != null && a.distanceTo(b) <= 0.5;
  }

  void _moveActiveTarget(GraphPoint point) {
    final target = _activeDragTarget;
    if (target == null) {
      return;
    }

    switch (target.kind) {
      case _DragKind.annotation:
        _moveAnnotation(target, point);
        return;
      case _DragKind.wallEndpoint:
        _moveWallEndpoint(
            target, _snapToGrid ? _snapPointToGrid(point) : point);
        return;
      case _DragKind.shape:
        _moveShape(target, point);
        return;
      case _DragKind.shapeResize:
        _resizeShape(target, point);
        return;
      case _DragKind.shapeRotation:
        _rotateShape(target, point);
        return;
      case _DragKind.freehand:
        _moveFreehand(target, point);
        return;
      case _DragKind.segment:
        _moveSegment(target, point);
        return;
    }
  }

  void _moveSegment(_DragTarget target, GraphPoint point) {
    final index = target.segmentIndex;
    final originalPoint = target.originalPoint;
    final sourceSegments = _dragOriginalWallSegments ?? _wallSegments;
    if (index == null ||
        originalPoint == null ||
        index < 0 ||
        index >= sourceSegments.length) {
      return;
    }

    final delta = point.offset - originalPoint.offset;
    final nextSegments = <WallSegment>[..._wallSegments];
    nextSegments[index] = _translateSegment(sourceSegments[index], delta);
    setState(() {
      _wallSegments = nextSegments;
      _dragMoved = true;
    });
  }

  void _moveAnnotation(_DragTarget target, GraphPoint point) {
    final index = target.annotationIndex;
    if (index == null || index < 0 || index >= _annotations.length) {
      return;
    }

    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(point: point);

    setState(() {
      _annotations = nextAnnotations;
      _dragMoved = true;
    });
  }

  void _moveWallEndpoint(_DragTarget target, GraphPoint point) {
    final originalPoint = target.originalPoint;
    if (originalPoint == null) {
      return;
    }

    final delta = Offset(point.x - originalPoint.x, point.y - originalPoint.y);
    final sourceSegments = _dragOriginalWallSegments ?? _wallSegments;
    final nextSegments = <WallSegment>[..._wallSegments];

    for (final ref in target.endpointRefs) {
      if (ref.segmentIndex < 0 ||
          ref.segmentIndex >= nextSegments.length ||
          ref.segmentIndex >= sourceSegments.length) {
        continue;
      }

      final segment = sourceSegments[ref.segmentIndex];
      final movedControlPoint = segment.controlPoint == null
          ? null
          : GraphPoint(
              x: segment.controlPoint!.x + (delta.dx * 0.5),
              y: segment.controlPoint!.y + (delta.dy * 0.5),
            );

      nextSegments[ref.segmentIndex] = ref.isStart
          ? segment.copyWith(start: point, controlPoint: movedControlPoint)
          : segment.copyWith(end: point, controlPoint: movedControlPoint);
    }

    setState(() {
      _wallSegments = nextSegments;
      if (target.movesActiveWallStart) {
        _activeWallStart = point;
      }
      if (target.movesActivePathStart) {
        _activePathStartPoint = point;
      }
      _dragMoved = true;
    });
  }

  void _moveShape(_DragTarget target, GraphPoint point) {
    final shapeIndex = target.shapeIndex;
    final originalPoint = target.originalPoint;
    if (shapeIndex == null ||
        originalPoint == null ||
        shapeIndex < 0 ||
        shapeIndex >= _shapes.length) {
      return;
    }

    final delta = Offset(point.x - originalPoint.x, point.y - originalPoint.y);
    final sourceSegments = _dragOriginalWallSegments ?? _wallSegments;
    final nextSegments = <WallSegment>[..._wallSegments];

    for (final segmentIndex
        in _uniqueShapeSegmentIndexes(_shapes[shapeIndex])) {
      if (segmentIndex < 0 ||
          segmentIndex >= nextSegments.length ||
          segmentIndex >= sourceSegments.length) {
        continue;
      }

      nextSegments[segmentIndex] = _translateSegment(
        sourceSegments[segmentIndex],
        delta,
      );
    }

    setState(() {
      _wallSegments = nextSegments;
      _dragMoved = true;
    });
  }

  void _moveFreehand(_DragTarget target, GraphPoint point) {
    final index = target.freehandIndex;
    final originalPoint = target.originalPoint;
    if (index == null ||
        originalPoint == null ||
        index < 0 ||
        index >= _freehandStrokes.length) {
      return;
    }

    final sourceStrokes = _dragOriginalFreehandStrokes ?? _freehandStrokes;
    if (index >= sourceStrokes.length) {
      return;
    }

    final delta = Offset(point.x - originalPoint.x, point.y - originalPoint.y);
    final nextStrokes = <FreehandStroke>[..._freehandStrokes];
    final stroke = sourceStrokes[index];
    nextStrokes[index] = stroke.copyWith(
      points: [
        for (final strokePoint in stroke.points)
          GraphPoint.fromOffset(strokePoint.offset + delta),
      ],
    );

    setState(() {
      _freehandStrokes = nextStrokes;
      _dragMoved = true;
    });
  }

  void _resizeShape(_DragTarget target, GraphPoint point) {
    final shapeIndex = target.shapeIndex;
    final originalBounds = target.originalBounds;
    if (shapeIndex == null ||
        originalBounds == null ||
        shapeIndex < 0 ||
        shapeIndex >= _shapes.length) {
      return;
    }

    final nextBounds = _boundsForResizeHandle(
      originalBounds,
      target.resizeHandleIndex,
      point.offset,
    );
    if (nextBounds.width < 24 || nextBounds.height < 24) {
      return;
    }

    final sourceSegments = _dragOriginalWallSegments ?? _wallSegments;
    final sourceShapes = _dragOriginalShapes ?? _shapes;
    final nextSegments = <WallSegment>[..._wallSegments];

    for (final segmentIndex
        in _uniqueShapeSegmentIndexes(sourceShapes[shapeIndex])) {
      if (segmentIndex < 0 ||
          segmentIndex >= nextSegments.length ||
          segmentIndex >= sourceSegments.length) {
        continue;
      }

      nextSegments[segmentIndex] = _resizeSegment(
        sourceSegments[segmentIndex],
        originalBounds,
        nextBounds,
      );
    }

    setState(() {
      _wallSegments = nextSegments;
      _dragMoved = true;
    });
  }

  Rect _boundsForResizeHandle(
    Rect originalBounds,
    int handleIndex,
    Offset point,
  ) {
    return switch (handleIndex) {
      0 => Rect.fromPoints(point, originalBounds.bottomRight),
      1 => Rect.fromPoints(point, originalBounds.bottomLeft),
      2 => Rect.fromPoints(originalBounds.topLeft, point),
      3 => Rect.fromPoints(originalBounds.topRight, point),
      _ => originalBounds,
    };
  }

  WallSegment _resizeSegment(
    WallSegment segment,
    Rect from,
    Rect to,
  ) {
    return segment.copyWith(
      start: _resizePoint(segment.start, from, to),
      end: _resizePoint(segment.end, from, to),
      controlPoint: segment.controlPoint == null
          ? null
          : _resizePoint(segment.controlPoint!, from, to),
    );
  }

  GraphPoint _resizePoint(GraphPoint point, Rect from, Rect to) {
    final xRatio = from.width == 0 ? 0 : (point.x - from.left) / from.width;
    final yRatio = from.height == 0 ? 0 : (point.y - from.top) / from.height;
    return GraphPoint(
      x: to.left + (to.width * xRatio),
      y: to.top + (to.height * yRatio),
    );
  }

  void _rotateShape(_DragTarget target, GraphPoint point) {
    final shapeIndex = target.shapeIndex;
    final shapeCenter = target.shapeCenter;
    if (shapeIndex == null ||
        shapeCenter == null ||
        shapeIndex < 0 ||
        shapeIndex >= _shapes.length) {
      return;
    }

    final currentAngle = math.atan2(
      point.y - shapeCenter.y,
      point.x - shapeCenter.x,
    );
    final deltaRadians = currentAngle - target.initialAngleRadians;
    final center = shapeCenter.offset;
    final sourceSegments = _dragOriginalWallSegments ?? _wallSegments;
    final sourceShapes = _dragOriginalShapes ?? _shapes;
    final nextSegments = <WallSegment>[..._wallSegments];
    final nextShapes = <GraphShape>[..._shapes];

    for (final segmentIndex
        in _uniqueShapeSegmentIndexes(sourceShapes[shapeIndex])) {
      if (segmentIndex < 0 ||
          segmentIndex >= nextSegments.length ||
          segmentIndex >= sourceSegments.length) {
        continue;
      }

      nextSegments[segmentIndex] = _rotateSegment(
        sourceSegments[segmentIndex],
        center,
        deltaRadians,
      );
    }

    nextShapes[shapeIndex] = sourceShapes[shapeIndex].copyWith(
      rotationDegrees: _normalizeDegrees(
        target.originalRotationDegrees + _radiansToDegrees(deltaRadians),
      ),
    );

    setState(() {
      _wallSegments = nextSegments;
      _shapes = nextShapes;
      _dragMoved = true;
    });
  }

  List<int> _uniqueShapeSegmentIndexes(GraphShape shape) {
    return shape.segmentIndexes.toSet().toList();
  }

  WallSegment _translateSegment(WallSegment segment, Offset delta) {
    return segment.copyWith(
      start: GraphPoint.fromOffset(segment.start.offset + delta),
      end: GraphPoint.fromOffset(segment.end.offset + delta),
      controlPoint: segment.controlPoint == null
          ? null
          : GraphPoint.fromOffset(segment.controlPoint!.offset + delta),
    );
  }

  WallSegment _rotateSegment(
    WallSegment segment,
    Offset center,
    double radians,
  ) {
    return segment.copyWith(
      start: GraphPoint.fromOffset(
        _rotateOffset(segment.start.offset, center, radians),
      ),
      end: GraphPoint.fromOffset(
        _rotateOffset(segment.end.offset, center, radians),
      ),
      controlPoint: segment.controlPoint == null
          ? null
          : GraphPoint.fromOffset(
              _rotateOffset(segment.controlPoint!.offset, center, radians),
            ),
    );
  }

  Offset _rotateOffset(Offset point, Offset center, double radians) {
    final translated = point - center;
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);

    return Offset(
          (translated.dx * cosTheta) - (translated.dy * sinTheta),
          (translated.dx * sinTheta) + (translated.dy * cosTheta),
        ) +
        center;
  }

  double _radiansToDegrees(double radians) => radians * 180 / math.pi;

  double _normalizeDegrees(double degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  void _finishActiveDrag() {
    if (!_dragMoved) {
      return;
    }

    final originalWallSegments = _dragOriginalWallSegments;
    final originalAnnotations = _dragOriginalAnnotations;
    final originalShapes = _dragOriginalShapes;
    final originalFreehandStrokes = _dragOriginalFreehandStrokes;

    if (originalWallSegments == null ||
        originalAnnotations == null ||
        originalShapes == null ||
        originalFreehandStrokes == null) {
      return;
    }

    setState(() {
      _undoStack.add(
        _UndoEntry(
          _UndoKind.move,
          previousWallSegments: originalWallSegments,
          previousAnnotations: originalAnnotations,
          previousShapes: originalShapes,
          previousFreehandStrokes: originalFreehandStrokes,
          previousActiveWallStart: _dragOriginalActiveWallStart,
          previousActivePathStartPoint: _dragOriginalActivePathStartPoint,
          previousActivePathStartSegmentIndex:
              _dragOriginalActivePathStartSegmentIndex,
        ),
      );
      _canvasStatus = 'Move saved';
    });
  }

  Future<void> _addPlaceholderAnnotation(Offset canvasOffset) async {
    final tappedPoint = GraphPoint.fromOffset(canvasOffset);
    var annotation = _buildAnnotationForSelectedTool(tappedPoint);
    final layer = _layerForAnnotation(annotation);

    if (_isLayerLocked(layer)) {
      _showCanvasMessage(
        layer == _GraphLayer.photos
            ? 'Photos layer is locked'
            : 'Findings layer is locked',
      );
      return;
    }

    if (annotation.kind == GraphAnnotationKind.marker &&
        annotation.markerType == GraphMarkerType.moisture) {
      final moisture = await _showTextLabelDialog(
        title: 'Moisture percentage',
        initialText: '20%',
      );
      if (!mounted || moisture == null) {
        return;
      }
      annotation = annotation.copyWith(label: moisture, note: moisture);
    } else if (annotation.kind == GraphAnnotationKind.marker &&
        annotation.markerType == GraphMarkerType.treatmentNote) {
      final note = await _showTextLabelDialog(
        title: 'Treatment note',
        initialText: 'Treatment Note',
      );
      if (!mounted || note == null) {
        return;
      }
      annotation = annotation.copyWith(label: note, note: note);
    }

    setState(() {
      _annotations = <GraphAnnotation>[..._annotations, annotation];
      _undoStack.add(const _UndoEntry(_UndoKind.annotation));
      _canvasStatus = '${annotation.label} placed';
    });
  }

  Future<void> _handleTextTap(Offset canvasOffset) async {
    if (_isLayerLocked(_GraphLayer.findings)) {
      _showCanvasMessage('Findings layer is locked');
      return;
    }

    final existingTextIndex = _findTextAnnotationIndex(canvasOffset);

    if (existingTextIndex != null) {
      await _editTextAnnotation(existingTextIndex);
      return;
    }

    await _addTextAnnotation(canvasOffset);
  }

  Future<void> _addTextAnnotation(Offset canvasOffset) async {
    final text = await _showTextLabelDialog(
      title: 'Add text label',
      initialText: 'Text ${_textCount + 1}',
    );

    if (!mounted || text == null) {
      return;
    }

    final annotation = GraphAnnotation(
      kind: GraphAnnotationKind.text,
      point: GraphPoint.fromOffset(canvasOffset),
      label: text,
      fontSize: _defaultTextFontSize,
      textColor: _defaultTextColor,
      backgroundColor: _defaultTextBackground,
      borderColor: _defaultTextBorder,
    );

    setState(() {
      _annotations = <GraphAnnotation>[..._annotations, annotation];
      _undoStack.add(const _UndoEntry(_UndoKind.annotation));
      _canvasStatus = '${annotation.label} placed';
    });
  }

  Future<void> _editTextAnnotation(int index) async {
    final previousAnnotation = _annotations[index];
    final text = await _showTextLabelDialog(
      title: 'Edit text label',
      initialText: previousAnnotation.label,
    );

    if (!mounted || text == null || text == previousAnnotation.label) {
      return;
    }

    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = previousAnnotation.copyWith(label: text);

    setState(() {
      _annotations = nextAnnotations;
      _undoStack.add(
        _UndoEntry(
          _UndoKind.textEdit,
          annotationIndex: index,
          previousAnnotation: previousAnnotation,
        ),
      );
      _canvasStatus = 'Text updated';
    });
  }

  Future<void> _editShapeText(int index) async {
    if (index < 0 || index >= _shapes.length || _shapes[index].isStructure) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    final before = _EditorSnapshot.capture(this);
    final shape = _shapes[index];
    _interaction.setTextEditing(true);
    final text = await _showTextLabelDialog(
      title: 'Edit shape text',
      initialText: shape.text.isEmpty ? shape.name : shape.text,
    );
    _interaction.setTextEditing(false);
    if (!mounted || text == null || text == shape.text) {
      return;
    }

    final nextShapes = <GraphShape>[..._shapes];
    nextShapes[index] = shape.copyWith(text: text);
    setState(() {
      _shapes = nextShapes;
      _undoStack.add(
        _UndoEntry(_UndoKind.snapshot, previousSnapshot: before),
      );
      _canvasStatus = 'Shape text updated';
    });
  }

  Future<String?> _showTextLabelDialog({
    required String title,
    required String initialText,
  }) async {
    final controller = TextEditingController(text: initialText);

    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.of(context).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  int? _findTextAnnotationIndex(Offset canvasOffset) {
    for (var i = _annotations.length - 1; i >= 0; i -= 1) {
      final annotation = _annotations[i];

      if (annotation.kind != GraphAnnotationKind.text) {
        continue;
      }

      if (!_isAnnotationVisible(annotation)) {
        continue;
      }

      final halfWidth =
          ((annotation.label.length * 8) + 24).clamp(56, 170).toDouble() / 2;
      const halfHeight = 24.0;
      final dx = (canvasOffset.dx - annotation.point.x).abs();
      final dy = (canvasOffset.dy - annotation.point.y).abs();

      if (dx <= halfWidth && dy <= halfHeight) {
        return i;
      }
    }

    return null;
  }

  GraphAnnotation _buildAnnotationForSelectedTool(GraphPoint point) {
    switch (_selectedTool) {
      case CanvasTool.select:
      case CanvasTool.pan:
      case CanvasTool.structure:
      case CanvasTool.rectangle:
      case CanvasTool.square:
      case CanvasTool.circle:
      case CanvasTool.ellipse:
      case CanvasTool.triangle:
      case CanvasTool.curve:
      case CanvasTool.wall:
      case CanvasTool.arrow:
      case CanvasTool.freehand:
        throw StateError('Drawing tools are not annotations.');
      case CanvasTool.marker:
        return GraphAnnotation(
          kind: GraphAnnotationKind.marker,
          point: point,
          label: _selectedMarkerType.shortLabel,
          markerType: _selectedMarkerType,
          color: _selectedMarkerColor,
          size: _selectedMarkerSize,
        );
      case CanvasTool.photo:
        return GraphAnnotation(
          kind: GraphAnnotationKind.photo,
          point: point,
          label: 'Photo ${_photoCount + 1}',
          markerType: GraphMarkerType.camera,
          color: GraphMarkerType.camera.defaultColor,
        );
      case CanvasTool.text:
        throw StateError(
            'Text annotations are created through the text dialog.');
    }
  }

  int get _textCount {
    return _annotations
        .where((annotation) => annotation.kind == GraphAnnotationKind.text)
        .length;
  }

  int get _photoCount {
    return _annotations
        .where((annotation) => annotation.kind == GraphAnnotationKind.photo)
        .length;
  }

  void _finishWallPath({bool closeShapeDefault = false}) {
    if (_selectedTool == CanvasTool.structure) {
      _finishStructurePath();
      return;
    }
    _finishWallPathAsync(closeShapeDefault: closeShapeDefault);
  }

  Future<void> _finishWallPathAsync({bool closeShapeDefault = false}) async {
    if (_activeWallStart == null) {
      _showCanvasMessage('No active wall shape to finish');
      return;
    }

    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    final startSegmentIndex =
        _activePathStartSegmentIndex ?? _wallSegments.length;
    final pathSegmentCount = _wallSegments.length - startSegmentIndex;

    if (pathSegmentCount <= 0) {
      setState(() {
        _activeWallStart = null;
        _activePathStartPoint = null;
        _pendingCurveControlPoint = null;
        _previewSegment = null;
        _activePathStartSegmentIndex = null;
        if (_undoStack.isNotEmpty &&
            _undoStack.last.kind == _UndoKind.wallStart) {
          _undoStack.removeLast();
        }
        _canvasStatus = 'Start point cleared';
      });
      return;
    }

    final pathStartPoint = _activePathStartPoint;
    final activeWallStart = _activeWallStart;
    final pathReturnsToStart = pathStartPoint != null &&
        activeWallStart != null &&
        pathSegmentCount >= 2 &&
        activeWallStart.distanceTo(pathStartPoint) <= _minimumWallLength;
    final canAddClosingSegment = pathStartPoint != null &&
        activeWallStart != null &&
        pathSegmentCount >= 2 &&
        activeWallStart.distanceTo(pathStartPoint) > _minimumWallLength;
    final canCloseShape = pathReturnsToStart || canAddClosingSegment;
    final result = await _showFinishShapeDialog(
      canCloseShape: canCloseShape,
      closeShapeDefault:
          (closeShapeDefault || pathReturnsToStart) && canCloseShape,
      defaultName: _selectedDrawingPreset?.kind == GraphDrawingPresetKind.area
          ? _defaultShapeName(_selectedTool)
          : 'Shape ${_shapes.length + 1}',
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      final previousActiveWallStart = _activeWallStart;
      final previousActivePathStartPoint = _activePathStartPoint;
      final previousActivePathStartSegmentIndex = _activePathStartSegmentIndex;
      var addedSegmentCount = 0;
      final shapeSegmentIndexes = <int>[
        for (var i = startSegmentIndex; i < _wallSegments.length; i += 1) i,
      ];

      if (result.closeShape && canAddClosingSegment) {
        final closingSegment = WallSegment(
          start: _activeWallStart!,
          end: _activePathStartPoint!,
        );
        shapeSegmentIndexes.add(_wallSegments.length);
        _wallSegments = <WallSegment>[..._wallSegments, closingSegment];
        addedSegmentCount = 1;
      }

      final shape = GraphShape(
        name: result.name,
        segmentIndexes: shapeSegmentIndexes,
        fillColor: result.fillColor,
        fillOpacity: result.fillOpacity,
        borderColor: result.borderColor,
        borderWidth: result.borderWidth,
        pattern: result.pattern,
        closed: result.closeShape && canCloseShape,
        rotationDegrees: 0,
        preset: _selectedDrawingPreset?.kind == GraphDrawingPresetKind.area
            ? _selectedDrawingPreset
            : null,
      );

      _shapes = <GraphShape>[..._shapes, shape];
      _activeWallStart = null;
      _activePathStartPoint = null;
      _pendingCurveControlPoint = null;
      _previewSegment = null;
      _activePathStartSegmentIndex = null;
      _undoStack.add(
        _UndoEntry(
          _UndoKind.shapeFinish,
          shapeIndex: _shapes.length - 1,
          addedSegmentCount: addedSegmentCount,
          previousActiveWallStart: previousActiveWallStart,
          previousActivePathStartPoint: previousActivePathStartPoint,
          previousActivePathStartSegmentIndex:
              previousActivePathStartSegmentIndex,
        ),
      );
      _canvasStatus = 'Shape finished: ${shape.name}';
    });
  }

  Future<_FinishShapeResult?> _showFinishShapeDialog({
    required bool canCloseShape,
    required bool closeShapeDefault,
    required String defaultName,
  }) async {
    final nameController = TextEditingController(text: defaultName);
    var closeShape = closeShapeDefault || canCloseShape;
    var fillChoice = _shapeFillChoiceForColor(_currentShapeFillColor);
    var borderChoice = _shapeBorderChoiceForColor(_currentShapeBorderColor);
    var borderWidth = _currentShapeBorderWidth;
    var pattern = _currentShapePattern;

    final result = await showDialog<_FinishShapeResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Finish shape'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Shape name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: closeShape,
                      enabled: canCloseShape,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Close shape'),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          closeShape = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<_ShapeFillChoice>(
                      initialValue: fillChoice,
                      decoration: const InputDecoration(
                        labelText: 'Transparent fill',
                        border: OutlineInputBorder(),
                      ),
                      items: _ShapeFillChoice.values
                          .map(
                            (choice) => DropdownMenuItem(
                              value: choice,
                              child: _ColorChoiceLabel(
                                label: choice.label,
                                color: choice.color,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          fillChoice = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_ShapeBorderChoice>(
                      initialValue: borderChoice,
                      decoration: const InputDecoration(
                        labelText: 'Border color',
                        border: OutlineInputBorder(),
                      ),
                      items: _ShapeBorderChoice.values
                          .map(
                            (choice) => DropdownMenuItem(
                              value: choice,
                              child: _ColorChoiceLabel(
                                label: choice.label,
                                color: choice.color,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          borderChoice = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<double>(
                      initialValue: borderWidth,
                      decoration: const InputDecoration(
                        labelText: 'Border width',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 2.0, child: Text('Thin')),
                        DropdownMenuItem(value: 3.0, child: Text('Medium')),
                        DropdownMenuItem(value: 5.0, child: Text('Heavy')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          borderWidth = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GraphShapePattern>(
                      initialValue: pattern,
                      decoration: const InputDecoration(
                        labelText: 'Pattern',
                        border: OutlineInputBorder(),
                      ),
                      items: GraphShapePattern.values
                          .map(
                            (pattern) => DropdownMenuItem(
                              value: pattern,
                              child: Text(_patternLabel(pattern)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          pattern = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim().isEmpty
                        ? defaultName
                        : nameController.text.trim();
                    Navigator.of(context).pop(
                      _FinishShapeResult(
                        name: name,
                        closeShape: closeShape,
                        fillColor: fillChoice.color,
                        fillOpacity: fillChoice.opacity,
                        borderColor: borderChoice.color,
                        borderWidth: borderWidth,
                        pattern: pattern,
                      ),
                    );
                  },
                  child: const Text('Finish'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    return result;
  }

  void _undoLastAction() {
    if (_undoStack.isEmpty) {
      _showCanvasMessage('Nothing to undo');
      return;
    }

    final undoEntry = _undoStack.removeLast();
    final redoEntry = _RedoEntry(
      snapshot: _EditorSnapshot.capture(this),
      undoEntry: undoEntry,
    );

    _applyingHistory = true;
    setState(() {
      switch (undoEntry.kind) {
        case _UndoKind.snapshot:
          undoEntry.previousSnapshot?.restore(this);
          _selection = null;
          _interaction.setSelected(null);
          _canvasStatus = 'Action undone';
          break;
        case _UndoKind.wallStart:
          _activeWallStart = null;
          _activePathStartPoint = null;
          _pendingCurveControlPoint = null;
          _previewSegment = null;
          _activePathStartSegmentIndex = null;
          _canvasStatus = 'Wall start removed';
          break;
        case _UndoKind.wallSegment:
          _undoWallSegment();
          break;
        case _UndoKind.annotation:
          _undoAnnotation();
          break;
        case _UndoKind.freehand:
          _undoFreehand();
          break;
        case _UndoKind.textEdit:
          _undoTextEdit(undoEntry);
          break;
        case _UndoKind.move:
          _undoMove(undoEntry);
          break;
        case _UndoKind.shapeFinish:
          _undoShapeFinish(undoEntry);
          break;
      }
    });
    _applyingHistory = false;
    _redoStack.add(redoEntry);
  }

  void _redoLastAction() {
    if (_redoStack.isEmpty) {
      _showCanvasMessage('Nothing to redo');
      return;
    }

    final redoEntry = _redoStack.removeLast();
    _applyingHistory = true;
    setState(() {
      redoEntry.snapshot.restore(this);
      _undoStack.add(redoEntry.undoEntry);
      _canvasStatus = 'Action restored';
    });
    _applyingHistory = false;
  }

  void _undoWallSegment() {
    if (_wallSegments.isEmpty) {
      _canvasStatus = 'No wall segment to undo';
      return;
    }

    final removedSegment = _wallSegments.last;

    _wallSegments = _wallSegments.sublist(0, _wallSegments.length - 1);
    _activeWallStart = removedSegment.start;
    _pendingCurveControlPoint = null;
    _previewSegment = null;
    if (_activePathStartSegmentIndex != null &&
        _wallSegments.length <= _activePathStartSegmentIndex!) {
      _activePathStartPoint = removedSegment.start;
    }
    _canvasStatus = 'Last wall removed';
  }

  void _undoAnnotation() {
    if (_annotations.isEmpty) {
      _canvasStatus = 'No item to undo';
      return;
    }

    _annotations = _annotations.sublist(0, _annotations.length - 1);
    _canvasStatus = 'Last item removed';
  }

  void _undoFreehand() {
    if (_freehandStrokes.isEmpty) {
      _canvasStatus = 'No freehand stroke to undo';
      return;
    }

    _freehandStrokes = _freehandStrokes.sublist(0, _freehandStrokes.length - 1);
    _canvasStatus = 'Last freehand stroke removed';
  }

  void _undoTextEdit(_UndoEntry undoEntry) {
    final index = undoEntry.annotationIndex;
    final previousAnnotation = undoEntry.previousAnnotation;

    if (index == null ||
        previousAnnotation == null ||
        index < 0 ||
        index >= _annotations.length) {
      _canvasStatus = 'Text edit could not be undone';
      return;
    }

    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = previousAnnotation;
    _annotations = nextAnnotations;
    _canvasStatus = 'Text edit undone';
  }

  void _undoMove(_UndoEntry undoEntry) {
    final previousWallSegments = undoEntry.previousWallSegments;
    final previousAnnotations = undoEntry.previousAnnotations;
    final previousShapes = undoEntry.previousShapes;
    final previousFreehandStrokes = undoEntry.previousFreehandStrokes;

    if (previousWallSegments == null ||
        previousAnnotations == null ||
        previousShapes == null ||
        previousFreehandStrokes == null) {
      _canvasStatus = 'Move could not be undone';
      return;
    }

    _wallSegments = previousWallSegments;
    _annotations = previousAnnotations;
    _shapes = previousShapes;
    _freehandStrokes = previousFreehandStrokes;
    _activeWallStart = undoEntry.previousActiveWallStart;
    _activePathStartPoint = undoEntry.previousActivePathStartPoint;
    _pendingCurveControlPoint = null;
    _previewSegment = null;
    _activePathStartSegmentIndex =
        undoEntry.previousActivePathStartSegmentIndex;
    _canvasStatus = 'Move undone';
  }

  void _undoShapeFinish(_UndoEntry undoEntry) {
    final shapeIndex = undoEntry.shapeIndex;

    if (shapeIndex != null && shapeIndex >= 0 && shapeIndex < _shapes.length) {
      final nextShapes = <GraphShape>[..._shapes]..removeAt(shapeIndex);
      _shapes = nextShapes;
    } else if (_shapes.isNotEmpty) {
      _shapes = _shapes.sublist(0, _shapes.length - 1);
    }

    if (undoEntry.addedSegmentCount > 0 &&
        undoEntry.addedSegmentCount <= _wallSegments.length) {
      _wallSegments = _wallSegments.sublist(
        0,
        _wallSegments.length - undoEntry.addedSegmentCount,
      );
    }

    _activeWallStart = undoEntry.previousActiveWallStart;
    _activePathStartPoint = undoEntry.previousActivePathStartPoint;
    _pendingCurveControlPoint = null;
    _previewSegment = null;
    _activePathStartSegmentIndex =
        undoEntry.previousActivePathStartSegmentIndex;
    _canvasStatus = 'Shape finish undone';
  }

  void _deleteSelection() {
    final currentSelection = _selection;

    if (currentSelection == null) {
      _showCanvasMessage('Nothing selected');
      return;
    }

    if (!_isSelectionEditable(currentSelection)) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    setState(() {
      switch (currentSelection.kind) {
        case _SelectionKind.annotation:
          final index = currentSelection.index;
          if (index >= 0 && index < _annotations.length) {
            _annotations = <GraphAnnotation>[..._annotations]..removeAt(index);
            _canvasStatus = 'Item deleted';
          }
          break;
        case _SelectionKind.segment:
          final index = currentSelection.index;
          if (index >= 0 && index < _wallSegments.length) {
            _removeSegmentAt(index);
            _canvasStatus = 'Line deleted';
          }
          break;
        case _SelectionKind.shape:
          final index = currentSelection.index;
          if (index >= 0 && index < _shapes.length) {
            _shapes = <GraphShape>[..._shapes]..removeAt(index);
            _canvasStatus = 'Shape overlay deleted';
          }
          break;
        case _SelectionKind.freehand:
          final index = currentSelection.index;
          if (index >= 0 && index < _freehandStrokes.length) {
            _freehandStrokes = <FreehandStroke>[..._freehandStrokes]
              ..removeAt(index);
            _canvasStatus = 'Freehand stroke deleted';
          }
          break;
      }

      _selection = null;
    });
  }

  void _duplicateSelection() {
    final currentSelection = _selection;

    if (currentSelection == null) {
      _showCanvasMessage('Nothing selected');
      return;
    }

    if (!_isSelectionEditable(currentSelection)) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    const duplicateOffset = Offset(36, 36);

    _recordSnapshotUndo();
    setState(() {
      switch (currentSelection.kind) {
        case _SelectionKind.annotation:
          final index = currentSelection.index;
          if (index >= 0 && index < _annotations.length) {
            final annotation = _annotations[index];
            final duplicated = annotation.copyWith(
              point: GraphPoint.fromOffset(
                  annotation.point.offset + duplicateOffset),
              label: '${annotation.label} Copy',
            );
            _annotations = <GraphAnnotation>[..._annotations, duplicated];
            _selection = _Selection.annotation(_annotations.length - 1);
            _canvasStatus = 'Item duplicated';
          }
          break;
        case _SelectionKind.segment:
          final index = currentSelection.index;
          if (index >= 0 && index < _wallSegments.length) {
            final segment = _wallSegments[index];
            final duplicated = segment.copyWith(
              start:
                  GraphPoint.fromOffset(segment.start.offset + duplicateOffset),
              end: GraphPoint.fromOffset(segment.end.offset + duplicateOffset),
              controlPoint: segment.controlPoint == null
                  ? null
                  : GraphPoint.fromOffset(
                      segment.controlPoint!.offset + duplicateOffset,
                    ),
            );
            _wallSegments = <WallSegment>[..._wallSegments, duplicated];
            _selection = _Selection.segment(_wallSegments.length - 1);
            _canvasStatus = 'Line duplicated';
          }
          break;
        case _SelectionKind.shape:
          final index = currentSelection.index;
          if (index >= 0 && index < _shapes.length) {
            _duplicateShape(index, duplicateOffset);
          }
          break;
        case _SelectionKind.freehand:
          final index = currentSelection.index;
          if (index >= 0 && index < _freehandStrokes.length) {
            final stroke = _freehandStrokes[index];
            final duplicated = stroke.copyWith(
              points: [
                for (final point in stroke.points)
                  GraphPoint.fromOffset(point.offset + duplicateOffset),
              ],
            );
            _freehandStrokes = <FreehandStroke>[
              ..._freehandStrokes,
              duplicated,
            ];
            _selection = _Selection.freehand(_freehandStrokes.length - 1);
            _canvasStatus = 'Freehand stroke duplicated';
          }
          break;
      }
    });
  }

  void _copySelection() {
    final currentSelection = _selection;
    if (currentSelection == null) {
      _showCanvasMessage('Nothing selected');
      return;
    }

    setState(() {
      _clipboardItem = _ClipboardItem(currentSelection);
      _canvasStatus = 'Copied';
    });
  }

  void _pasteClipboard() {
    final clipboardItem = _clipboardItem;
    if (clipboardItem == null) {
      _showCanvasMessage('Clipboard is empty');
      return;
    }

    _selection = clipboardItem.selection;
    _duplicateSelection();
  }

  void _reorderSelection(_ReorderDirection direction) {
    final currentSelection = _selection;
    if (currentSelection == null) {
      _showCanvasMessage('Nothing selected');
      return;
    }

    _recordSnapshotUndo();
    setState(() {
      switch (currentSelection.kind) {
        case _SelectionKind.annotation:
          _annotations = _reorderedList(
            _annotations,
            currentSelection.index,
            direction,
          );
          _selection = _Selection.annotation(
            _nextReorderIndex(
                _annotations.length, currentSelection.index, direction),
          );
          break;
        case _SelectionKind.shape:
          _shapes = _reorderedList(_shapes, currentSelection.index, direction);
          _selection = _Selection.shape(
            _nextReorderIndex(
                _shapes.length, currentSelection.index, direction),
          );
          break;
        case _SelectionKind.segment:
        case _SelectionKind.freehand:
          _canvasStatus = 'Layer order applies to markers and shapes';
          return;
      }
      _canvasStatus = 'Layer order updated';
    });
  }

  List<T> _reorderedList<T>(
    List<T> items,
    int index,
    _ReorderDirection direction,
  ) {
    if (index < 0 || index >= items.length || items.length < 2) {
      return items;
    }

    final nextItems = <T>[...items];
    final item = nextItems.removeAt(index);
    final nextIndex = _nextReorderIndex(items.length, index, direction);
    nextItems.insert(nextIndex, item);
    return nextItems;
  }

  int _nextReorderIndex(
    int length,
    int index,
    _ReorderDirection direction,
  ) {
    return switch (direction) {
      _ReorderDirection.forward => math.min(index + 1, length - 1),
      _ReorderDirection.backward => math.max(index - 1, 0),
      _ReorderDirection.front => length - 1,
      _ReorderDirection.back => 0,
    };
  }

  void _setSelectedLayerLocked(bool locked) {
    final currentSelection = _selection;
    if (currentSelection == null) {
      _showCanvasMessage('Nothing selected');
      return;
    }

    final layer = _layerForSelection(currentSelection);
    setState(() {
      final current = _layerSettings[layer] ?? const _LayerSettings();
      _setLayerSettings(layer, current.copyWith(locked: locked));
      _canvasStatus =
          '${_layerLabel(layer)} layer ${locked ? 'locked' : 'unlocked'}';
    });
  }

  void _removeSegmentAt(int removedIndex) {
    _wallSegments = <WallSegment>[..._wallSegments]..removeAt(removedIndex);
    final nextShapes = <GraphShape>[];

    for (final shape in _shapes) {
      final nextIndexes = <int>[];

      for (final segmentIndex in shape.segmentIndexes) {
        if (segmentIndex == removedIndex) {
          continue;
        }

        nextIndexes.add(
          segmentIndex > removedIndex ? segmentIndex - 1 : segmentIndex,
        );
      }

      if (nextIndexes.isNotEmpty) {
        nextShapes.add(shape.copyWith(segmentIndexes: nextIndexes));
      }
    }

    _shapes = nextShapes;
  }

  void _duplicateShape(int shapeIndex, Offset duplicateOffset) {
    final shape = _shapes[shapeIndex];
    final newSegmentIndexes = <int>[];
    var nextWallSegments = <WallSegment>[..._wallSegments];

    for (final segmentIndex in shape.segmentIndexes) {
      if (segmentIndex < 0 || segmentIndex >= _wallSegments.length) {
        continue;
      }

      final segment = _wallSegments[segmentIndex];
      final duplicated = segment.copyWith(
        start: GraphPoint.fromOffset(segment.start.offset + duplicateOffset),
        end: GraphPoint.fromOffset(segment.end.offset + duplicateOffset),
        controlPoint: segment.controlPoint == null
            ? null
            : GraphPoint.fromOffset(
                segment.controlPoint!.offset + duplicateOffset),
      );

      newSegmentIndexes.add(nextWallSegments.length);
      nextWallSegments = <WallSegment>[...nextWallSegments, duplicated];
    }

    if (newSegmentIndexes.isEmpty) {
      return;
    }

    _wallSegments = nextWallSegments;
    _shapes = <GraphShape>[
      ..._shapes,
      shape.copyWith(
        name: '${shape.name} Copy',
        segmentIndexes: newSegmentIndexes,
      ),
    ];
    _selection = _Selection.shape(_shapes.length - 1);
    _canvasStatus = 'Shape duplicated';
  }

  Future<void> _confirmClearGraph() async {
    if (_wallSegments.isEmpty &&
        _annotations.isEmpty &&
        _shapes.isEmpty &&
        _freehandStrokes.isEmpty &&
        _activeWallStart == null) {
      _showCanvasMessage('Graph is already clear');
      return;
    }

    if (_hasLockedContent()) {
      _showCanvasMessage('Unlock layers before clearing graph');
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear graph?'),
          content: const Text('This removes all wall segments and items.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldClear != true) {
      return;
    }

    setState(() {
      _wallSegments = <WallSegment>[];
      _annotations = <GraphAnnotation>[];
      _shapes = <GraphShape>[];
      _freehandStrokes = <FreehandStroke>[];
      _undoStack.clear();
      _activeWallStart = null;
      _activePathStartPoint = null;
      _pendingCurveControlPoint = null;
      _previewSegment = null;
      _activePathStartSegmentIndex = null;
      _selection = null;
      _canvasStatus = 'Graph cleared';
    });
  }

  bool _hasLockedContent() {
    final structureLocked = _isLayerLocked(_GraphLayer.structure) &&
        (_wallSegments.isNotEmpty || _freehandStrokes.isNotEmpty);
    final shapesLocked =
        _isLayerLocked(_GraphLayer.shapes) && _shapes.isNotEmpty;
    final findingsLocked = _isLayerLocked(_GraphLayer.findings) &&
        _annotations.any(
          (annotation) => annotation.kind != GraphAnnotationKind.photo,
        );
    final photosLocked = _isLayerLocked(_GraphLayer.photos) &&
        _annotations.any(
          (annotation) => annotation.kind == GraphAnnotationKind.photo,
        );

    return structureLocked || shapesLocked || findingsLocked || photosLocked;
  }

  void _showCanvasMessage(String message) {
    setState(() {
      _canvasStatus = message;
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  void _toggleTraceLayer() {
    setState(() {
      final traceSettings =
          _layerSettings[_GraphLayer.trace] ?? const _LayerSettings();
      final nextVisible = !traceSettings.visible;
      _setLayerSettings(
        _GraphLayer.trace,
        traceSettings.copyWith(visible: nextVisible),
      );
      _canvasStatus = nextVisible ? 'Trace layer on' : 'Trace layer off';
    });
  }

  void _toggleLayerVisibility(_GraphLayer layer) {
    if (layer == _GraphLayer.trace) {
      _toggleTraceLayer();
      return;
    }

    setState(() {
      final current = _layerSettings[layer] ?? const _LayerSettings();
      final nextVisible = !current.visible;
      _setLayerSettings(layer, current.copyWith(visible: nextVisible));

      final selection = _selection;
      if (!nextVisible &&
          selection != null &&
          _selectionBelongsToLayer(selection, layer)) {
        _selection = null;
      }

      _canvasStatus =
          '${_layerLabel(layer)} layer ${nextVisible ? 'shown' : 'hidden'}';
    });
  }

  void _toggleLayerLock(_GraphLayer layer) {
    setState(() {
      final current = _layerSettings[layer] ?? const _LayerSettings();
      final nextLocked = !current.locked;
      _setLayerSettings(layer, current.copyWith(locked: nextLocked));
      _canvasStatus =
          '${_layerLabel(layer)} layer ${nextLocked ? 'locked' : 'unlocked'}';
    });
  }

  void _setLayerSettings(_GraphLayer layer, _LayerSettings settings) {
    _document.setLayer(
      layer.name,
      GraphLayerState(visible: settings.visible, locked: settings.locked),
    );
  }

  void _saveDocument() {
    setState(() {
      _document.markClean();
      _canvasStatus = 'All changes saved';
    });
    _showCanvasMessage('Graph saved');
  }

  void _togglePropertiesCollapsed() {
    setState(() {
      _propertiesCollapsed = !_propertiesCollapsed;
      _canvasStatus =
          _propertiesCollapsed ? 'Properties collapsed' : 'Properties shown';
    });
  }

  void _toggleLayersCollapsed() {
    setState(() {
      _layersCollapsed = !_layersCollapsed;
      _canvasStatus = _layersCollapsed ? 'Layers collapsed' : 'Layers shown';
    });
  }

  bool _selectionBelongsToLayer(_Selection selection, _GraphLayer layer) {
    if (selection.kind == _SelectionKind.annotation &&
        (selection.index < 0 || selection.index >= _annotations.length)) {
      return false;
    }

    return _layerForSelection(selection) == layer;
  }

  String _layerLabel(_GraphLayer layer) {
    return switch (layer) {
      _GraphLayer.structure => 'Structure',
      _GraphLayer.shapes => 'Shapes',
      _GraphLayer.findings => 'Findings',
      _GraphLayer.photos => 'Photos',
      _GraphLayer.trace => 'Trace',
    };
  }

  List<WallSegment> get _previewShapeSegments {
    final start = _shapeDrawStart;
    final current = _shapeDrawCurrent;
    if (start == null ||
        current == null ||
        !_isPresetShapeTool(_selectedTool)) {
      return const <WallSegment>[];
    }

    final rect = _normalizeMinimumRect(
      _rectFromDrag(
        start,
        current,
        forceSquare: _selectedTool == CanvasTool.square ||
            _selectedTool == CanvasTool.circle,
      ),
    );
    return _segmentsForPresetShapeTool(_selectedTool, rect);
  }

  GraphShape? get _previewShape {
    final segments = _previewShapeSegments;
    if (segments.isEmpty) {
      return null;
    }

    return GraphShape(
      name: _defaultShapeName(_selectedTool),
      segmentIndexes: [
        for (var i = 0; i < segments.length; i += 1) i,
      ],
      fillColor: _currentShapeFillColor,
      fillOpacity: _currentShapeFillOpacity,
      borderColor: _currentShapeBorderColor,
      borderWidth: _currentShapeBorderWidth,
      pattern: _currentShapePattern,
      closed: true,
      rotationDegrees: 0,
      preset: _selectedDrawingPreset,
    );
  }

  void _showActionMessage(String label) {
    setState(() {
      _canvasStatus = '$label will be added in the next build step';
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$label will be added in the next build step.'),
        ),
      );
  }

  void _zoomBy(double factor) {
    final currentMatrix = _transformationController.value.clone();
    currentMatrix
      ..setEntry(0, 0, currentMatrix.entry(0, 0) * factor)
      ..setEntry(1, 1, currentMatrix.entry(1, 1) * factor)
      ..setEntry(2, 2, currentMatrix.entry(2, 2) * factor);
    _transformationController.value = currentMatrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _toggleGridVisible() {
    setState(() {
      _gridVisible = !_gridVisible;
      _canvasStatus = _gridVisible ? 'Grid visible' : 'Grid hidden';
    });
  }

  void _toggleSnapToGrid() {
    setState(() {
      _snapToGrid = !_snapToGrid;
      _canvasStatus = _snapToGrid ? 'Snap to grid on' : 'Snap to grid off';
    });
  }

  void _toggleSnapToObjects() {
    setState(() {
      _snapToObjects = !_snapToObjects;
      _canvasStatus =
          _snapToObjects ? 'Snap to objects on' : 'Snap to objects off';
    });
  }

  void _setScaleLabel(String value) {
    setState(() {
      _scaleLabel = value;
      _canvasStatus = 'Scale set to $value';
    });
  }

  void _updateAnnotationLabel(int index, String label) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }

    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(label: label);

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = 'Label updated';
    });
  }

  void _updateAnnotationMarkerType(int index, GraphMarkerType markerType) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }
    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final markerDefault = _markerDefaultsFor(markerType);
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(
      markerType: markerType,
      color: markerDefault.color,
      size: markerDefault.size,
      label: markerType.shortLabel,
    );

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = 'Marker type updated';
    });
  }

  void _updateAnnotationColor(int index, Color color) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }
    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(color: color);

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = 'Marker color updated';
    });
  }

  void _updateAnnotationSize(int index, double size) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }
    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(size: size);

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = 'Marker size updated';
    });
  }

  void _updateAnnotationRotation(int index, double rotationDegrees) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }
    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(
      rotationDegrees: rotationDegrees,
    );

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = 'Marker rotation updated';
    });
  }

  void _updateAnnotationNote(int index, String note) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }
    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(note: note);

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = 'Note updated';
    });
  }

  void _updateTextFontSize(int index, double fontSize) {
    _updateTextStyle(index, fontSize: fontSize, status: 'Text size updated');
  }

  void _updateTextBold(int index, bool bold) {
    _updateTextStyle(index, bold: bold, status: 'Text weight updated');
  }

  void _updateTextItalic(int index, bool italic) {
    _updateTextStyle(index, italic: italic, status: 'Text style updated');
  }

  void _updateTextColor(int index, Color color) {
    _updateTextStyle(index, textColor: color, status: 'Text color updated');
  }

  void _updateTextBackground(int index, Color color) {
    _updateTextStyle(
      index,
      backgroundColor: color,
      status: 'Text background updated',
    );
  }

  void _updateTextBorder(int index, Color color) {
    _updateTextStyle(index, borderColor: color, status: 'Text border updated');
  }

  void _updateTextStyle(
    int index, {
    double? fontSize,
    bool? bold,
    bool? italic,
    Color? textColor,
    Color? backgroundColor,
    Color? borderColor,
    required String status,
  }) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }
    if (_isAnnotationLocked(_annotations[index])) {
      _showCanvasMessage('Selected layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextAnnotations = <GraphAnnotation>[..._annotations];
    nextAnnotations[index] = nextAnnotations[index].copyWith(
      fontSize: fontSize,
      bold: bold,
      italic: italic,
      textColor: textColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
    );

    setState(() {
      _annotations = nextAnnotations;
      _canvasStatus = status;
    });
  }

  void _setMarkerDefault(int index) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }

    final annotation = _annotations[index];
    if (annotation.kind != GraphAnnotationKind.marker) {
      return;
    }

    setState(() {
      _markerDefaults[annotation.markerType] = _MarkerStyleDefaults(
        color: annotation.color ?? annotation.markerType.defaultColor,
        size: annotation.size,
      );
      _interaction.selectMarker(annotation.markerType);
      _selectedMarkerColor =
          annotation.color ?? annotation.markerType.defaultColor;
      _selectedMarkerSize = annotation.size;
      _canvasStatus =
          '${annotation.markerType.shortLabel} set as marker default';
    });
  }

  void _setTextDefault(int index) {
    if (index < 0 || index >= _annotations.length) {
      return;
    }

    final annotation = _annotations[index];
    if (annotation.kind != GraphAnnotationKind.text) {
      return;
    }

    setState(() {
      _defaultTextFontSize = annotation.fontSize;
      _defaultTextColor = annotation.textColor;
      _defaultTextBackground = annotation.backgroundColor;
      _defaultTextBorder = annotation.borderColor;
      _canvasStatus = 'Text style set as default';
    });
  }

  void _setLineDefault(int index) {
    if (index < 0 || index >= _wallSegments.length) {
      return;
    }

    final segment = _wallSegments[index];
    setState(() {
      final preset = _selectedDrawingPreset;
      if (preset != null && preset.kind == GraphDrawingPresetKind.line) {
        final current = _drawingDefaultsFor(preset);
        _drawingPresetDefaults[preset] = current.copyWith(
          lineColor: segment.color,
          lineWidth: segment.strokeWidth,
          linePattern: segment.pattern,
        );
        _canvasStatus = '${preset.label} line style set as default';
      } else {
        if (segment.hasArrow) {
          _defaultArrowColor = segment.color;
          _defaultArrowWidth = segment.strokeWidth;
          _defaultArrowPattern = segment.pattern;
          _canvasStatus = 'Arrow style set as default';
        } else {
          _defaultLineColor = segment.color;
          _defaultLineWidth = segment.strokeWidth;
          _defaultLinePattern = segment.pattern;
          _canvasStatus = 'Line style set as default';
        }
      }
    });
  }

  void _setShapeDefault(int index) {
    if (index < 0 || index >= _shapes.length) {
      return;
    }

    final shape = _shapes[index];
    setState(() {
      final preset = shape.preset;
      if (preset != null && preset.kind == GraphDrawingPresetKind.area) {
        final current = _drawingDefaultsFor(preset);
        _drawingPresetDefaults[preset] = current.copyWith(
          fillColor: shape.fillColor,
          clearFillColor: shape.fillColor == null,
          fillOpacity: shape.fillOpacity,
          borderColor: shape.borderColor,
          borderWidth: shape.borderWidth,
          pattern: shape.pattern,
        );
        _canvasStatus = '${preset.label} style set as default';
      } else {
        _defaultShapeFillColor = shape.fillColor;
        _defaultShapeFillOpacity = shape.fillOpacity;
        _defaultShapeBorderColor = shape.borderColor;
        _defaultShapeBorderWidth = shape.borderWidth;
        _defaultShapePattern = shape.pattern;
        _canvasStatus = 'Shape style set as default';
      }
    });
  }

  void _setFreehandDefault(int index) {
    if (index < 0 || index >= _freehandStrokes.length) {
      return;
    }

    final stroke = _freehandStrokes[index];
    setState(() {
      _defaultFreehandColor = stroke.color;
      _defaultFreehandWidth = stroke.strokeWidth;
      _defaultFreehandOpacity = stroke.opacity;
      _canvasStatus = 'Freehand style set as default';
    });
  }

  void _updateSegmentColor(int index, Color color) {
    if (index < 0 || index >= _wallSegments.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextSegments = <WallSegment>[..._wallSegments];
    nextSegments[index] = nextSegments[index].copyWith(color: color);
    setState(() {
      _wallSegments = nextSegments;
      _canvasStatus = 'Line color updated';
    });
  }

  void _updateSegmentPattern(int index, LinePattern pattern) {
    if (index < 0 || index >= _wallSegments.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextSegments = <WallSegment>[..._wallSegments];
    nextSegments[index] = nextSegments[index].copyWith(pattern: pattern);
    setState(() {
      _wallSegments = nextSegments;
      _canvasStatus = 'Line pattern updated';
    });
  }

  void _updateSegmentWidth(int index, double strokeWidth) {
    if (index < 0 || index >= _wallSegments.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextSegments = <WallSegment>[..._wallSegments];
    nextSegments[index] =
        nextSegments[index].copyWith(strokeWidth: strokeWidth);
    setState(() {
      _wallSegments = nextSegments;
      _canvasStatus = 'Line width updated';
    });
  }

  void _updateSegmentArrow(int index, bool hasArrow) {
    if (index < 0 || index >= _wallSegments.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextSegments = <WallSegment>[..._wallSegments];
    nextSegments[index] = nextSegments[index].copyWith(hasArrow: hasArrow);
    setState(() {
      _wallSegments = nextSegments;
      _canvasStatus = hasArrow ? 'Arrow enabled' : 'Arrow disabled';
    });
  }

  void _updateFreehandColor(int index, Color color) {
    if (index < 0 || index >= _freehandStrokes.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextStrokes = <FreehandStroke>[..._freehandStrokes];
    nextStrokes[index] = nextStrokes[index].copyWith(color: color);
    setState(() {
      _freehandStrokes = nextStrokes;
      _canvasStatus = 'Freehand color updated';
    });
  }

  void _updateFreehandWidth(int index, double strokeWidth) {
    if (index < 0 || index >= _freehandStrokes.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextStrokes = <FreehandStroke>[..._freehandStrokes];
    nextStrokes[index] = nextStrokes[index].copyWith(strokeWidth: strokeWidth);
    setState(() {
      _freehandStrokes = nextStrokes;
      _canvasStatus = 'Freehand width updated';
    });
  }

  void _updateFreehandOpacity(int index, double opacity) {
    if (index < 0 || index >= _freehandStrokes.length) {
      return;
    }
    if (_isLayerLocked(_GraphLayer.structure)) {
      _showCanvasMessage('Structure layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextStrokes = <FreehandStroke>[..._freehandStrokes];
    nextStrokes[index] = nextStrokes[index].copyWith(opacity: opacity);
    setState(() {
      _freehandStrokes = nextStrokes;
      _canvasStatus = 'Freehand opacity updated';
    });
  }

  void _updateShapeName(int index, String name) {
    if (index < 0 || index >= _shapes.length) {
      return;
    }

    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextShapes = <GraphShape>[..._shapes];
    nextShapes[index] = nextShapes[index].copyWith(name: name);

    setState(() {
      _shapes = nextShapes;
      _canvasStatus = 'Shape name updated';
    });
  }

  void _updateShapeFill(int index, Color? fillColor) {
    if (index < 0 || index >= _shapes.length) {
      return;
    }

    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextShapes = <GraphShape>[..._shapes];
    nextShapes[index] = nextShapes[index].copyWith(
      fillColor: fillColor,
      clearFillColor: fillColor == null,
      fillOpacity: _fillOpacityForColor(fillColor),
    );

    setState(() {
      _shapes = nextShapes;
      _canvasStatus = 'Shape fill updated';
    });
  }

  double _fillOpacityForColor(Color? color) {
    for (final choice in _ShapeFillChoice.values) {
      if (choice.color == color) {
        return choice.opacity;
      }
    }

    return color == null ? 0 : 0.32;
  }

  _ShapeFillChoice _shapeFillChoiceForColor(Color? color) {
    for (final choice in _ShapeFillChoice.values) {
      if (choice.color == color) {
        return choice;
      }
    }

    return _ShapeFillChoice.none;
  }

  _ShapeBorderChoice _shapeBorderChoiceForColor(Color color) {
    for (final choice in _ShapeBorderChoice.values) {
      if (choice.color == color) {
        return choice;
      }
    }

    return _ShapeBorderChoice.darkGreen;
  }

  void _updateShapeBorderColor(int index, Color borderColor) {
    if (index < 0 || index >= _shapes.length) {
      return;
    }

    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextShapes = <GraphShape>[..._shapes];
    nextShapes[index] = nextShapes[index].copyWith(borderColor: borderColor);

    setState(() {
      _shapes = nextShapes;
      _canvasStatus = 'Shape border updated';
    });
  }

  void _updateShapeBorderWidth(int index, double borderWidth) {
    if (index < 0 || index >= _shapes.length) {
      return;
    }

    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextShapes = <GraphShape>[..._shapes];
    nextShapes[index] = nextShapes[index].copyWith(borderWidth: borderWidth);

    setState(() {
      _shapes = nextShapes;
      _canvasStatus = 'Shape border width updated';
    });
  }

  void _updateShapePattern(int index, GraphShapePattern pattern) {
    if (index < 0 || index >= _shapes.length) {
      return;
    }

    if (_isLayerLocked(_GraphLayer.shapes)) {
      _showCanvasMessage('Shapes layer is locked');
      return;
    }

    _recordSnapshotUndo();
    final nextShapes = <GraphShape>[..._shapes];
    nextShapes[index] = nextShapes[index].copyWith(pattern: pattern);

    setState(() {
      _shapes = nextShapes;
      _canvasStatus = 'Shape pattern updated';
    });
  }

  void _recordSnapshotUndo() {
    if (_applyingHistory) {
      return;
    }
    _undoStack.add(
      _UndoEntry(
        _UndoKind.snapshot,
        previousSnapshot: _EditorSnapshot.capture(this),
      ),
    );
    _redoStack.clear();
  }

  MouseCursor get _canvasCursor {
    final hovered = _hoverSelection;
    if (hovered != null) {
      return _isSelectionEditable(hovered)
          ? SystemMouseCursors.move
          : SystemMouseCursors.click;
    }
    if (_interaction.dragging) {
      return SystemMouseCursors.grabbing;
    }
    return switch (_selectedTool) {
      CanvasTool.pan => SystemMouseCursors.grab,
      CanvasTool.structure ||
      CanvasTool.rectangle ||
      CanvasTool.square ||
      CanvasTool.circle ||
      CanvasTool.ellipse ||
      CanvasTool.triangle ||
      CanvasTool.wall ||
      CanvasTool.arrow ||
      CanvasTool.curve ||
      CanvasTool.freehand ||
      CanvasTool.marker ||
      CanvasTool.photo =>
        SystemMouseCursors.precise,
      CanvasTool.text => SystemMouseCursors.text,
      CanvasTool.select => SystemMouseCursors.basic,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sidePanelWidth = _propertiesCollapsed ? 44.0 : 268.0;
    final canvasRightInset = _propertiesCollapsed ? 68.0 : 292.0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          _document.isDirty
              ? '${_document.customer.name} • Unsaved'
              : _document.customer.name,
        ),
      ),
      body: Focus(
        focusNode: _editorFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      left: 96,
                      top: 54,
                      right: canvasRightInset,
                      bottom: 12,
                      child: MouseRegion(
                        cursor: _canvasCursor,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: _handlePointerDown,
                          onPointerMove: _handlePointerMove,
                          onPointerHover: _handlePointerHover,
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            panEnabled: _selectedTool == CanvasTool.pan,
                            scaleEnabled: true,
                            constrained: false,
                            minScale: 0.25,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(1200),
                            child: _CanvasSurface(
                              canvasSize: _canvasSize,
                              wallSegments: _wallSegments,
                              annotations: _annotations,
                              shapes: _shapes,
                              freehandStrokes: _freehandStrokes,
                              draftFreehandPoints: _draftFreehandPoints,
                              previewShapeSegments: _previewShapeSegments,
                              previewShape: _previewShape,
                              hiddenSegmentIndexes: _shapeSegmentIndexSet,
                              gridVisible: _gridVisible,
                              selectedSegmentIndex: _selection?.segmentIndex,
                              selectedAnnotationIndex:
                                  _selection?.annotationIndex,
                              selectedShapeIndex: _selection?.shapeIndex,
                              selectedFreehandIndex: _selection?.freehandIndex,
                              hoveredSegmentIndex:
                                  _hoverSelection?.segmentIndex,
                              hoveredAnnotationIndex:
                                  _hoverSelection?.annotationIndex,
                              hoveredShapeIndex: _hoverSelection?.shapeIndex,
                              hoveredFreehandIndex:
                                  _hoverSelection?.freehandIndex,
                              activeWallStart: _activeWallStart,
                              previewSegment: _previewSegment,
                              structureVisible:
                                  _isLayerVisible(_GraphLayer.structure),
                              shapesVisible:
                                  _isLayerVisible(_GraphLayer.shapes),
                              findingsVisible:
                                  _isLayerVisible(_GraphLayer.findings),
                              photosVisible:
                                  _isLayerVisible(_GraphLayer.photos),
                              traceLayerVisible: _traceLayerVisible,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 54,
                      bottom: 12,
                      width: 72,
                      child: CanvasToolbar(
                        selectedTool: _selectedTool,
                        selectedMarkerType: _selectedMarkerType,
                        selectedDrawingPreset: _selectedStructureType,
                        onToolSelected: _selectTool,
                        onMarkerSelected: _selectMarker,
                        onDrawingPresetSelected: _selectDrawingPreset,
                        traceLayerVisible: _traceLayerVisible,
                        onToggleTraceLayer: _toggleTraceLayer,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 8,
                      child: Tooltip(
                        message: _canvasStatus,
                        child: _TopEditorToolbar(
                          onUndo: _undoLastAction,
                          onRedo: _redoLastAction,
                          onFinish: _finishWallPath,
                          onClear: _confirmClearGraph,
                          onSave: _saveDocument,
                          onExport: () => _showActionMessage('Export'),
                          onUpload: () => _showActionMessage('Upload'),
                          onZoomIn: () => _zoomBy(1.2),
                          onZoomOut: () => _zoomBy(0.85),
                          onResetZoom: _resetZoom,
                          gridVisible: _gridVisible,
                          onToggleGrid: _toggleGridVisible,
                          snapToGrid: _snapToGrid,
                          onToggleSnapToGrid: _toggleSnapToGrid,
                          snapToObjects: _snapToObjects,
                          onToggleSnapToObjects: _toggleSnapToObjects,
                          scaleLabel: _scaleLabel,
                          onScaleChanged: _setScaleLabel,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 54,
                      right: 12,
                      bottom: 12,
                      width: sidePanelWidth,
                      child: _propertiesCollapsed
                          ? _CollapsedPanelTab(
                              icon: Icons.tune,
                              label: 'Props',
                              onPressed: _togglePropertiesCollapsed,
                            )
                          : _PropertiesSidebar(
                              selection: _selection,
                              annotations: _annotations,
                              wallSegments: _wallSegments,
                              shapes: _shapes,
                              freehandStrokes: _freehandStrokes,
                              layerSettings: _layerSettings,
                              traceLayerVisible: _traceLayerVisible,
                              layersCollapsed: _layersCollapsed,
                              onCollapsePanel: _togglePropertiesCollapsed,
                              onToggleLayersCollapsed: _toggleLayersCollapsed,
                              onToggleLayerVisibility: _toggleLayerVisibility,
                              onToggleLayerLock: _toggleLayerLock,
                              onAnnotationLabelChanged: _updateAnnotationLabel,
                              onAnnotationMarkerTypeChanged:
                                  _updateAnnotationMarkerType,
                              onAnnotationColorChanged: _updateAnnotationColor,
                              onAnnotationSizeChanged: _updateAnnotationSize,
                              onAnnotationRotationChanged:
                                  _updateAnnotationRotation,
                              onAnnotationNoteChanged: _updateAnnotationNote,
                              onTextFontSizeChanged: _updateTextFontSize,
                              onTextBoldChanged: _updateTextBold,
                              onTextItalicChanged: _updateTextItalic,
                              onTextColorChanged: _updateTextColor,
                              onTextBackgroundChanged: _updateTextBackground,
                              onTextBorderChanged: _updateTextBorder,
                              onSetMarkerDefault: _setMarkerDefault,
                              onSetTextDefault: _setTextDefault,
                              onSegmentColorChanged: _updateSegmentColor,
                              onSegmentPatternChanged: _updateSegmentPattern,
                              onSegmentWidthChanged: _updateSegmentWidth,
                              onSegmentArrowChanged: _updateSegmentArrow,
                              onSetLineDefault: _setLineDefault,
                              onFreehandColorChanged: _updateFreehandColor,
                              onFreehandWidthChanged: _updateFreehandWidth,
                              onFreehandOpacityChanged: _updateFreehandOpacity,
                              onSetFreehandDefault: _setFreehandDefault,
                              onShapeNameChanged: _updateShapeName,
                              onShapeFillChanged: _updateShapeFill,
                              onShapeBorderColorChanged:
                                  _updateShapeBorderColor,
                              onShapeBorderWidthChanged:
                                  _updateShapeBorderWidth,
                              onShapePatternChanged: _updateShapePattern,
                              onSetShapeDefault: _setShapeDefault,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopEditorToolbar extends StatelessWidget {
  const _TopEditorToolbar({
    required this.onUndo,
    required this.onRedo,
    required this.onFinish,
    required this.onClear,
    required this.onSave,
    required this.onExport,
    required this.onUpload,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.gridVisible,
    required this.onToggleGrid,
    required this.snapToGrid,
    required this.onToggleSnapToGrid,
    required this.snapToObjects,
    required this.onToggleSnapToObjects,
    required this.scaleLabel,
    required this.onScaleChanged,
  });

  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFinish;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onUpload;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final bool gridVisible;
  final VoidCallback onToggleGrid;
  final bool snapToGrid;
  final VoidCallback onToggleSnapToGrid;
  final bool snapToObjects;
  final VoidCallback onToggleSnapToObjects;
  final String scaleLabel;
  final ValueChanged<String> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: SizedBox(
        height: 46,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _TopButton(icon: Icons.undo, label: 'Undo', onPressed: onUndo),
              _TopButton(icon: Icons.redo, label: 'Redo', onPressed: onRedo),
              const _ToolbarDivider(),
              _TopButton(
                  icon: Icons.done, label: 'Finish', onPressed: onFinish),
              _TopButton(
                icon: Icons.delete_outline,
                label: 'Clear',
                onPressed: onClear,
              ),
              const _ToolbarDivider(),
              _TopButton(
                icon: Icons.save_outlined,
                label: 'Save',
                onPressed: onSave,
              ),
              _TopButton(
                icon: Icons.ios_share,
                label: 'Export',
                onPressed: onExport,
              ),
              _TopButton(
                icon: Icons.cloud_upload_outlined,
                label: 'Upload',
                onPressed: onUpload,
              ),
              const _ToolbarDivider(),
              _IconOnlyButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: onZoomOut,
              ),
              _TopButton(
                icon: Icons.fit_screen,
                label: 'Reset',
                onPressed: onResetZoom,
              ),
              _IconOnlyButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: onZoomIn,
              ),
              const _ToolbarDivider(),
              _ToggleButton(
                label: 'Grid',
                selected: gridVisible,
                onPressed: onToggleGrid,
              ),
              _ToggleButton(
                label: 'Snap Grid',
                selected: snapToGrid,
                onPressed: onToggleSnapToGrid,
              ),
              _ToggleButton(
                label: 'Snap Obj',
                selected: snapToObjects,
                onPressed: onToggleSnapToObjects,
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: scaleLabel,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: '1:1', child: Text('1:1')),
                  DropdownMenuItem(value: '2:1', child: Text('2:1')),
                  DropdownMenuItem(value: '3:1', child: Text('3:1')),
                  DropdownMenuItem(value: '4:1', child: Text('4:1')),
                  DropdownMenuItem(value: '10:1', child: Text('10:1')),
                  DropdownMenuItem(value: '20:1', child: Text('20:1')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onScaleChanged(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _IconOnlyButton extends StatelessWidget {
  const _IconOnlyButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onPressed(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE3E0D8),
    );
  }
}

class _CollapsedPanelTab extends StatelessWidget {
  const _CollapsedPanelTab({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertiesSidebar extends StatelessWidget {
  const _PropertiesSidebar({
    required this.selection,
    required this.annotations,
    required this.wallSegments,
    required this.shapes,
    required this.freehandStrokes,
    required this.layerSettings,
    required this.traceLayerVisible,
    required this.layersCollapsed,
    required this.onCollapsePanel,
    required this.onToggleLayersCollapsed,
    required this.onToggleLayerVisibility,
    required this.onToggleLayerLock,
    required this.onAnnotationLabelChanged,
    required this.onAnnotationMarkerTypeChanged,
    required this.onAnnotationColorChanged,
    required this.onAnnotationSizeChanged,
    required this.onAnnotationRotationChanged,
    required this.onAnnotationNoteChanged,
    required this.onTextFontSizeChanged,
    required this.onTextBoldChanged,
    required this.onTextItalicChanged,
    required this.onTextColorChanged,
    required this.onTextBackgroundChanged,
    required this.onTextBorderChanged,
    required this.onSetMarkerDefault,
    required this.onSetTextDefault,
    required this.onSegmentColorChanged,
    required this.onSegmentPatternChanged,
    required this.onSegmentWidthChanged,
    required this.onSegmentArrowChanged,
    required this.onSetLineDefault,
    required this.onFreehandColorChanged,
    required this.onFreehandWidthChanged,
    required this.onFreehandOpacityChanged,
    required this.onSetFreehandDefault,
    required this.onShapeNameChanged,
    required this.onShapeFillChanged,
    required this.onShapeBorderColorChanged,
    required this.onShapeBorderWidthChanged,
    required this.onShapePatternChanged,
    required this.onSetShapeDefault,
  });

  final _Selection? selection;
  final List<GraphAnnotation> annotations;
  final List<WallSegment> wallSegments;
  final List<GraphShape> shapes;
  final List<FreehandStroke> freehandStrokes;
  final Map<_GraphLayer, _LayerSettings> layerSettings;
  final bool traceLayerVisible;
  final bool layersCollapsed;
  final VoidCallback onCollapsePanel;
  final VoidCallback onToggleLayersCollapsed;
  final ValueChanged<_GraphLayer> onToggleLayerVisibility;
  final ValueChanged<_GraphLayer> onToggleLayerLock;
  final void Function(int index, String label) onAnnotationLabelChanged;
  final void Function(int index, GraphMarkerType markerType)
      onAnnotationMarkerTypeChanged;
  final void Function(int index, Color color) onAnnotationColorChanged;
  final void Function(int index, double size) onAnnotationSizeChanged;
  final void Function(int index, double rotationDegrees)
      onAnnotationRotationChanged;
  final void Function(int index, String note) onAnnotationNoteChanged;
  final void Function(int index, double fontSize) onTextFontSizeChanged;
  final void Function(int index, bool bold) onTextBoldChanged;
  final void Function(int index, bool italic) onTextItalicChanged;
  final void Function(int index, Color color) onTextColorChanged;
  final void Function(int index, Color color) onTextBackgroundChanged;
  final void Function(int index, Color color) onTextBorderChanged;
  final ValueChanged<int> onSetMarkerDefault;
  final ValueChanged<int> onSetTextDefault;
  final void Function(int index, Color color) onSegmentColorChanged;
  final void Function(int index, LinePattern pattern) onSegmentPatternChanged;
  final void Function(int index, double strokeWidth) onSegmentWidthChanged;
  final void Function(int index, bool hasArrow) onSegmentArrowChanged;
  final ValueChanged<int> onSetLineDefault;
  final void Function(int index, Color color) onFreehandColorChanged;
  final void Function(int index, double strokeWidth) onFreehandWidthChanged;
  final void Function(int index, double opacity) onFreehandOpacityChanged;
  final ValueChanged<int> onSetFreehandDefault;
  final void Function(int index, String name) onShapeNameChanged;
  final void Function(int index, Color? fillColor) onShapeFillChanged;
  final void Function(int index, Color borderColor) onShapeBorderColorChanged;
  final void Function(int index, double borderWidth) onShapeBorderWidthChanged;
  final void Function(int index, GraphShapePattern pattern)
      onShapePatternChanged;
  final ValueChanged<int> onSetShapeDefault;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Properties',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Collapse properties',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCollapsePanel,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildContent(context)),
            const Divider(height: 20),
            if (layersCollapsed)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onToggleLayersCollapsed,
                  icon: const Icon(Icons.layers_outlined),
                  label: const Text('Show Layers'),
                ),
              )
            else
              _LayersPanel(
                wallCount: wallSegments.length,
                shapeCount: shapes.length,
                itemCount: annotations
                    .where(
                      (annotation) =>
                          annotation.kind != GraphAnnotationKind.photo,
                    )
                    .length,
                photoCount: annotations
                    .where(
                      (annotation) =>
                          annotation.kind == GraphAnnotationKind.photo,
                    )
                    .length,
                layerSettings: layerSettings,
                traceLayerVisible: traceLayerVisible,
                onCollapse: onToggleLayersCollapsed,
                onToggleVisibility: onToggleLayerVisibility,
                onToggleLock: onToggleLayerLock,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final currentSelection = selection;

    if (currentSelection == null) {
      return _InspectorSection(
        title: 'Properties',
        children: [
          Text(
            'Select an object to edit its properties.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const _InspectorValue(label: 'Editor', value: 'Drawings mode'),
        ],
      );
    }

    if (currentSelection.annotationIndex case final index?
        when index < annotations.length) {
      final annotation = annotations[index];
      final annotationLocked = _isLayerLocked(_layerForAnnotation(annotation));
      return _InspectorSection(
        title: 'Item Properties',
        children: [
          _InspectorValue(label: 'Type', value: annotation.kind.name),
          const SizedBox(height: 10),
          if (annotation.kind == GraphAnnotationKind.marker) ...[
            DropdownButtonFormField<GraphMarkerType>(
              initialValue: annotation.markerType,
              decoration: const InputDecoration(labelText: 'Marker type'),
              items: GraphMarkerType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: annotationLocked
                  ? null
                  : (value) {
                      if (value != null) {
                        onAnnotationMarkerTypeChanged(index, value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<_MarkerColorChoice>(
              initialValue: _markerColorChoiceForColor(
                annotation.color ?? annotation.markerType.defaultColor,
              ),
              decoration: const InputDecoration(labelText: 'Color'),
              items: _MarkerColorChoice.values
                  .map(
                    (choice) => DropdownMenuItem(
                      value: choice,
                      child: _ColorChoiceLabel(
                        label: choice.label,
                        color: choice.color,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: annotationLocked
                  ? null
                  : (choice) {
                      if (choice != null) {
                        onAnnotationColorChanged(index, choice.color);
                      }
                    },
            ),
            const SizedBox(height: 10),
            _LabeledSlider(
              label: 'Size',
              value: annotation.size,
              min: 0.7,
              max: 1.8,
              enabled: !annotationLocked,
              onChanged: (value) => onAnnotationSizeChanged(index, value),
            ),
            _LabeledSlider(
              label: 'Rotation',
              value: annotation.rotationDegrees,
              min: 0,
              max: 360,
              enabled: !annotationLocked,
              onChanged: (value) => onAnnotationRotationChanged(index, value),
            ),
          ],
          if (annotation.kind == GraphAnnotationKind.text) ...[
            _LabeledSlider(
              label: 'Font',
              value: annotation.fontSize,
              min: 10,
              max: 32,
              enabled: !annotationLocked,
              onChanged: (value) => onTextFontSizeChanged(index, value),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Bold'),
                  selected: annotation.bold,
                  onSelected: annotationLocked
                      ? null
                      : (value) => onTextBoldChanged(index, value),
                ),
                FilterChip(
                  label: const Text('Italic'),
                  selected: annotation.italic,
                  onSelected: annotationLocked
                      ? null
                      : (value) => onTextItalicChanged(index, value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<_MarkerColorChoice>(
              initialValue: _markerColorChoiceForColor(annotation.textColor),
              decoration: const InputDecoration(labelText: 'Text color'),
              items: _MarkerColorChoice.values
                  .map(
                    (choice) => DropdownMenuItem(
                      value: choice,
                      child: _ColorChoiceLabel(
                        label: choice.label,
                        color: choice.color,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: annotationLocked
                  ? null
                  : (choice) {
                      if (choice != null) {
                        onTextColorChanged(index, choice.color);
                      }
                    },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<_ShapeFillChoice>(
              initialValue: _fillChoiceForColor(annotation.backgroundColor),
              decoration: const InputDecoration(labelText: 'Background'),
              items: _ShapeFillChoice.values
                  .where((choice) => choice.color != null)
                  .map(
                    (choice) => DropdownMenuItem(
                      value: choice,
                      child: _ColorChoiceLabel(
                        label: choice.label,
                        color: choice.color,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: annotationLocked
                  ? null
                  : (choice) {
                      if (choice?.color != null) {
                        onTextBackgroundChanged(index, choice!.color!);
                      }
                    },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<_MarkerColorChoice>(
              initialValue: _markerColorChoiceForColor(annotation.borderColor),
              decoration: const InputDecoration(labelText: 'Border'),
              items: _MarkerColorChoice.values
                  .map(
                    (choice) => DropdownMenuItem(
                      value: choice,
                      child: _ColorChoiceLabel(
                        label: choice.label,
                        color: choice.color,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: annotationLocked
                  ? null
                  : (choice) {
                      if (choice != null) {
                        onTextBorderChanged(index, choice.color);
                      }
                    },
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed:
                  annotationLocked ? null : () => onSetTextDefault(index),
              child: const Text('Set as Default'),
            ),
            const SizedBox(height: 10),
          ],
          TextFormField(
            key: ValueKey('annotation-$index'),
            initialValue: annotation.label,
            decoration: const InputDecoration(labelText: 'Label'),
            enabled: !annotationLocked,
            onChanged: annotationLocked
                ? null
                : (value) => onAnnotationLabelChanged(index, value),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('annotation-note-$index'),
            initialValue: annotation.note,
            decoration: const InputDecoration(labelText: 'Notes'),
            enabled: !annotationLocked,
            maxLines: 2,
            onChanged: annotationLocked
                ? null
                : (value) => onAnnotationNoteChanged(index, value),
          ),
          if (annotation.kind == GraphAnnotationKind.marker) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed:
                  annotationLocked ? null : () => onSetMarkerDefault(index),
              child: const Text('Set as Default'),
            ),
          ],
          const SizedBox(height: 10),
          _InspectorValue(
            label: 'Position',
            value:
                '${annotation.point.x.round()}, ${annotation.point.y.round()}',
          ),
        ],
      );
    }

    if (currentSelection.segmentIndex case final index?
        when index < wallSegments.length) {
      final segment = wallSegments[index];
      final structureLocked = _isLayerLocked(_GraphLayer.structure);
      return _InspectorSection(
        title: 'Line Properties',
        children: [
          _InspectorValue(
            label: 'Type',
            value: segment.hasArrow
                ? 'Arrow'
                : segment.isCurve
                    ? 'Curve'
                    : 'Straight line',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_MarkerColorChoice>(
            initialValue: _markerColorChoiceForColor(segment.color),
            decoration: const InputDecoration(labelText: 'Color'),
            items: _MarkerColorChoice.values
                .map(
                  (choice) => DropdownMenuItem(
                    value: choice,
                    child: _ColorChoiceLabel(
                      label: choice.label,
                      color: choice.color,
                    ),
                  ),
                )
                .toList(),
            onChanged: structureLocked
                ? null
                : (choice) {
                    if (choice != null) {
                      onSegmentColorChanged(index, choice.color);
                    }
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<LinePattern>(
            initialValue: segment.pattern,
            decoration: const InputDecoration(labelText: 'Line style'),
            items: LinePattern.values
                .map(
                  (pattern) => DropdownMenuItem(
                    value: pattern,
                    child: Text(pattern.label),
                  ),
                )
                .toList(),
            onChanged: structureLocked
                ? null
                : (pattern) {
                    if (pattern != null) {
                      onSegmentPatternChanged(index, pattern);
                    }
                  },
          ),
          _LabeledSlider(
            label: 'Width',
            value: segment.strokeWidth,
            min: 2,
            max: 10,
            enabled: !structureLocked,
            onChanged: (value) => onSegmentWidthChanged(index, value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Arrow head'),
            value: segment.hasArrow,
            onChanged: structureLocked
                ? null
                : (value) => onSegmentArrowChanged(index, value),
          ),
          OutlinedButton(
            onPressed: structureLocked ? null : () => onSetLineDefault(index),
            child: const Text('Set as Default'),
          ),
          const SizedBox(height: 8),
          _InspectorValue(label: 'Length', value: segment.measurementLabel),
          const SizedBox(height: 8),
          _InspectorValue(
            label: 'Start',
            value: '${segment.start.x.round()}, ${segment.start.y.round()}',
          ),
          const SizedBox(height: 8),
          _InspectorValue(
            label: 'End',
            value: '${segment.end.x.round()}, ${segment.end.y.round()}',
          ),
        ],
      );
    }

    if (currentSelection.shapeIndex case final index?
        when index < shapes.length) {
      final shape = shapes[index];
      final shapeLocked = _isLayerLocked(_GraphLayer.shapes);
      return _InspectorSection(
        title: 'Shape Properties',
        children: [
          _InspectorValue(
            label: 'Preset',
            value: shape.preset?.label ?? 'Custom',
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('shape-$index'),
            initialValue: shape.name,
            decoration: const InputDecoration(labelText: 'Name'),
            enabled: !shapeLocked,
            onChanged: shapeLocked
                ? null
                : (value) => onShapeNameChanged(index, value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_ShapeFillChoice>(
            initialValue: _fillChoiceForColor(shape.fillColor),
            decoration: const InputDecoration(labelText: 'Fill'),
            items: _ShapeFillChoice.values
                .map(
                  (choice) => DropdownMenuItem(
                    value: choice,
                    child: _ColorChoiceLabel(
                      label: choice.label,
                      color: choice.color,
                    ),
                  ),
                )
                .toList(),
            onChanged: shapeLocked
                ? null
                : (choice) {
                    if (choice != null) {
                      onShapeFillChanged(index, choice.color);
                    }
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_ShapeBorderChoice>(
            initialValue: _borderChoiceForColor(shape.borderColor),
            decoration: const InputDecoration(labelText: 'Border'),
            items: _ShapeBorderChoice.values
                .map(
                  (choice) => DropdownMenuItem(
                    value: choice,
                    child: _ColorChoiceLabel(
                      label: choice.label,
                      color: choice.color,
                    ),
                  ),
                )
                .toList(),
            onChanged: shapeLocked
                ? null
                : (choice) {
                    if (choice != null) {
                      onShapeBorderColorChanged(index, choice.color);
                    }
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<double>(
            initialValue: shape.borderWidth,
            decoration: const InputDecoration(labelText: 'Border width'),
            items: const [
              DropdownMenuItem(value: 2.0, child: Text('Thin')),
              DropdownMenuItem(value: 3.0, child: Text('Medium')),
              DropdownMenuItem(value: 5.0, child: Text('Heavy')),
            ],
            onChanged: shapeLocked
                ? null
                : (value) {
                    if (value != null) {
                      onShapeBorderWidthChanged(index, value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<GraphShapePattern>(
            initialValue: shape.pattern,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pattern'),
            items: GraphShapePattern.values
                .map(
                  (pattern) => DropdownMenuItem(
                    value: pattern,
                    child: Text(_patternLabel(pattern)),
                  ),
                )
                .toList(),
            onChanged: shapeLocked
                ? null
                : (pattern) {
                    if (pattern != null) {
                      onShapePatternChanged(index, pattern);
                    }
                  },
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: shapeLocked ? null : () => onSetShapeDefault(index),
            child: const Text('Set as Default'),
          ),
          const SizedBox(height: 10),
          _InspectorValue(
            label: 'Rotation',
            value: '${shape.rotationDegrees.round()} deg',
          ),
          const SizedBox(height: 8),
          _InspectorValue(
            label: 'Linear ft',
            value: _shapeLinearFeet(shape).toStringAsFixed(1),
          ),
          const SizedBox(height: 8),
          _InspectorValue(
            label: 'Square ft',
            value: _shapeSquareFeet(shape).toStringAsFixed(1),
          ),
          const SizedBox(height: 8),
          _InspectorValue(
            label: 'Segments',
            value: shape.segmentIndexes.length.toString(),
          ),
        ],
      );
    }

    if (currentSelection.freehandIndex case final index?
        when index < freehandStrokes.length) {
      final stroke = freehandStrokes[index];
      final structureLocked = _isLayerLocked(_GraphLayer.structure);
      return _InspectorSection(
        title: 'Freehand Properties',
        children: [
          DropdownButtonFormField<_MarkerColorChoice>(
            initialValue: _markerColorChoiceForColor(stroke.color),
            decoration: const InputDecoration(labelText: 'Color'),
            items: _MarkerColorChoice.values
                .map(
                  (choice) => DropdownMenuItem(
                    value: choice,
                    child: _ColorChoiceLabel(
                      label: choice.label,
                      color: choice.color,
                    ),
                  ),
                )
                .toList(),
            onChanged: structureLocked
                ? null
                : (choice) {
                    if (choice != null) {
                      onFreehandColorChanged(index, choice.color);
                    }
                  },
          ),
          _LabeledSlider(
            label: 'Width',
            value: stroke.strokeWidth,
            min: 2,
            max: 12,
            enabled: !structureLocked,
            onChanged: (value) => onFreehandWidthChanged(index, value),
          ),
          _LabeledSlider(
            label: 'Opacity',
            value: stroke.opacity,
            min: 0.15,
            max: 1,
            enabled: !structureLocked,
            onChanged: (value) => onFreehandOpacityChanged(index, value),
          ),
          OutlinedButton(
            onPressed:
                structureLocked ? null : () => onSetFreehandDefault(index),
            child: const Text('Set as Default'),
          ),
          const SizedBox(height: 8),
          _InspectorValue(
            label: 'Points',
            value: stroke.points.length.toString(),
          ),
        ],
      );
    }

    return const _InspectorSection(
      title: 'Properties',
      children: [
        Text('Selected object is no longer available.'),
      ],
    );
  }

  _ShapeFillChoice _fillChoiceForColor(Color? color) {
    for (final choice in _ShapeFillChoice.values) {
      if (choice.color == color) {
        return choice;
      }
    }

    return _ShapeFillChoice.none;
  }

  _MarkerColorChoice _markerColorChoiceForColor(Color color) {
    for (final choice in _MarkerColorChoice.values) {
      if (choice.color == color) {
        return choice;
      }
    }

    return _MarkerColorChoice.red;
  }

  _ShapeBorderChoice _borderChoiceForColor(Color color) {
    for (final choice in _ShapeBorderChoice.values) {
      if (choice.color == color) {
        return choice;
      }
    }

    return _ShapeBorderChoice.darkGreen;
  }

  bool _isLayerLocked(_GraphLayer layer) {
    return layerSettings[layer]?.locked ?? false;
  }

  _GraphLayer _layerForAnnotation(GraphAnnotation annotation) {
    return annotation.kind == GraphAnnotationKind.photo
        ? _GraphLayer.photos
        : _GraphLayer.findings;
  }

  double _shapeLinearFeet(GraphShape shape) {
    var total = 0.0;

    for (final index in shape.segmentIndexes) {
      if (index >= 0 && index < wallSegments.length) {
        total += wallSegments[index].lengthFeet;
      }
    }

    return total;
  }

  double _shapeSquareFeet(GraphShape shape) {
    if (!shape.closed || shape.segmentIndexes.length < 3) {
      return 0;
    }

    final points = <GraphPoint>[];

    for (final index in shape.segmentIndexes) {
      if (index >= 0 && index < wallSegments.length) {
        points.add(wallSegments[index].start);
      }
    }

    if (points.length < 3) {
      return 0;
    }

    var areaPixels = 0.0;

    for (var i = 0; i < points.length; i += 1) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      areaPixels += (current.x * next.y) - (next.x * current.y);
    }

    return areaPixels.abs() /
        2 /
        (WallSegment.pixelsPerFoot * WallSegment.pixelsPerFoot);
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _InspectorValue extends StatelessWidget {
  const _InspectorValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF666B62),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _ColorChoiceLabel extends StatelessWidget {
  const _ColorChoiceLabel({
    required this.label,
    required this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final swatchColor = color ?? Colors.transparent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: swatchColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF9B9F96)),
          ),
          child: color == null
              ? const Icon(Icons.block, size: 13, color: Color(0xFF666B62))
              : null,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${value.toStringAsFixed(label == 'Rotation' ? 0 : 1)}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _LayersPanel extends StatelessWidget {
  const _LayersPanel({
    required this.wallCount,
    required this.shapeCount,
    required this.itemCount,
    required this.photoCount,
    required this.layerSettings,
    required this.traceLayerVisible,
    required this.onCollapse,
    required this.onToggleVisibility,
    required this.onToggleLock,
  });

  final int wallCount;
  final int shapeCount;
  final int itemCount;
  final int photoCount;
  final Map<_GraphLayer, _LayerSettings> layerSettings;
  final bool traceLayerVisible;
  final VoidCallback onCollapse;
  final ValueChanged<_GraphLayer> onToggleVisibility;
  final ValueChanged<_GraphLayer> onToggleLock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Layers',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Collapse layers',
                visualDensity: VisualDensity.compact,
                onPressed: onCollapse,
                icon: const Icon(Icons.expand_more, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                _LayerRow(
                  icon: Icons.foundation_outlined,
                  name: 'Structure',
                  detail: '$wallCount lines',
                  visible: _isVisible(_GraphLayer.structure),
                  locked: _isLocked(_GraphLayer.structure),
                  onToggleVisibility: () =>
                      onToggleVisibility(_GraphLayer.structure),
                  onToggleLock: () => onToggleLock(_GraphLayer.structure),
                ),
                _LayerRow(
                  icon: Icons.category_outlined,
                  name: 'Shapes',
                  detail: '$shapeCount overlays',
                  visible: _isVisible(_GraphLayer.shapes),
                  locked: _isLocked(_GraphLayer.shapes),
                  onToggleVisibility: () =>
                      onToggleVisibility(_GraphLayer.shapes),
                  onToggleLock: () => onToggleLock(_GraphLayer.shapes),
                ),
                _LayerRow(
                  icon: Icons.place_outlined,
                  name: 'Findings',
                  detail: '$itemCount items',
                  visible: _isVisible(_GraphLayer.findings),
                  locked: _isLocked(_GraphLayer.findings),
                  onToggleVisibility: () =>
                      onToggleVisibility(_GraphLayer.findings),
                  onToggleLock: () => onToggleLock(_GraphLayer.findings),
                ),
                _LayerRow(
                  icon: Icons.photo_camera_outlined,
                  name: 'Photos',
                  detail: '$photoCount pins',
                  visible: _isVisible(_GraphLayer.photos),
                  locked: _isLocked(_GraphLayer.photos),
                  onToggleVisibility: () =>
                      onToggleVisibility(_GraphLayer.photos),
                  onToggleLock: () => onToggleLock(_GraphLayer.photos),
                ),
                _LayerRow(
                  icon: Icons.layers_outlined,
                  name: 'Trace Layer',
                  detail: 'satellite placeholder',
                  visible: traceLayerVisible,
                  locked: _isLocked(_GraphLayer.trace),
                  onToggleVisibility: () =>
                      onToggleVisibility(_GraphLayer.trace),
                  onToggleLock: () => onToggleLock(_GraphLayer.trace),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isVisible(_GraphLayer layer) {
    if (layer == _GraphLayer.trace) {
      return traceLayerVisible;
    }

    return layerSettings[layer]?.visible ?? true;
  }

  bool _isLocked(_GraphLayer layer) {
    return layerSettings[layer]?.locked ?? false;
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.icon,
    required this.name,
    required this.detail,
    required this.visible,
    required this.locked,
    required this.onToggleVisibility,
    required this.onToggleLock,
  });

  final IconData icon;
  final String name;
  final String detail;
  final bool visible;
  final bool locked;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF666B62),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: visible ? 'Hide layer' : 'Show layer',
            visualDensity: VisualDensity.compact,
            onPressed: onToggleVisibility,
            icon: Icon(
              visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 17,
            ),
          ),
          IconButton(
            tooltip: locked ? 'Unlock layer' : 'Lock layer',
            visualDensity: VisualDensity.compact,
            onPressed: onToggleLock,
            icon: Icon(
              locked ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasSurface extends StatelessWidget {
  const _CanvasSurface({
    required this.canvasSize,
    required this.wallSegments,
    required this.annotations,
    required this.shapes,
    required this.freehandStrokes,
    required this.draftFreehandPoints,
    required this.previewShapeSegments,
    required this.previewShape,
    required this.hiddenSegmentIndexes,
    required this.gridVisible,
    required this.selectedSegmentIndex,
    required this.selectedAnnotationIndex,
    required this.selectedShapeIndex,
    required this.selectedFreehandIndex,
    required this.hoveredSegmentIndex,
    required this.hoveredAnnotationIndex,
    required this.hoveredShapeIndex,
    required this.hoveredFreehandIndex,
    required this.activeWallStart,
    required this.previewSegment,
    required this.structureVisible,
    required this.shapesVisible,
    required this.findingsVisible,
    required this.photosVisible,
    required this.traceLayerVisible,
  });

  final Size canvasSize;
  final List<WallSegment> wallSegments;
  final List<GraphAnnotation> annotations;
  final List<GraphShape> shapes;
  final List<FreehandStroke> freehandStrokes;
  final List<GraphPoint> draftFreehandPoints;
  final List<WallSegment> previewShapeSegments;
  final GraphShape? previewShape;
  final Set<int> hiddenSegmentIndexes;
  final bool gridVisible;
  final int? selectedSegmentIndex;
  final int? selectedAnnotationIndex;
  final int? selectedShapeIndex;
  final int? selectedFreehandIndex;
  final int? hoveredSegmentIndex;
  final int? hoveredAnnotationIndex;
  final int? hoveredShapeIndex;
  final int? hoveredFreehandIndex;
  final GraphPoint? activeWallStart;
  final WallSegment? previewSegment;
  final bool structureVisible;
  final bool shapesVisible;
  final bool findingsVisible;
  final bool photosVisible;
  final bool traceLayerVisible;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: canvasSize,
      painter: GraphGridPainter(visible: gridVisible),
      foregroundPainter: _GraphOverlayPainter(
        wallSegments: wallSegments,
        annotations: annotations,
        shapes: shapes,
        freehandStrokes: freehandStrokes,
        draftFreehandPoints: draftFreehandPoints,
        previewShapeSegments: previewShapeSegments,
        previewShape: previewShape,
        hiddenSegmentIndexes: hiddenSegmentIndexes,
        selectedSegmentIndex: selectedSegmentIndex,
        selectedAnnotationIndex: selectedAnnotationIndex,
        selectedShapeIndex: selectedShapeIndex,
        selectedFreehandIndex: selectedFreehandIndex,
        hoveredSegmentIndex: hoveredSegmentIndex,
        hoveredAnnotationIndex: hoveredAnnotationIndex,
        hoveredShapeIndex: hoveredShapeIndex,
        hoveredFreehandIndex: hoveredFreehandIndex,
        activeWallStart: activeWallStart,
        previewSegment: previewSegment,
        structureVisible: structureVisible,
        shapesVisible: shapesVisible,
        findingsVisible: findingsVisible,
        photosVisible: photosVisible,
      ),
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: traceLayerVisible ? const _TraceLayer() : null,
      ),
    );
  }
}

class _GraphOverlayPainter extends CustomPainter {
  const _GraphOverlayPainter({
    required this.wallSegments,
    required this.annotations,
    required this.shapes,
    required this.freehandStrokes,
    required this.draftFreehandPoints,
    required this.previewShapeSegments,
    required this.previewShape,
    required this.hiddenSegmentIndexes,
    required this.selectedSegmentIndex,
    required this.selectedAnnotationIndex,
    required this.selectedShapeIndex,
    required this.selectedFreehandIndex,
    required this.hoveredSegmentIndex,
    required this.hoveredAnnotationIndex,
    required this.hoveredShapeIndex,
    required this.hoveredFreehandIndex,
    required this.activeWallStart,
    required this.previewSegment,
    required this.structureVisible,
    required this.shapesVisible,
    required this.findingsVisible,
    required this.photosVisible,
  });

  final List<WallSegment> wallSegments;
  final List<GraphAnnotation> annotations;
  final List<GraphShape> shapes;
  final List<FreehandStroke> freehandStrokes;
  final List<GraphPoint> draftFreehandPoints;
  final List<WallSegment> previewShapeSegments;
  final GraphShape? previewShape;
  final Set<int> hiddenSegmentIndexes;
  final int? selectedSegmentIndex;
  final int? selectedAnnotationIndex;
  final int? selectedShapeIndex;
  final int? selectedFreehandIndex;
  final int? hoveredSegmentIndex;
  final int? hoveredAnnotationIndex;
  final int? hoveredShapeIndex;
  final int? hoveredFreehandIndex;
  final GraphPoint? activeWallStart;
  final WallSegment? previewSegment;
  final bool structureVisible;
  final bool shapesVisible;
  final bool findingsVisible;
  final bool photosVisible;

  @override
  void paint(Canvas canvas, Size size) {
    if (shapesVisible) {
      GraphShapesPainter(
        shapes: shapes,
        segments: wallSegments,
        selectedShapeIndex: selectedShapeIndex,
        hoveredShapeIndex: hoveredShapeIndex,
      ).paint(
        canvas,
        size,
      );
    }
    if (structureVisible) {
      WallSegmentsPainter(
        segments: wallSegments,
        selectedSegmentIndex: selectedSegmentIndex,
        hoveredSegmentIndex: hoveredSegmentIndex,
        activeWallStart: activeWallStart,
        previewSegment: previewSegment,
        hiddenSegmentIndexes: hiddenSegmentIndexes,
      ).paint(canvas, size);
      final shapePreview = previewShape;
      if (shapePreview != null && previewShapeSegments.isNotEmpty) {
        GraphShapesPainter(
          shapes: [shapePreview],
          segments: previewShapeSegments,
          selectedShapeIndex: null,
          hoveredShapeIndex: null,
        ).paint(canvas, size);
      }
      FreehandStrokesPainter(
        strokes: freehandStrokes,
        draftPoints: draftFreehandPoints,
        selectedStrokeIndex: selectedFreehandIndex,
        hoveredStrokeIndex: hoveredFreehandIndex,
      ).paint(canvas, size);
    }
    GraphAnnotationsPainter(
      annotations: annotations,
      selectedAnnotationIndex: selectedAnnotationIndex,
      hoveredAnnotationIndex: hoveredAnnotationIndex,
      findingsVisible: findingsVisible,
      photosVisible: photosVisible,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _GraphOverlayPainter oldDelegate) {
    return oldDelegate.wallSegments != wallSegments ||
        oldDelegate.annotations != annotations ||
        oldDelegate.shapes != shapes ||
        oldDelegate.freehandStrokes != freehandStrokes ||
        oldDelegate.draftFreehandPoints != draftFreehandPoints ||
        oldDelegate.previewShapeSegments != previewShapeSegments ||
        oldDelegate.previewShape != previewShape ||
        oldDelegate.hiddenSegmentIndexes != hiddenSegmentIndexes ||
        oldDelegate.selectedSegmentIndex != selectedSegmentIndex ||
        oldDelegate.selectedAnnotationIndex != selectedAnnotationIndex ||
        oldDelegate.selectedShapeIndex != selectedShapeIndex ||
        oldDelegate.selectedFreehandIndex != selectedFreehandIndex ||
        oldDelegate.hoveredSegmentIndex != hoveredSegmentIndex ||
        oldDelegate.hoveredAnnotationIndex != hoveredAnnotationIndex ||
        oldDelegate.hoveredShapeIndex != hoveredShapeIndex ||
        oldDelegate.hoveredFreehandIndex != hoveredFreehandIndex ||
        oldDelegate.activeWallStart != activeWallStart ||
        oldDelegate.previewSegment != previewSegment ||
        oldDelegate.structureVisible != structureVisible ||
        oldDelegate.shapesVisible != shapesVisible ||
        oldDelegate.findingsVisible != findingsVisible ||
        oldDelegate.photosVisible != photosVisible;
  }
}

class _TraceLayer extends StatelessWidget {
  const _TraceLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(89, 123, 153, 0.16),
          border: Border.all(
            color: const Color.fromRGBO(89, 123, 153, 0.35),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'Satellite trace layer placeholder',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF35566E),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

enum _UndoKind {
  snapshot,
  wallStart,
  wallSegment,
  annotation,
  freehand,
  textEdit,
  move,
  shapeFinish,
}

enum _SelectionKind {
  annotation,
  segment,
  shape,
  freehand,
}

enum _ContextAction {
  copy,
  paste,
  duplicate,
  delete,
  bringForward,
  sendBackward,
  bringToFront,
  sendToBack,
  group,
  ungroup,
  lock,
  unlock,
  properties,
}

enum _ReorderDirection {
  forward,
  backward,
  front,
  back,
}

class _ClipboardItem {
  const _ClipboardItem(this.selection);

  final _Selection selection;
}

enum _GraphLayer {
  structure,
  shapes,
  findings,
  photos,
  trace,
}

class _LayerSettings {
  const _LayerSettings({
    this.visible = true,
    this.locked = false,
  });

  final bool visible;
  final bool locked;

  _LayerSettings copyWith({
    bool? visible,
    bool? locked,
  }) {
    return _LayerSettings(
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
    );
  }
}

class _MarkerStyleDefaults {
  const _MarkerStyleDefaults({
    required this.color,
    required this.size,
  });

  factory _MarkerStyleDefaults.fromMarkerType(GraphMarkerType markerType) {
    return _MarkerStyleDefaults(
      color: markerType.defaultColor,
      size: 1,
    );
  }

  final Color color;
  final double size;
}

class _DrawingStyleDefaults {
  const _DrawingStyleDefaults({
    required this.fillColor,
    required this.fillOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.pattern,
    required this.lineColor,
    required this.lineWidth,
    required this.linePattern,
  });

  factory _DrawingStyleDefaults.fromPreset(GraphDrawingPreset preset) {
    return _DrawingStyleDefaults(
      fillColor: preset.defaultFillColor,
      fillOpacity: preset.defaultFillOpacity,
      borderColor: preset.defaultBorderColor,
      borderWidth: preset.defaultBorderWidth,
      pattern: preset.defaultPattern,
      lineColor: preset.defaultLineColor,
      lineWidth: preset.defaultLineWidth,
      linePattern: _linePatternFromPresetValue(preset.defaultLinePattern),
    );
  }

  final Color? fillColor;
  final double fillOpacity;
  final Color borderColor;
  final double borderWidth;
  final GraphShapePattern pattern;
  final Color lineColor;
  final double lineWidth;
  final LinePattern linePattern;

  _DrawingStyleDefaults copyWith({
    Color? fillColor,
    bool clearFillColor = false,
    double? fillOpacity,
    Color? borderColor,
    double? borderWidth,
    GraphShapePattern? pattern,
    Color? lineColor,
    double? lineWidth,
    LinePattern? linePattern,
  }) {
    return _DrawingStyleDefaults(
      fillColor: clearFillColor ? null : fillColor ?? this.fillColor,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      pattern: pattern ?? this.pattern,
      lineColor: lineColor ?? this.lineColor,
      lineWidth: lineWidth ?? this.lineWidth,
      linePattern: linePattern ?? this.linePattern,
    );
  }
}

LinePattern _linePatternFromPresetValue(LinePatternValue value) {
  return switch (value) {
    LinePatternValue.solid => LinePattern.solid,
    LinePatternValue.dashed => LinePattern.dashed,
    LinePatternValue.xMarks => LinePattern.xMarks,
    LinePatternValue.dottedSmall => LinePattern.dottedSmall,
    LinePatternValue.dottedLarge => LinePattern.dottedLarge,
    LinePatternValue.diamonds => LinePattern.diamonds,
  };
}

class _Selection {
  const _Selection._({
    required this.kind,
    required this.index,
  });

  factory _Selection.annotation(int index) {
    return _Selection._(kind: _SelectionKind.annotation, index: index);
  }

  factory _Selection.segment(int index) {
    return _Selection._(kind: _SelectionKind.segment, index: index);
  }

  factory _Selection.shape(int index) {
    return _Selection._(kind: _SelectionKind.shape, index: index);
  }

  factory _Selection.freehand(int index) {
    return _Selection._(kind: _SelectionKind.freehand, index: index);
  }

  final _SelectionKind kind;
  final int index;

  int? get annotationIndex => kind == _SelectionKind.annotation ? index : null;

  int? get segmentIndex => kind == _SelectionKind.segment ? index : null;

  int? get shapeIndex => kind == _SelectionKind.shape ? index : null;

  int? get freehandIndex => kind == _SelectionKind.freehand ? index : null;

  @override
  bool operator ==(Object other) =>
      other is _Selection && other.kind == kind && other.index == index;

  @override
  int get hashCode => Object.hash(kind, index);
}

class _EditorSnapshot {
  const _EditorSnapshot({
    required this.wallSegments,
    required this.annotations,
    required this.shapes,
    required this.freehandStrokes,
    required this.activeWallStart,
    required this.activePathStartPoint,
    required this.pendingCurveControlPoint,
    required this.activePathStartSegmentIndex,
  });

  factory _EditorSnapshot.capture(_GraphCanvasScreenState state) =>
      _EditorSnapshot(
        wallSegments: List<WallSegment>.of(state._wallSegments),
        annotations: List<GraphAnnotation>.of(state._annotations),
        shapes: List<GraphShape>.of(state._shapes),
        freehandStrokes: List<FreehandStroke>.of(state._freehandStrokes),
        activeWallStart: state._activeWallStart,
        activePathStartPoint: state._activePathStartPoint,
        pendingCurveControlPoint: state._pendingCurveControlPoint,
        activePathStartSegmentIndex: state._activePathStartSegmentIndex,
      );

  final List<WallSegment> wallSegments;
  final List<GraphAnnotation> annotations;
  final List<GraphShape> shapes;
  final List<FreehandStroke> freehandStrokes;
  final GraphPoint? activeWallStart;
  final GraphPoint? activePathStartPoint;
  final GraphPoint? pendingCurveControlPoint;
  final int? activePathStartSegmentIndex;

  void restore(_GraphCanvasScreenState state) {
    state._wallSegments = wallSegments;
    state._annotations = annotations;
    state._shapes = shapes;
    state._freehandStrokes = freehandStrokes;
    state._activeWallStart = activeWallStart;
    state._activePathStartPoint = activePathStartPoint;
    state._pendingCurveControlPoint = pendingCurveControlPoint;
    state._activePathStartSegmentIndex = activePathStartSegmentIndex;
    state._previewSegment = null;
  }
}

class _RedoEntry {
  const _RedoEntry({required this.snapshot, required this.undoEntry});

  final _EditorSnapshot snapshot;
  final _UndoEntry undoEntry;
}

class _UndoEntry {
  const _UndoEntry(
    this.kind, {
    this.previousSnapshot,
    this.annotationIndex,
    this.previousAnnotation,
    this.previousWallSegments,
    this.previousAnnotations,
    this.previousShapes,
    this.previousFreehandStrokes,
    this.previousActiveWallStart,
    this.previousActivePathStartPoint,
    this.previousActivePathStartSegmentIndex,
    this.shapeIndex,
    this.addedSegmentCount = 0,
  });

  final _UndoKind kind;
  final _EditorSnapshot? previousSnapshot;
  final int? annotationIndex;
  final GraphAnnotation? previousAnnotation;
  final List<WallSegment>? previousWallSegments;
  final List<GraphAnnotation>? previousAnnotations;
  final List<GraphShape>? previousShapes;
  final List<FreehandStroke>? previousFreehandStrokes;
  final GraphPoint? previousActiveWallStart;
  final GraphPoint? previousActivePathStartPoint;
  final int? previousActivePathStartSegmentIndex;
  final int? shapeIndex;
  final int addedSegmentCount;
}

enum _DragKind {
  wallEndpoint,
  segment,
  annotation,
  shape,
  shapeResize,
  shapeRotation,
  freehand,
}

class _DragTarget {
  const _DragTarget._({
    required this.kind,
    required this.distance,
    this.annotationIndex,
    this.segmentIndex,
    this.shapeIndex,
    this.freehandIndex,
    this.endpointRefs = const <_SegmentEndpointRef>[],
    this.movesActiveWallStart = false,
    this.movesActivePathStart = false,
    this.originalPoint,
    this.shapeCenter,
    this.originalBounds,
    this.resizeHandleIndex = 0,
    this.initialAngleRadians = 0,
    this.originalRotationDegrees = 0,
    this.selection,
  });

  factory _DragTarget.annotation({
    required int annotationIndex,
    required double distance,
  }) {
    return _DragTarget._(
      kind: _DragKind.annotation,
      annotationIndex: annotationIndex,
      distance: distance,
      selection: _Selection.annotation(annotationIndex),
    );
  }

  factory _DragTarget.segment({
    required int segmentIndex,
    required double distance,
    required GraphPoint originalPoint,
  }) {
    return _DragTarget._(
      kind: _DragKind.segment,
      segmentIndex: segmentIndex,
      distance: distance,
      originalPoint: originalPoint,
      selection: _Selection.segment(segmentIndex),
    );
  }

  factory _DragTarget.wallEndpoint({
    required List<_SegmentEndpointRef> endpointRefs,
    required bool movesActiveWallStart,
    required bool movesActivePathStart,
    required GraphPoint originalPoint,
    required double distance,
  }) {
    return _DragTarget._(
      kind: _DragKind.wallEndpoint,
      endpointRefs: endpointRefs,
      movesActiveWallStart: movesActiveWallStart,
      movesActivePathStart: movesActivePathStart,
      originalPoint: originalPoint,
      distance: distance,
      selection: endpointRefs.isEmpty
          ? null
          : _Selection.segment(endpointRefs.first.segmentIndex),
    );
  }

  factory _DragTarget.shape({
    required int shapeIndex,
    required double distance,
    required GraphPoint originalPoint,
  }) {
    return _DragTarget._(
      kind: _DragKind.shape,
      shapeIndex: shapeIndex,
      distance: distance,
      originalPoint: originalPoint,
      selection: _Selection.shape(shapeIndex),
    );
  }

  factory _DragTarget.shapeResize({
    required int shapeIndex,
    required double distance,
    required GraphPoint originalPoint,
    required Rect originalBounds,
    required int resizeHandleIndex,
  }) {
    return _DragTarget._(
      kind: _DragKind.shapeResize,
      shapeIndex: shapeIndex,
      distance: distance,
      originalPoint: originalPoint,
      originalBounds: originalBounds,
      resizeHandleIndex: resizeHandleIndex,
      selection: _Selection.shape(shapeIndex),
    );
  }

  factory _DragTarget.shapeRotation({
    required int shapeIndex,
    required double distance,
    required GraphPoint originalPoint,
    required GraphPoint shapeCenter,
    required double initialAngleRadians,
    required double originalRotationDegrees,
  }) {
    return _DragTarget._(
      kind: _DragKind.shapeRotation,
      shapeIndex: shapeIndex,
      distance: distance,
      originalPoint: originalPoint,
      shapeCenter: shapeCenter,
      initialAngleRadians: initialAngleRadians,
      originalRotationDegrees: originalRotationDegrees,
      selection: _Selection.shape(shapeIndex),
    );
  }

  factory _DragTarget.freehand({
    required int freehandIndex,
    required double distance,
    required GraphPoint originalPoint,
  }) {
    return _DragTarget._(
      kind: _DragKind.freehand,
      freehandIndex: freehandIndex,
      distance: distance,
      originalPoint: originalPoint,
      selection: _Selection.freehand(freehandIndex),
    );
  }

  final _DragKind kind;
  final double distance;
  final int? annotationIndex;
  final int? segmentIndex;
  final int? shapeIndex;
  final int? freehandIndex;
  final List<_SegmentEndpointRef> endpointRefs;
  final bool movesActiveWallStart;
  final bool movesActivePathStart;
  final GraphPoint? originalPoint;
  final GraphPoint? shapeCenter;
  final Rect? originalBounds;
  final int resizeHandleIndex;
  final double initialAngleRadians;
  final double originalRotationDegrees;
  final _Selection? selection;
}

class _SegmentEndpointRef {
  const _SegmentEndpointRef({
    required this.segmentIndex,
    required this.isStart,
  });

  final int segmentIndex;
  final bool isStart;
}

class _FinishShapeResult {
  const _FinishShapeResult({
    required this.name,
    required this.closeShape,
    required this.fillColor,
    required this.fillOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.pattern,
  });

  final String name;
  final bool closeShape;
  final Color? fillColor;
  final double fillOpacity;
  final Color borderColor;
  final double borderWidth;
  final GraphShapePattern pattern;
}

enum _ShapeFillChoice {
  none('None', null, 0),
  noteYellow('Note yellow', Color(0xFFFFF2B8), 0.85),
  lime('Lime', Color(0xFFB6D94C), 0.34),
  teal('Teal', Color(0xFF24A69A), 0.32),
  blue('Blue', Color(0xFF3D7CFF), 0.30),
  violet('Violet', Color(0xFF8E5CF7), 0.30),
  amber('Amber', Color(0xFFFFB52E), 0.36),
  red('Red', Color(0xFFFF5A47), 0.30);

  const _ShapeFillChoice(this.label, this.color, this.opacity);

  final String label;
  final Color? color;
  final double opacity;
}

enum _ShapeBorderChoice {
  darkGreen('Dark green', Color(0xFF214D38)),
  black('Black', Color(0xFF1C2B22)),
  blue('Blue', Color(0xFF245BDB)),
  violet('Violet', Color(0xFF7048D8)),
  orange('Orange', Color(0xFFD1721E)),
  red('Red', Color(0xFFD33A2C));

  const _ShapeBorderChoice(this.label, this.color);

  final String label;
  final Color color;
}

enum _MarkerColorChoice {
  red('Red', Color(0xFFD33A2C)),
  orange('Orange', Color(0xFFE5792A)),
  yellow('Yellow', Color(0xFFE0AD19)),
  green('Green', Color(0xFF2E7D55)),
  teal('Teal', Color(0xFF168AAD)),
  blue('Blue', Color(0xFF245BDB)),
  purple('Purple', Color(0xFF7048D8)),
  black('Black', Color(0xFF1C2B22));

  const _MarkerColorChoice(this.label, this.color);

  final String label;
  final Color color;
}

String _patternLabel(GraphShapePattern pattern) {
  return switch (pattern) {
    GraphShapePattern.none => 'None',
    GraphShapePattern.diagonal => 'Diagonal',
    GraphShapePattern.reverseDiagonal => 'Reverse diagonal',
    GraphShapePattern.crossHatch => 'Cross hatch',
    GraphShapePattern.horizontal => 'Horizontal',
    GraphShapePattern.vertical => 'Vertical',
    GraphShapePattern.grid => 'Grid',
    GraphShapePattern.dots => 'Dots',
    GraphShapePattern.largeDots => 'Large dots',
    GraphShapePattern.checker => 'Checker',
  };
}
