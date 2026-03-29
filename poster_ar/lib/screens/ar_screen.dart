import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ar_provider.dart';
import '../widgets/camera_preview_widget.dart';
import 'poster_paint_screen.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

//C:\temp\poster_ar
class _ArScreenState extends State<ArScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArProvider>().initialize();
    });
  }

  void _navigateToPaintScreen() {
    final arProvider = context.read<ArProvider>();
    if (arProvider.currentPoster != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PosterPaintScreen(poster: arProvider.currentPoster!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: const Text('Scanare AR', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ArProvider>(
        builder: (context, provider, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (provider.cameraController != null &&
                  provider.cameraController!.value.isInitialized)
                CameraPreviewWidget(controller: provider.cameraController!)
              else
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE94560)),
                      SizedBox(height: 16),
                      Text(
                        'Se initializeaza camera...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

              if (provider.state == ArState.scanning)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFE94560)),
                        SizedBox(height: 16),
                        Text(
                          'Se scaneaza posterul...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Positioned(
                bottom: 30,
                left: 16,
                right: 16,
                child: _buildScanButton(context, provider),
              ),

              if (provider.currentPoster != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: GestureDetector(
                      onTap: _navigateToPaintScreen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0F3460,
                          ).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE94560,
                              ).withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00FF87),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.currentPoster?.name ??
                                      'Poster Recunoscut',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Apasa pentru a desena',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.arrow_forward,
                              color: Color(0xFFE94560),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScanButton(BuildContext context, ArProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.currentPoster != null) ...[
          TextButton.icon(
            onPressed: _navigateToPaintScreen,
            icon: const Icon(Icons.brush, color: Colors.white),
            label: const Text(
              'Deseneaza pe acest poster',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: provider.isScanning
                ? null
                : () {
                    if (provider.state == ArState.posterRecognized) {
                      provider.resetRecognition();
                    } else {
                      provider.scanForPoster();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.state == ArState.scanning
                  ? Colors.grey
                  : const Color(0xFF0F3460),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: Icon(
              provider.currentPoster != null
                  ? Icons.qr_code_scanner
                  : Icons.search,
              color: Colors.white,
            ),
            label: Text(
              provider.currentPoster != null ? 'Scan Again' : 'Scan Poster',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
