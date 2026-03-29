import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drawing_point.dart';
import '../models/poster.dart';
import '../providers/auth_provider.dart';
import '../providers/socket_provider.dart';
import '../services/drawing_storage_service.dart';
import '../services/socket_service.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';

class PosterPaintScreen extends StatefulWidget {
  final Poster poster;

  const PosterPaintScreen({super.key, required this.poster});

  @override
  State<PosterPaintScreen> createState() => _PosterPaintScreenState();
}

class _PosterPaintScreenState extends State<PosterPaintScreen> {
  final DrawingStorageService _storageService = DrawingStorageService();

  List<DrawingPoint> _savedPoints = [];
  List<DrawingPoint> _currentPoints = [];

  Color _selectedColor = const Color(0xFFE94560);
  double _strokeWidth = 8.0;
  bool _isLoading = true;
  bool _isSaving = false;
  SocketService? _socketService;
  StreamSubscription? _historySub;
  StreamSubscription? _remoteSaveSub;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();
    _loadDrawing();
    // Join socket room if connected and subscribe to history/remote saves
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final sp = context.read<SocketProvider>();
        // Ensure socket provider is initialized when opening the paint screen
        sp.initialize();
        _socketService = sp.socketService;
        if (_socketService != null) {
          // If already connected, join immediately; otherwise wait for connection
          if (_socketService!.isConnected) {
            _socketService!.joinPosterRoom(widget.poster.id);
          } else {
            _connectionSub = _socketService!.connectionStream.listen((
              connected,
            ) {
              if (connected) {
                _socketService!.joinPosterRoom(widget.poster.id);
                _connectionSub?.cancel();
                _connectionSub = null;
              }
            });
          }

          // Register listeners (idempotent)
          _registerSocketListeners();
        }
      } catch (e) {
        // ignore
      }
    });
  }

  void _registerSocketListeners() {
    if (_socketService == null) return;

    _historySub ??= _socketService!.drawingHistoryStream.listen((drawings) {
      final merged = <DrawingPoint>[];
      for (final d in drawings) {
        final pts = (d as dynamic).points as List? ?? [];
        for (final p in pts) {
          try {
            merged.add(DrawingPoint.fromJson(p as Map<String, dynamic>));
          } catch (e) {}
        }
      }
      setState(() {
        _savedPoints = merged;
      });
    });

    _remoteSaveSub ??= _socketService!.remoteSaveStream.listen((dl) {
      final pts = (dl as dynamic).points as List? ?? [];
      final added = <DrawingPoint>[];
      for (final p in pts) {
        try {
          added.add(DrawingPoint.fromJson(p as Map<String, dynamic>));
        } catch (e) {}
      }
      if (added.isNotEmpty) {
        setState(() {
          _savedPoints = [..._savedPoints, ...added];
        });
      }
    });
  }

  Future<void> _loadDrawing() async {
    final points = await _storageService.loadDrawing(widget.poster.id);
    if (!mounted) return;
    setState(() {
      _savedPoints = points;
      _isLoading = false;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPoints.add(
        DrawingPoint(
          offset: details.localPosition,
          color: _selectedColor,
          strokeWidth: _strokeWidth,
          isNewStroke: true,
        ),
      );
    });
    // emit live line start
    try {
      if (_socketService != null && _socketService!.isConnected) {
        final last = _currentPoints.last;
        _socketService!.sendLiveLine(
          posterId: widget.poster.id,
          points: [last.toJson()],
          color:
              '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
          size: _strokeWidth.toInt(),
        );
      }
    } catch (e) {}
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoints.add(
        DrawingPoint(
          offset: details.localPosition,
          color: _selectedColor,
          strokeWidth: _strokeWidth,
          isNewStroke: false,
        ),
      );
    });
    // emit live point
    try {
      if (_socketService != null && _socketService!.isConnected) {
        final last = _currentPoints.last;
        _socketService!.sendLiveLine(
          posterId: widget.poster.id,
          points: [last.toJson()],
          color:
              '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
          size: _strokeWidth.toInt(),
        );
      }
    } catch (e) {}
  }

  void _undoCurrentStroke() {
    if (_currentPoints.isEmpty) return;

    var index = _currentPoints.length - 1;
    while (index > 0 && !_currentPoints[index].isNewStroke) {
      index--;
    }

    setState(() {
      _currentPoints.removeRange(index, _currentPoints.length);
    });
  }

  void _clearUnsaved() {
    if (_currentPoints.isEmpty) return;
    setState(() {
      _currentPoints = [];
    });
  }

  Future<void> _saveDrawing() async {
    if (_currentPoints.isEmpty || _isSaving) return;

    final authProvider = context.read<AuthProvider>();
    final socketProvider = context.read<SocketProvider>();
    final currentUser = authProvider.user;

    setState(() {
      _isSaving = true;
    });

    try {
      final merged = [..._savedPoints, ..._currentPoints];
      await _storageService.saveDrawing(widget.poster.id, merged);

      // Keep local save behavior unchanged, but also push vector data to backend.
      if (currentUser != null && socketProvider.isConnected) {
        final vectorPoints = _currentPoints
            .map(
              (point) => {
                'dx': point.offset.dx,
                'dy': point.offset.dy,
                'color': point.color.toARGB32(),
                'strokeWidth': point.strokeWidth,
                'isNewStroke': point.isNewStroke,
              },
            )
            .toList();

        final firstPoint = _currentPoints.first;
        socketProvider.socketService.saveDrawing(
          posterId: widget.poster.id,
          dbUserId: currentUser.id,
          completeLineJSON: vectorPoints,
          color:
              '#${firstPoint.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          size: firstPoint.strokeWidth.round(),
        );
      }

      if (!mounted) return;

      setState(() {
        _savedPoints = merged;
        _currentPoints = [];
      });

      // Also emit to socket server so other devices receive and server saves to DB
      try {
        final socketService = context.read<SocketProvider>().socketService;
        if (socketService.isConnected) {
          final jsonPoints = merged.map((p) => p.toJson()).toList();
          // convert color to hex #RRGGBB
          final hex =
              '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
          socketService.saveDrawing(
            posterId: widget.poster.id,
            dbUserId: socketService.userId ?? '',
            completeLineJSON: jsonPoints,
            color: hex,
            size: _strokeWidth.toInt(),
          );
        }
      } catch (e) {
        // non-fatal
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desenul a fost salvat pentru acest afiș.'),
          backgroundColor: Color(0xFF00FF87),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la salvare: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _remoteSaveSub?.cancel();
    // leave room
    try {
      if (_socketService != null && _socketService!.isConnected) {
        _socketService!.leavePosterRoom(widget.poster.id);
      }
    } catch (e) {}
    super.dispose();
  }

  Future<void> _clearSavedDrawing() async {
    try {
      await _storageService.clearDrawing(widget.poster.id);
      if (!mounted) return;

      setState(() {
        _savedPoints = [];
        _currentPoints = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desenul a fost șters de pe acest afiș.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la ștergere: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Șterge desenul?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Se vor șterge toate liniile salvate pentru acest afiș.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearSavedDrawing();
            },
            child: const Text('Șterge', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = <DrawingPoint>[..._savedPoints, ..._currentPoints];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: Text(
          widget.poster.name,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _currentPoints.isNotEmpty ? _undoCurrentStroke : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: _currentPoints.isNotEmpty ? _clearUnsaved : null,
            tooltip: 'Curăță modificările curente',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _savedPoints.isNotEmpty ? _showClearDialog : null,
            tooltip: 'Șterge desenul salvat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE94560)),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              widget.poster.assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 64,
                                  ),
                                );
                              },
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _DrawingPainter(points: allPoints),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildToolbar(),
              ],
            ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorButton(const Color(0xFFE94560)),
                _buildColorButton(const Color(0xFF00FF87)),
                _buildColorButton(const Color(0xFFFFD700)),
                _buildColorButton(const Color(0xFF00BFFF)),
                _buildColorButton(const Color(0xFF9B59B6)),
                _buildColorButton(const Color(0xFF2C3E50)),
                _buildColorButton(Colors.white),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.brush, color: Colors.white54, size: 20),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 2,
                    max: 30,
                    activeColor: _selectedColor,
                    inactiveColor: Colors.grey,
                    onChanged: (value) {
                      setState(() {
                        _strokeWidth = value;
                      });
                    },
                  ),
                ),
                Text(
                  '${_strokeWidth.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const CircularProgressIndicator(
                    color: Color(0xFFE94560),
                    strokeWidth: 2,
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _currentPoints.isNotEmpty ? _saveDrawing : null,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Salvează pe afiș'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF87),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  const _DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length; i++) {
      final current = points[i];

      if (current.isNewStroke || i == points.length - 1) {
        canvas.drawCircle(
          current.offset,
          current.strokeWidth / 2,
          Paint()
            ..color = current.color
            ..style = PaintingStyle.fill,
        );
        continue;
      }

      final next = points[i + 1];
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
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
