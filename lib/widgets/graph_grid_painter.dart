import 'package:flutter/material.dart';

class GraphGridPainter extends CustomPainter {
  const GraphGridPainter({
    this.visible = true,
  });

  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    const smallGrid = 24.0;
    const majorGrid = smallGrid * 4;

    final backgroundPaint = Paint()..color = Colors.white;
    final smallGridPaint = Paint()
      ..color = const Color(0xFFE8E5DD)
      ..strokeWidth = 1;
    final majorGridPaint = Paint()
      ..color = const Color(0xFFD1CCBF)
      ..strokeWidth = 1.4;

    canvas.drawRect(Offset.zero & size, backgroundPaint);

    if (!visible) {
      return;
    }

    for (double x = 0; x <= size.width; x += smallGrid) {
      final paint = x % majorGrid == 0 ? majorGridPaint : smallGridPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += smallGrid) {
      final paint = y % majorGrid == 0 ? majorGridPaint : smallGridPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphGridPainter oldDelegate) {
    return oldDelegate.visible != visible;
  }
}
