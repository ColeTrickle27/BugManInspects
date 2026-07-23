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
      _drawSummary(canvas, trace);
      _drawScaleBar(canvas, trace);
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

  @override
  bool shouldRepaint(covariant TraceGeometryPainter oldDelegate) =>
      oldDelegate.traces != traces ||
      oldDelegate.selectedTraceIndex != selectedTraceIndex ||
      oldDelegate.hoveredTraceIndex != hoveredTraceIndex;
}
