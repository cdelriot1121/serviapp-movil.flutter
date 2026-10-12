import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScanPainter extends CustomPainter {
  final double progress;

  ScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final double scanY = size.height * progress;

    // ========================================================
    // 1. CONO DE PROYECCIÓN HOLOGRÁFICA (Luz desde arriba)
    // ========================================================
    final conePath = Path()
      ..moveTo(size.width / 2, -50) // Origen focal arriba del recibo
      ..lineTo(-20, scanY)
      ..lineTo(size.width + 20, scanY)
      ..close();

    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyanAccent.withValues(alpha: 0.0),
          Colors.cyanAccent.withValues(alpha: 0.05),
          Colors.cyanAccent.withValues(alpha: 0.20),
        ],
      ).createShader(conePath.getBounds());
    
    canvas.drawPath(conePath, conePaint);

    // ========================================================
    // 2. FRAGMENTACIÓN DE DATOS (Efecto Matrix de bits subiendo)
    // ========================================================
    final particlePaint = Paint()..style = PaintingStyle.fill;
    // Semilla fija para que los cuadritos no parpadeen, solo fluyan
    final math.Random rand = math.Random(12345); 
    
    for (int i = 0; i < 40; i++) {
      final x = rand.nextDouble() * size.width;
      final speed = 0.5 + rand.nextDouble(); // Velocidad aleatoria
      
      // Calculamos qué tan arriba del láser está el bit
      final distY = (progress * 600 * speed) % 80; 
      final y = scanY - distY;
      
      if (y > 0 && y < scanY) {
        // Se desvanecen a medida que suben
        final opacity = (1.0 - (distY / 80)).clamp(0.0, 1.0);
        
        // Mezclamos aleatoriamente los colores de Agua, Energía y Gas
        final colorChoice = rand.nextInt(3);
        Color pColor = Colors.cyanAccent;
        if (colorChoice == 1) pColor = Colors.amberAccent;
        if (colorChoice == 2) pColor = Colors.greenAccent;

        particlePaint.color = pColor.withValues(alpha: opacity);
        
        // Dibujamos el "bit" de datos como un pequeño bloque digital
        final sizeBit = 1.5 + rand.nextDouble() * 3.0;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: sizeBit, height: sizeBit), 
          particlePaint
        );
      }
    }

    // ========================================================
    // 3. LÁSER DE FUSIÓN DE SERVICIOS (Agua, Energía, Gas)
    // ========================================================
    final laserPaint = Paint()
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.cyanAccent,  // Agua
          Colors.amberAccent, // Energía
          Colors.greenAccent, // Gas
          Colors.cyanAccent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 1));

    // Glow extremo de la base
    final extremeGlow = Paint()
      ..strokeWidth = 20.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..shader = laserPaint.shader;
      
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), extremeGlow);
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), laserPaint);

    // ========================================================
    // 4. ONDA DE ANÁLISIS VIVA (Osciloscopio / Electricidad)
    // ========================================================
    final wavePath = Path();
    wavePath.moveTo(0, scanY);
    
    // El tiempo hace que la onda se mueva hacia la derecha furiosamente
    final time = progress * 20 * math.pi; 
    
    for (double i = 0; i <= size.width; i += 2) {
      // Combinación matemática de dos ondas para crear un efecto caótico y vibrante
      final wave1 = math.sin(i * 0.04 - time) * 6; // Amplitud mayor
      final wave2 = math.cos(i * 0.12 + time) * 3; // Detalle rápido
      
      // Reducimos la onda en los bordes para que no se salga de la pantalla
      final edgeFade = math.sin((i / size.width) * math.pi);
      
      wavePath.lineTo(i, scanY + ((wave1 + wave2) * edgeFade));
    }

    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    canvas.drawPath(wavePath, wavePaint);

    // ========================================================
    // 5. MIRAS DE FIJACIÓN HOLOGRÁFICAS (Cruces Tácticas)
    // ========================================================
    void drawCrosshair(Offset center) {
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      const d = 8.0; // Tamaño de la cruz
      
      // Líneas cruzadas
      canvas.drawLine(Offset(center.dx - d, center.dy), Offset(center.dx + d, center.dy), paint);
      canvas.drawLine(Offset(center.dx, center.dy - d), Offset(center.dx, center.dy + d), paint);
      
      // Anillo de enfoque y resplandor
      canvas.drawCircle(center, d * 1.8, paint..color = Colors.cyanAccent.withValues(alpha: 0.6));
      canvas.drawCircle(center, 2, paint..style = PaintingStyle.fill..color = Colors.white);
    }

    // Dibujamos las miras un poco hacia adentro de los bordes
    drawCrosshair(Offset(15, scanY));
    drawCrosshair(Offset(size.width - 15, scanY));
  }

  @override
  bool shouldRepaint(covariant ScanPainter oldDelegate) {
    // Repintamos en cada fotograma del progreso
    return oldDelegate.progress != progress;
  }
}