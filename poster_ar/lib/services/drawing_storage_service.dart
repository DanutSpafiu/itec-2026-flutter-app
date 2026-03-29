import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing_point.dart';

class DrawingStorageService {
  static const String _drawingKeyPrefix = 'drawing_';

  Future<void> saveDrawing(String posterId, List<DrawingPoint> points) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = points.map((p) => p.toJson()).toList();
    await prefs.setString('$_drawingKeyPrefix$posterId', jsonEncode(jsonList));
  }

  Future<List<DrawingPoint>> loadDrawing(String posterId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_drawingKeyPrefix$posterId');
    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList
        .map((json) => DrawingPoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearDrawing(String posterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_drawingKeyPrefix$posterId');
  }

  Future<bool> hasDrawing(String posterId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_drawingKeyPrefix$posterId');
  }
}
