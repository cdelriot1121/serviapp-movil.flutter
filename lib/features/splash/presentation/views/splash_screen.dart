import 'package:flutter/material.dart';
import '../widgets/glass_receipt.dart';
import '../widgets/orbital_services.dart';
import '../../../auth/presentation/views/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _fusionController;
  
  bool _showReceipt = false;
  bool _fusionStarted = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fusionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fusionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(), 
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
    _startIntro();
  }

  Future<void> _startIntro() async {
    await _logoController.forward();
    if (!mounted) return;
    setState(() => _showReceipt = true);
  }

  // Secuencia final (Sin audio)
  void _onScanCompleted() {
    if (!mounted || _fusionStarted) return;
    _fusionStarted = true;
    _fusionController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fusionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030914), 
      body: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: StaticGridPainter(),
          ),
          if (!_showReceipt)
            FadeTransition(
              opacity: _logoController,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_graph_rounded, color: Colors.cyanAccent, size: 90),
                  SizedBox(height: 20),
                  Text(
                    'SERVIAPP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),
          if (_showReceipt)
            AnimatedBuilder(
              animation: _fusionController,
              builder: (context, child) {
                final opacity = _fusionController.value > 0.7 ? 0.0 : 1.0;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: opacity,
                  child: child,
                );
              },
              child: GlassReceipt(
                onScanCompleted: _onScanCompleted, 
              ),
            ),
          if (_showReceipt)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _fusionController,
                builder: (context, child) {
                  return OrbitalServices(progress: _fusionController.value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class StaticGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    const double gridSize = 50.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant StaticGridPainter oldDelegate) => false;
}