import 'dart:ui';

class DrawingPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;
  final bool isNewStroke;

  const DrawingPoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
    required this.isNewStroke,
  });

  Map<String, dynamic> toJson() {
    return {
      'dx': offset.dx,
      'dy': offset.dy,
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'isNewStroke': isNewStroke,
    };
  }

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      offset: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      isNewStroke: json['isNewStroke'] as bool,
    );
  }
}
