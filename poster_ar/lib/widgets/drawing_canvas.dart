import 'package:flutter/material.dart';
import '../models/drawing_point.dart';

class DrawingCanvas extends StatelessWidget {
  final List<DrawingPoint> points;
  final Function(Offset)? onPanStart;
  final Function(Offset)? onPanUpdate;
  final bool enabled;

  const DrawingCanvas({
    super.key,
    required this.points,
    this.onPanStart,
    this.onPanUpdate,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: enabled && onPanStart != null
          ? (details) => onPanStart!(details.localPosition)
          : null,
      onPanUpdate: enabled && onPanUpdate != null
          ? (details) =>onPanUpdate!(details.localPosition) 
          : null,
      child: CustomPaint(
        painter: _DrawingPainter(points: points),
        size: Size.infinite,
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  _DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current.isNewStroke) {
        canvas.drawCircle(
          current.offset,
          current.strokeWidth / 2,
          Paint()
            ..color = current.color
            ..style = PaintingStyle.fill,
        );
        continue;
      }

      canvas.drawLine(
        current.offset,
        next.offset,
        Paint()
          ..color = current.color
          ..strokeWidth = current.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    if (points.isNotEmpty && points.last.isNewStroke) {
      final last = points.last;
      canvas.drawCircle(
        last.offset,
        last.strokeWidth / 2,
        Paint()
          ..color = last.color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}

