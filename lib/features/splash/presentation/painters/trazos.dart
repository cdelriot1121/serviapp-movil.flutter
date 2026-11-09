import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'splash_timeline.dart';

// Piezas de dibujo reutilizadas por los painters del splash. Los brillos se
// hacen con gradientes radiales (no con blur) para que la animación vaya
// fluida incluso en teléfonos modestos.

/// Onda de agua vista en perspectiva: una elipse clara con su sombra.
void dibujarOnda(Canvas canvas, Offset centro, double radio, double opacidad,
    {double aplanado = 0.3, double grosor = 1.8}) {
  if (opacidad <= 0.01 || radio <= 0.5) return;
  final rect = Rect.fromCenter(center: centro, width: radio * 2, height: radio * 2 * aplanado);
  canvas.drawOval(
    rect.shift(Offset(0, grosor * 1.2)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor * 1.8
      ..color = Paleta.aguaOscura.withValues(alpha: opacidad * 0.3),
  );
  canvas.drawOval(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = Paleta.espuma.withValues(alpha: opacidad * 0.95),
  );
}

/// Gota en forma de lágrima; [centro] es el centro de su parte redonda.
void dibujarGota(Canvas canvas, Offset centro, double radio, double opacidad, {double estiramiento = 1}) {
  if (opacidad <= 0.01 || radio <= 0.3) return;
  final punta = centro.dy - radio * (1.6 + 1.2 * estiramiento);
  final forma = Path()
    ..moveTo(centro.dx, punta)
    ..quadraticBezierTo(centro.dx + radio * 1.05, centro.dy - radio * 0.7, centro.dx + radio, centro.dy)
    ..arcToPoint(Offset(centro.dx - radio, centro.dy), radius: Radius.circular(radio))
    ..quadraticBezierTo(centro.dx - radio * 1.05, centro.dy - radio * 0.7, centro.dx, punta)
    ..close();
  canvas.drawPath(
    forma,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, 0.3),
        radius: 0.9,
        colors: [
          Paleta.espuma.withValues(alpha: opacidad),
          Paleta.agua.withValues(alpha: opacidad * 0.85),
          Paleta.aguaOscura.withValues(alpha: opacidad * 0.9),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(forma.getBounds()),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: centro + Offset(-radio * 0.35, -radio * 0.2),
      width: radio * 0.5,
      height: radio * 0.8,
    ),
    Paint()..color = Paleta.blanco.withValues(alpha: opacidad * 0.9),
  );
}

/// Gotita o burbuja redonda con reflejo.
void dibujarBurbuja(Canvas canvas, Offset centro, double radio, double opacidad) {
  if (opacidad <= 0.01 || radio <= 0.2) return;
  if (radio < 2.2) {
    canvas.drawCircle(centro, radio, Paint()..color = Paleta.agua.withValues(alpha: opacidad * 0.9));
    return;
  }
  canvas.drawCircle(
    centro,
    radio,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        colors: [
          Paleta.blanco.withValues(alpha: opacidad),
          Paleta.agua.withValues(alpha: opacidad * 0.55),
          Paleta.aguaOscura.withValues(alpha: opacidad * 0.75),
        ],
        stops: const [0, 0.6, 1],
      ).createShader(Rect.fromCircle(center: centro, radius: radio)),
  );
}

/// Hoja con nervadura central; [angulo] en radianes.
void dibujarHoja(Canvas canvas, Offset centro, double largo, double angulo, double opacidad) {
  if (opacidad <= 0.01 || largo <= 0.5) return;
  final m = largo / 2;
  canvas.save();
  canvas.translate(centro.dx, centro.dy);
  canvas.rotate(angulo);
  final forma = Path()
    ..moveTo(-m, 0)
    ..quadraticBezierTo(-m * 0.1, -largo * 0.42, m, 0)
    ..quadraticBezierTo(-m * 0.1, largo * 0.36, -m, 0)
    ..close();
  canvas.drawPath(
    forma,
    Paint()
      ..shader = LinearGradient(colors: [
        Paleta.hojaClara.withValues(alpha: opacidad),
        Paleta.hoja.withValues(alpha: opacidad),
      ]).createShader(Rect.fromLTRB(-m, -largo * 0.3, m, largo * 0.3)),
  );
  canvas.drawLine(
    Offset(-m * 0.9, 0),
    Offset(m * 0.8, -largo * 0.02),
    Paint()
      ..color = const Color(0xFFEAF8DD).withValues(alpha: opacidad * 0.7)
      ..strokeWidth = math.max(0.6, largo * 0.04),
  );
  canvas.restore();
}

/// Halo de luz suave.
void dibujarHalo(Canvas canvas, Offset centro, double radio, Color color, double opacidad) {
  if (opacidad <= 0.01 || radio <= 0.5) return;
  canvas.drawCircle(
    centro,
    radio,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacidad),
          color.withValues(alpha: opacidad * 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: centro, radius: radio)),
  );
}

/// Destello de cuatro puntas.
void dibujarDestello(Canvas canvas, Offset centro, double tam, double opacidad) {
  if (opacidad <= 0.01 || tam <= 0.3) return;
  dibujarHalo(canvas, centro, tam * 1.1, Paleta.blanco, opacidad * 0.6);
  final x = centro.dx;
  final y = centro.dy;
  final rayos = Path()
    ..moveTo(x, y - tam)
    ..quadraticBezierTo(x, y, x + tam, y)
    ..quadraticBezierTo(x, y, x, y + tam)
    ..quadraticBezierTo(x, y, x - tam, y)
    ..quadraticBezierTo(x, y, x, y - tam)
    ..close();
  canvas.drawPath(rayos, Paint()..color = Paleta.blanco.withValues(alpha: opacidad));
}

/// Gotitas que saltan en parábola desde [origen]; [u] son los segundos desde
/// el impacto y [escala] el tamaño de la salpicadura.
void dibujarSalpicadura(Canvas canvas, Offset origen, double u, double escala, int semilla,
    {int cantidad = 10}) {
  const vida = 0.65;
  if (u < 0 || u > vida) return;
  final azar = math.Random(semilla);
  final gravedad = 520 * escala;
  for (var i = 0; i < cantidad; i++) {
    final angulo = math.pi * (0.12 + 0.76 * (i + azar.nextDouble() * 0.6) / cantidad);
    final velocidad = escala * (110 + azar.nextDouble() * 110);
    final radio = escala * (1.2 + azar.nextDouble() * 1.6) * (1 - u / vida * 0.5);
    final posicion = origen +
        Offset(
          math.cos(angulo) * velocidad * u,
          -math.sin(angulo) * velocidad * u + gravedad * u * u,
        );
    // La gotita que vuelve al agua desaparece en ella.
    if (posicion.dy > origen.dy + radio) continue;
    dibujarBurbuja(canvas, posicion, radio, 1 - intervalo(u, vida * 0.45, vida));
  }
}
