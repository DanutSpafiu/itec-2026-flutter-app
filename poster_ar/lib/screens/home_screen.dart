import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/socket_provider.dart';
import '../providers/ar_provider.dart';
import '../models/poster.dart';
import 'poster_paint_screen.dart';
import 'ar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndConnect();
    });
  }

  Future<void> _checkPermissionsAndConnect() async {
    final socketProvider = context.read<SocketProvider>();
    await socketProvider.initialize();

    final status = await Permission.camera.status;
    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isChecking = false;
      });
    } else {
      final result = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _hasPermission = result.isGranted;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: _isChecking
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE94560)),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Icon(
                      Icons.view_in_ar,
                      size: 60,
                      color: Color(0xFFE94560),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Poster AR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Alege un afis si deseneaza pe el',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_hasPermission)
                      _buildOptionButton(
                        icon: Icons.qr_code_scanner,
                        title: 'Scanare AR',
                        subtitle: 'Scaneaza un poster cu camera',
                        color: const Color(0xFFE94560),
                        onTap: () {
                          context.read<ArProvider>().resetRecognition();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ArScreen(),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.no_photography,
                              color: Colors.red,
                              size: 32,
                            ),
                            Text(
                              'Camera nu este permisa',
                              style: TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    const Text(
                      'Sau alege direct din galerie:',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),

                    Expanded(child: _PosterGrid()),

                    const SizedBox(height: 8),
                    Consumer<SocketProvider>(
                      builder: (context, socketProvider, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              socketProvider.isConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: socketProvider.isConnected
                                  ? Colors.green
                                  : Colors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              socketProvider.isConnected
                                  ? 'Server conectat'
                                  : 'Server deconectat',
                              style: TextStyle(
                                color: socketProvider.isConnected
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PosterGrid extends StatelessWidget {
  const _PosterGrid();

  @override
  Widget build(BuildContext context) {
    final posters = Poster.getPosters();
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: posters.length,
      itemBuilder: (context, index) {
        final poster = posters[index];
        return _PosterCard(poster: poster);
      },
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Poster poster;
  const _PosterCard({required this.poster});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PosterPaintScreen(poster: poster),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.asset(
                  poster.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                color: Color(0xFF1A1A2E),
              ),
              child: Text(
                poster.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
