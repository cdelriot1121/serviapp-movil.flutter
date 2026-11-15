import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../splash/presentation/painters/trazos.dart';

/// Segundos transcurridos desde que se abrió la pantalla; mueven la escena.
mixin RelojEscena<T extends StatefulWidget>
    on SingleTickerProviderStateMixin<T> {
  final ValueNotifier<double> tiempo = ValueNotifier(0);

  late final Ticker _reloj = createTicker(
    (transcurrido) => tiempo.value = transcurrido.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _reloj.start();
  }

  @override
  void dispose() {
    _reloj.dispose();
    tiempo.dispose();
    super.dispose();
  }
}

/// Encabezado con sol, hojas que caen en cascada y agua que se funde con el
/// fondo crema de la página. [cantidadHojas] y [destellos] regulan cuánta
/// vida tiene: el inicio usa la escena completa y el login una más calmada.
class EncabezadoNaturaleza extends StatelessWidget {
  final ValueNotifier<double> tiempo;
  final int cantidadHojas;
  final bool destellos;
  final Widget child;

  const EncabezadoNaturaleza({
    super.key,
    required this.tiempo,
    required this.child,
    this.cantidadHojas = 20,
    this.destellos = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.naturaleza),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _NaturalezaPainter(
                    tiempo,
                    cantidadHojas: cantidadHojas,
                    destellos: destellos,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// Hoja que cae: posición horizontal, velocidad, tamaño, vaivén y color.
typedef _Hoja = ({
  double x,
  double velocidad,
  double largo,
  double vaiven,
  double frecuencia,
  double giro,
  double fase,
  double opacidad,
  int tono,
});

// Degradados de las hojas: verde fresco, verde claro y amarillo sol.
const _tonosHoja = [
  (clara: AppColors.leafLight, oscura: AppColors.green),
  (clara: Color(0xFFEAF8DD), oscura: AppColors.leafLight),
  (clara: Color(0xFFFFE9A8), oscura: AppColors.sun),
];

class _NaturalezaPainter extends CustomPainter {
  _NaturalezaPainter(
    this.tiempo, {
    required int cantidadHojas,
    required this.destellos,
  }) : _hojas = _cache.putIfAbsent(
         cantidadHojas,
         () => _generarHojas(cantidadHojas, 7),
       ),
       super(repaint: tiempo);

  final ValueNotifier<double> tiempo;
  final bool destellos;
  final List<_Hoja> _hojas;

  static final Map<int, List<_Hoja>> _cache = {};

  static List<_Hoja> _generarHojas(int cantidad, int semilla) {
    final azar = math.Random(semilla);
    return List.generate(cantidad, (i) {
      // Las más grandes están "más cerca": caen más rápido y se ven más.
      final cercania = azar.nextDouble();
      return (
        x: (i + azar.nextDouble()) / cantidad,
        velocidad: 16 + cercania * 26,
        largo: 11 + cercania * 15,
        vaiven: 10 + azar.nextDouble() * 18,
        frecuencia: 0.5 + azar.nextDouble() * 0.6,
        giro: (azar.nextBool() ? 1 : -1) * (0.15 + azar.nextDouble() * 0.35),
        fase: azar.nextDouble(),
        opacidad: 0.55 + cercania * 0.4,
        tono: azar.nextInt(_tonosHoja.length),
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = tiempo.value;
    final w = size.width;
    final h = size.height;

    // Sol cálido en la esquina, con un pulso lento.
    final sol = Offset(w * 0.88, h * 0.06);
    final pulso = 1 + 0.06 * math.sin(t * 0.8);
    dibujarHalo(canvas, sol, 150 * pulso, AppColors.sun, 0.42);
    dibujarHalo(canvas, sol, 60 * pulso, Colors.white, 0.35);

    // Destellos de luz que flotan cerca del sol.
    if (destellos) {
      for (var k = 0; k < 4; k++) {
        final brillo = math.sin(t * 0.9 + k * 1.7);
        final punto = Offset(
          w * (0.62 + 0.09 * k) + math.sin(t * 0.3 + k) * 6,
          h * (0.12 + 0.11 * (k % 2)) + math.cos(t * 0.25 + k) * 4,
        );
        dibujarHalo(
          canvas,
          punto,
          7 + 3 * k.toDouble(),
          Colors.white,
          0.10 + 0.08 * brillo,
        );
      }
    }

    // Hojas en cascada; desaparecen al tocar el agua.
    final suelo = h - 30;
    for (final hoja in _hojas) {
      final recorrido = suelo + hoja.largo * 2;
      final y =
          (hoja.fase * recorrido + t * hoja.velocidad) % recorrido - hoja.largo;
      final x =
          hoja.x * w +
          math.sin(t * hoja.frecuencia + hoja.fase * 2 * math.pi) * hoja.vaiven;
      final angulo =
          hoja.fase * 2 * math.pi +
          math.sin(t * hoja.frecuencia * 0.9 + hoja.fase * 5) * 0.9 +
          t * hoja.giro;
      // El volteo simula la hoja girando en el aire.
      final volteo =
          0.45 +
          0.55 * math.cos(t * hoja.frecuencia * 1.6 + hoja.fase * 9).abs();
      final tono = _tonosHoja[hoja.tono];

      canvas.save();
      canvas.translate(x, y);
      canvas.scale(volteo, 1);
      dibujarHoja(
        canvas,
        Offset.zero,
        hoja.largo,
        angulo,
        hoja.opacidad,
        clara: tono.clara,
        oscura: tono.oscura,
      );
      canvas.restore();
    }

    // Agua: una ola translúcida detrás y la crema de la página delante.
    _ola(
      canvas,
      size,
      base: h - 40,
      amplitud: 8,
      ondas: 1.3,
      desfase: t * 0.7,
      color: Colors.white.withValues(alpha: 0.22),
    );
    _ola(
      canvas,
      size,
      base: h - 24,
      amplitud: 7,
      ondas: 1.1,
      desfase: -t * 0.5 + 1.5,
      color: AppColors.cream,
    );
  }

  void _ola(
    Canvas canvas,
    Size size, {
    required double base,
    required double amplitud,
    required double ondas,
    required double desfase,
    required Color color,
  }) {
    final camino = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 6; x += 6) {
      final y =
          base +
          math.sin(x / size.width * 2 * math.pi * ondas + desfase) * amplitud;
      camino.lineTo(x, y);
    }
    camino
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(camino, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NaturalezaPainter oldDelegate) =>
      oldDelegate.tiempo != tiempo ||
      oldDelegate.destellos != destellos ||
      oldDelegate._hojas != _hojas;
}
