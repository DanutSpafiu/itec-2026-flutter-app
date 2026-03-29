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
    // Support multiple possible JSON shapes produced by server/frontend
    double parseNum(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double dx = 0.0;
    double dy = 0.0;

    if (json.containsKey('dx') || json.containsKey('dy')) {
      dx = parseNum(json['dx']);
      dy = parseNum(json['dy']);
    } else if (json.containsKey('x') || json.containsKey('y')) {
      dx = parseNum(json['x']);
      dy = parseNum(json['y']);
    } else if (json.containsKey('point') && json['point'] is List) {
      final lst = json['point'] as List;
      if (lst.isNotEmpty) dx = parseNum(lst[0]);
      if (lst.length > 1) dy = parseNum(lst[1]);
    } else if (json.containsKey('0') && json.containsKey('1')) {
      dx = parseNum(json['0']);
      dy = parseNum(json['1']);
    }

    // color can be int ARGB, or hex string like '#FF00AA'
    Color col = const Color(0xFFE94560);
    final cval = json['color'];
    if (cval is int) {
      col = Color(cval);
    } else if (cval is String) {
      final s = cval.toLowerCase();
      try {
        String hex = s.replaceAll('#', '');
        // if given as 6 chars, assume RRGGBB and add FF alpha
        if (hex.length == 6) hex = 'ff$hex';
        final v = int.parse(hex, radix: 16);
        col = Color(v);
      } catch (e) {
        // leave default
      }
    }

    double sw = 4.0;
    if (json.containsKey('strokeWidth')) sw = parseNum(json['strokeWidth']);
    bool isNew = false;
    if (json.containsKey('isNewStroke')) {
      final iv = json['isNewStroke'];
      if (iv is bool) {
        isNew = iv;
      } else if (iv is num)
        isNew = iv != 0;
      else if (iv is String)
        isNew = iv.toLowerCase() == 'true';
    }

    return DrawingPoint(
      offset: Offset(dx, dy),
      color: col,
      strokeWidth: sw,
      isNewStroke: isNew,
    );
  }
}
