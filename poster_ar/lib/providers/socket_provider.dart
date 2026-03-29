import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/socket_service.dart';

class SocketProvider extends ChangeNotifier {
  final SocketService _socketService = SocketService();
  bool _isInitialized = false;
  StreamSubscription<bool>? _connectionSubscription;

  SocketService get socketService => _socketService;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _socketService.isConnected;
  String? get userId => _socketService.userId;
  String? get userName => _socketService.userName;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _connectionSubscription = _socketService.connectionStream.listen((_) {
      notifyListeners();
    });

    _socketService.connect();
    _isInitialized = true;
    notifyListeners();
  }

  void setAuthenticatedUser({required String name, required String dbUserId}) {
    _socketService.setAuthenticatedUser(name: name, dbUserId: dbUserId);
    notifyListeners();
  }

  void logout() {
    _socketService.clearAuthenticatedUser();
    _socketService.disconnect();
    _isInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }
}
