import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../models/drawing_point.dart';
import '../models/poster.dart';
import '../services/camera_service.dart';
import '../services/drawing_storage_service.dart';
import '../services/image_recognition_service.dart';

enum ArState { initializing, ready, scanning, posterRecognized, drawing }

class ArProvider extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  final ImageRecognitionService _recognitionService = ImageRecognitionService();
  final DrawingStorageService _storageService = DrawingStorageService();

  ArState _state = ArState.initializing;
  String? _recognizedPosterId;
  List<DrawingPoint> _drawingPoints = [];
  List<DrawingPoint> _savedDrawingPoints = [];
  Color _selectedColor = const Color(0xFFE94560);
  double _strokeWidth = 4.0;
  bool _isScanning = false;
  Poster? _currentPoster;

  CameraController? get cameraController => _cameraService.controller;
  ArState get state => _state;
  String? get recognizedPosterId => _recognizedPosterId;
  List<DrawingPoint> get drawingPoints => _drawingPoints;
  List<DrawingPoint> get savedDrawingPoints => _savedDrawingPoints;
  Color get selectedColor => _selectedColor;
  double get strokeWidth => _strokeWidth;
  bool get isScanning => _isScanning;
  Poster? get currentPoster => _currentPoster;
  bool get hasSavedDrawing => _savedDrawingPoints.isNotEmpty;

  List<Poster> get allPosters => Poster.getPosters();

  Future<void> initialize() async {
    try {
      await _cameraService.initializeCamera();
      await _recognitionService.loadPosterImages();
      _state = ArState.ready;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AR: $e');
      _state = ArState.ready;
      notifyListeners();
    }
  }

  Future<void> scanForPoster() async {
    if (_isScanning) return;

    _isScanning = true;
    _state = ArState.scanning;
    notifyListeners();

    try {
      final file = await _cameraService.takePicture();
      if (file != null) {
        final posterId = await _recognitionService.recognizePoster(
          File(file.path),
        );

        if (posterId != null) {
          _recognizedPosterId = posterId;
          _currentPoster = Poster.getPosters().firstWhere(
            (p) => p.id == posterId,
            orElse: () =>
                Poster(id: posterId, name: 'Poster $posterId', assetPath: ''),
          );

          final savedPoints = await _storageService.loadDrawing(posterId);
          _savedDrawingPoints = savedPoints;

          _state = ArState.posterRecognized;
        } else {
          _state = ArState.ready;
        }
      } else {
        _state = ArState.ready;
      }
    } catch (e) {
      debugPrint('Error scanning: $e');
      _state = ArState.ready;
    }

    _isScanning = false;
    notifyListeners();
  }

  void startDrawing() {
    if (_recognizedPosterId == null) return;
    _state = ArState.drawing;
    notifyListeners();
  }

  void addPoint(Offset point) {
    _drawingPoints.add(
      DrawingPoint(
        offset: point,
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        isNewStroke:
            _drawingPoints.isEmpty || _drawingPoints.last.offset.dx == 0,
      ),
    );
    notifyListeners();
  }

  void clearCurrentDrawing() {
    _drawingPoints = [];
    notifyListeners();
  }

  Future<void> saveDrawing() async {
    if (_recognizedPosterId == null) return;

    final allPoints = [..._savedDrawingPoints, ..._drawingPoints];
    await _storageService.saveDrawing(_recognizedPosterId!, allPoints);
    _savedDrawingPoints = allPoints;
    _drawingPoints = [];
    notifyListeners();
  }

  // Populate saved drawing points from a remote source (socket / DB)
  void updateSavedDrawingFromRemote(List<dynamic> drawings) {
    final merged = <DrawingPoint>[];
    for (final d in drawings) {
      // server may send graffiti with `linesData` or `points`
      final lines = d['linesData'] ?? d['points'] ?? [];
      if (lines is List) {
        for (final p in lines) {
          try {
            merged.add(DrawingPoint.fromJson(p as Map<String, dynamic>));
          } catch (e) {
            // ignore malformed points
          }
        }
      }
    }

    _savedDrawingPoints = merged;
    notifyListeners();
  }

  void appendSavedDrawingFromRemote(Map<String, dynamic> drawing) {
    final lines = drawing['linesData'] ?? drawing['points'] ?? [];
    if (lines is List) {
      for (final p in lines) {
        try {
          _savedDrawingPoints.add(
            DrawingPoint.fromJson(p as Map<String, dynamic>),
          );
        } catch (e) {}
      }
      notifyListeners();
    }
  }

  Future<void> clearSavedDrawing() async {
    if (_recognizedPosterId == null) return;

    await _storageService.clearDrawing(_recognizedPosterId!);
    _savedDrawingPoints = [];
    _drawingPoints = [];
    notifyListeners();
  }

  void setColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void resetRecognition() {
    _recognizedPosterId = null;
    _currentPoster = null;
    _savedDrawingPoints = [];
    _drawingPoints = [];
    _state = ArState.ready;
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _recognitionService.dispose();
    super.dispose();
  }
}
