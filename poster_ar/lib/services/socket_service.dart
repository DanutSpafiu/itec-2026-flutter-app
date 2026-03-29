import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class DrawingLine {
  final List<Map<String, dynamic>> points;
  final String color;
  final int size;
  final String userId;
  final String? userName;

  DrawingLine({
    required this.points,
    required this.color,
    required this.size,
    required this.userId,
    this.userName,
  });

  factory DrawingLine.fromJson(Map<String, dynamic> json) {
    // Server may send points under different keys (linesData, points)
    final rawPoints = json['points'] ?? json['linesData'] ?? [];
    List<Map<String, dynamic>> normalizedPoints = [];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map<String, dynamic>) {
          normalizedPoints.add(p);
        } else if (p is Map) {
          normalizedPoints.add(Map<String, dynamic>.from(p));
        } else {
          // ignore other types
        }
      }
    }

    return DrawingLine(
      points: normalizedPoints,
      color: json['color'] ?? '#FF6B6B',
      size: json['size'] ?? 12,
      userId: json['user']?['id'] ?? json['userId'] ?? '',
      userName: json['user']?['name'] ?? json['userName'],
    );
  }
}

class SocketService {
  // For Wi-Fi testing, use API_BASE_URL or SOCKET_SERVER_URL in .env.
  static String get _serverUrl {
    // Order of precedence:
    // 1. .env (flutter_dotenv)
    // 2. --dart-define=SOCKET_SERVER_URL
    // 3. .env API_BASE_URL (shared with HTTP auth)
    // 4. --dart-define=API_BASE_URL
    // 5. Android emulator special host
    // 6. localhost
    final envDot = dotenv.env['SOCKET_SERVER_URL'];
    if (envDot != null && envDot.isNotEmpty) return envDot;

    const envDefine = String.fromEnvironment('SOCKET_SERVER_URL');
    if (envDefine.isNotEmpty) return envDefine;

    final apiDot = dotenv.env['API_BASE_URL'];
    if (apiDot != null && apiDot.isNotEmpty) return apiDot;

    const apiDefine = String.fromEnvironment('API_BASE_URL');
    if (apiDefine.isNotEmpty) return apiDefine;

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:3000';
      } catch (e) {
        // fallback
      }
    }

    return 'http://localhost:3000';
  }

  io.Socket? _socket;
  String? _userId;
  String? _userName;
  String? _authUserName;
  String? _authDbUserId;
  bool _isConnected = false;

  final _connectionController = StreamController<bool>.broadcast();
  final _drawingHistoryController =
      StreamController<List<DrawingLine>>.broadcast();
  final _liveLineController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _remoteSaveController = StreamController<DrawingLine>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<DrawingLine>> get drawingHistoryStream =>
      _drawingHistoryController.stream;
  Stream<Map<String, dynamic>> get liveLineStream => _liveLineController.stream;
  Stream<DrawingLine> get remoteSaveStream => _remoteSaveController.stream;

  bool get isConnected => _isConnected;
  String? get userId => _userId;
  String? get userName => _userName;

  void connect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    debugPrint('Connecting to socket server: $_serverUrl');

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      _isConnected = true;
      _connectionController.add(true);
      if (_authUserName != null) {
        registerUser(_authUserName!, dbUserId: _authDbUserId);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      debugPrint('Socket connection error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.on('user_registered', (data) {
      _userId = data['userId'];
      _userName = data['userName'];
      debugPrint('User registered: $_userName ($_userId)');
    });

    _socket!.on('load_drawing_history', (data) {
      debugPrint('Received drawing history: ${data.length} drawings');
      final drawings = (data as List)
          .map((g) => DrawingLine.fromJson(g as Map<String, dynamic>))
          .toList();
      _drawingHistoryController.add(drawings);
    });

    _socket!.on('receive_live_line', (data) {
      _liveLineController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('remote_graffiti_saved', (data) {
      debugPrint('Remote graffiti saved');
      final drawing = DrawingLine.fromJson(data as Map<String, dynamic>);
      _remoteSaveController.add(drawing);
    });
  }

  void setAuthenticatedUser({required String name, required String dbUserId}) {
    _authUserName = name;
    _authDbUserId = dbUserId;

    if (_isConnected) {
      registerUser(name, dbUserId: dbUserId);
    }
  }

  void clearAuthenticatedUser() {
    _authUserName = null;
    _authDbUserId = null;
    _userId = null;
    _userName = null;
  }

  void registerUser(String name, {String? dbUserId}) {
    _socket?.emit('register_user', {'name': name, 'dbUserId': dbUserId});
  }

  void joinPosterRoom(String posterId) {
    _socket?.emit('phone_sees_poster', posterId);
    debugPrint('Joined poster room: $posterId');
  }

  void leavePosterRoom(String posterId) {
    _socket?.emit('phone_loses_poster', posterId);
    debugPrint('Left poster room: $posterId');
  }

  void sendLiveLine({
    required String posterId,
    required List<Map<String, dynamic>> points,
    required String color,
    required int size,
  }) {
    _socket?.emit('user_draws_line_live', {
      'posterId': posterId,
      'points': points,
      'color': color,
      'size': size,
    });
  }

  void saveDrawing({
    required String posterId,
    required String dbUserId,
    required List<Map<String, dynamic>> completeLineJSON,
    required String color,
    required int size,
  }) {
    _socket?.emit('phone_saves_final_drawing', {
      'posterId': posterId,
      'dbUserId': dbUserId,
      'completeLineJSON': completeLineJSON,
      'color': color,
      'size': size,
    });
    debugPrint('Saved drawing for poster: $posterId');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _drawingHistoryController.close();
    _liveLineController.close();
    _remoteSaveController.close();
  }
}
