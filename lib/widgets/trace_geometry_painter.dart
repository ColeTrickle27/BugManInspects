import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/trace_geometry.dart';
import '../services/measurement_format.dart';
import '../services/measurement_service.dart';
import '../services/trace_projection_service.dart';

class TraceGeometryPainter extends CustomPainter {
  const TraceGeometryPainter({
    required this.traces,
    this.selectedTraceIndex,
    this.hoveredTraceIndex,
  });

  final List<TraceGeometry> traces;
  final int? selectedTraceIndex;
  final int? hoveredTraceIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var traceIndex = 0; traceIndex < traces.length; traceIndex += 1) {
      final trace = traces[traceIndex];
      final selected = traceIndex == selectedTraceIndex;
      final hovered = traceIndex == hoveredTraceIndex;
      if (trace.canvasPoints.length < 2) continue;
      final path = Path()
        ..moveTo(trace.canvasPoints.first.x, trace.canvasPoints.first.y);
      for (final point in trace.canvasPoints.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      if (trace.closed && trace.canvasPoints.length >= 3) path.close();
      if (trace.closed) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x223B82F6)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = selected
              ? const Color(0xFF1976D2)
              : hovered
                  ? const Color(0xFFFF6F00)
                  : const Color(0xFFCC2000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 7 : 5
          ..strokeJoin = StrokeJoin.round,
      );
      for (final point in trace.canvasPoints) {
        canvas.drawCircle(
          point.offset,
          selected ? 10 : 7,
          Paint()
            ..color =
                selected ? const Color(0xFF1976D2) : const Color(0xFFCC2000),
        );
      }
      _drawSegmentMeasurements(canvas, trace);
      _drawSummary(canvas, trace);
      _drawScaleBar(canvas, trace);
      if (selected) _drawRotationHandle(canvas, trace);
    }
  }

  static Rect? canvasBounds(TraceGeometry trace) {
    if (trace.canvasPoints.isEmpty) return null;
    final left = trace.canvasPoints.map((point) => point.x).reduce(math.min);
    final right = trace.canvasPoints.map((point) => point.x).reduce(math.max);
    final top = trace.canvasPoints.map((point) => point.y).reduce(math.min);
    final bottom = trace.canvasPoints.map((point) => point.y).reduce(math.max);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Offset? rotationHandleCenter(TraceGeometry trace) {
    final bounds = canvasBounds(trace);
    return bounds == null ? null : bounds.topCenter - const Offset(0, 42);
  }

  void _drawSegmentMeasurements(Canvas canvas, TraceGeometry trace) {
    final pointCount = trace.canvasPoints.length < trace.geoPoints.length
        ? trace.canvasPoints.length
        : trace.geoPoints.length;
    if (pointCount < 2) return;
    final edgeCount =
        trace.closed && pointCount > 2 ? pointCount : pointCount - 1;
    final center = Offset(
      trace.canvasPoints
              .take(pointCount)
              .map((point) => point.x)
              .reduce((a, b) => a + b) /
          pointCount,
      trace.canvasPoints
              .take(pointCount)
              .map((point) => point.y)
              .reduce((a, b) => a + b) /
          pointCount,
    );

    for (var index = 0; index < edgeCount; index += 1) {
      final nextIndex = (index + 1) % pointCount;
      final start = trace.canvasPoints[index].offset;
      final end = trace.canvasPoints[nextIndex].offset;
      final segment = end - start;
      final segmentLength = segment.distance;
      if (segmentLength <= 0.01) continue;

      final midpoint = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );
      var normal =
          Offset(-segment.dy / segmentLength, segment.dx / segmentLength);
      final towardMidpoint = midpoint - center;
      if ((normal.dx * towardMidpoint.dx) + (normal.dy * towardMidpoint.dy) <
          0) {
        normal = Offset(-normal.dx, -normal.dy);
      }

      final linearFeet = MeasurementService.geodesicDistanceMeters(
            trace.geoPoints[index],
            trace.geoPoints[nextIndex],
          ) *
          3.280839895013123;
      final label = TextPainter(
        text: TextSpan(
          text: MeasurementFormat.linearFeet(linearFeet),
          style: const TextStyle(
            color: Color(0xFF0F3D77),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelCenter = midpoint + (normal * 22);
      final labelRect = Rect.fromCenter(
        center: labelCenter,
        width: label.width + 16,
        height: label.height + 10,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      label.paint(canvas, labelRect.topLeft + const Offset(8, 5));
    }
  }

  void _drawSummary(Canvas canvas, TraceGeometry trace) {
    final measurement = MeasurementService.measureTrace(
      trace,
      status: MeasurementAccuracyStatus.estimated,
    );
    final center = Offset(
      trace.canvasPoints.map((point) => point.x).reduce((a, b) => a + b) /
          trace.canvasPoints.length,
      trace.canvasPoints.map((point) => point.y).reduce((a, b) => a + b) /
          trace.canvasPoints.length,
    );
    final text = TextPainter(
      text: TextSpan(
        text: '${trace.label}\n'
            '${MeasurementFormat.linearFeet(measurement.linearFeet)} • '
            '${MeasurementFormat.squareFeet(measurement.squareFeet)} • '
            '${MeasurementFormat.acres(measurement.acres)}',
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 320);
    final rect = Rect.fromCenter(
      center: center,
      width: text.width + 24,
      height: text.height + 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    text.paint(canvas, rect.topLeft + const Offset(12, 8));
  }

  void _drawScaleBar(Canvas canvas, TraceGeometry trace) {
    final metersPerCanvasUnit = trace.metersPerCanvasUnit;
    if (metersPerCanvasUnit == null || metersPerCanvasUnit <= 0) return;
    final feet = TraceProjectionService.scaleBarFeet(metersPerCanvasUnit);
    final width = feet / (metersPerCanvasUnit * 3.280839895013123);
    final left = trace.canvasPoints.map((point) => point.x).reduce(math.min);
    final top = trace.canvasPoints.map((point) => point.y).reduce(math.min);
    final start = Offset(left, math.max(26, top - 54));
    final end = start + Offset(width, 0);
    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 4;
    canvas.drawLine(start, end, paint);
    canvas.drawLine(
        start - const Offset(0, 8), start + const Offset(0, 8), paint);
    canvas.drawLine(end - const Offset(0, 8), end + const Offset(0, 8), paint);
    final label = TextPainter(
      text: TextSpan(
        text: '${feet.round()} ft',
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset((start.dx + end.dx - label.width) / 2, start.dy - 26),
    );
  }

  void _drawRotationHandle(Canvas canvas, TraceGeometry trace) {
    final bounds = canvasBounds(trace);
    final handleCenter = rotationHandleCenter(trace);
    if (bounds == null || handleCenter == null) return;
    final paint = Paint()
      ..color = const Color(0xFF1976D2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(bounds.topCenter, handleCenter, paint);
    canvas.drawCircle(
      handleCenter,
      13,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(handleCenter, 13, paint);
    canvas.drawArc(
      Rect.fromCircle(center: handleCenter, radius: 7),
      -math.pi / 3,
      math.pi * 1.45,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant TraceGeometryPainter oldDelegate) =>
      oldDelegate.traces != traces ||
      oldDelegate.selectedTraceIndex != selectedTraceIndex ||
      oldDelegate.hoveredTraceIndex != hoveredTraceIndex;
}
