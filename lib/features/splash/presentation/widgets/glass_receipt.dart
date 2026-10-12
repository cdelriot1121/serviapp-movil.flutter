import 'dart:ui';
import 'package:flutter/material.dart';
// Importamos el painter subiendo una carpeta y entrando a painters
import '../painters/scan_painter.dart';

class GlassReceipt extends StatefulWidget {
  final VoidCallback? onScanCompleted;
  const GlassReceipt({super.key, this.onScanCompleted});

  @override
  State<GlassReceipt> createState() => _GlassReceiptState();
}

class _GlassReceiptState extends State<GlassReceipt> with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _startSequence();
  }

  Future<void> _startSequence() async {
    await _revealController.forward();
    if (!mounted) return;
    await _scanController.forward();
    if (!mounted) return;
    widget.onScanCompleted?.call();
  }

  @override
  void dispose() {
    _revealController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _revealController,
        builder: (context, child) {
          final scale = Curves.easeOutBack.transform(_revealController.value);
          return Transform(
            alignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(0.2 * (1 - scale))
              ..scale(scale),
            child: Opacity(
              opacity: _revealController.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: SizedBox(
          width: 260,
          height: 380,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: -5)
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: _buildUI(),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      return CustomPaint(painter: ScanPainter(progress: _scanController.value));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.memory, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              'ANÁLISIS DE CONSUMO',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTechLine(150),
        const SizedBox(height: 12),
        _buildTechLine(200),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AnimatedBar(height: 60, delay: 0.2, color: Colors.cyanAccent, label: 'AGU'),
            _AnimatedBar(height: 100, delay: 0.4, color: Colors.amberAccent, label: 'ENE'),
            _AnimatedBar(height: 80, delay: 0.6, color: Colors.greenAccent, label: 'GAS'),
          ],
        ),
        const Spacer(),
        _buildTechLine(180),
      ],
    );
  }

  Widget _buildTechLine(double width) {
    return Container(
      width: width, height: 4,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final double height; final double delay; final Color color; final String label;
  const _AnimatedBar({required this.height, required this.delay, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        final currentVal = (value * 100).toInt();
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$currentVal%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: 25, height: height * value,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1))
          ],
        );
      },
    );
  }
}