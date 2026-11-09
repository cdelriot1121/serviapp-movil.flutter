import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'splash_timeline.dart';
import 'trazos.dart';

typedef _Particula = ({double x, double y, double tam, double vel, double fase});

List<_Particula> _generar(int cantidad, int semilla) {
  final azar = math.Random(semilla);
  return List.generate(
    cantidad,
    (_) => (
      x: azar.nextDouble(),
      y: azar.nextDouble(),
      tam: azar.nextDouble(),
      vel: azar.nextDouble(),
      fase: azar.nextDouble() * math.pi * 2,
    ),
  );
}

/// Ambiente de la intro: cielo claro, agua, ondas de energía, burbujas,
/// partículas de gas, ramas y hojas. Todo es sutil y queda detrás de las letras.
class FondoPainter extends CustomPainter {
  FondoPainter(this.tiempo) : super(repaint: tiempo);

  final ValueListenable<double> tiempo;

  static final _luces = _generar(7, 9);
  static final _burbujas = _generar(22, 5);
  static final _hojas = _generar(14, 3);
  static final _chispas = _generar(16, 13);

  Shader? _shaderCielo;
  Size? _tamCielo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tiempo.value;
    final e = Escena.de(size);
    _cielo(canvas, size, t);
    _lucesBokeh(canvas, size, t);
    _ondas(canvas, e, t);
    _cintasDeEnergia(canvas, size, t);
    _gotas(canvas, e, t);
    _burbujasYGas(canvas, size, t);
    _ramas(canvas, size, t);
    _hojasFlotando(canvas, size, t);
    _titileos(canvas, size, t);
  }

  void _cielo(Canvas canvas, Size size, double t) {
    if (_tamCielo != size) {
      _tamCielo = size;
      _shaderCielo = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: Paleta.cielo,
        stops: [0, 0.38, 0.72, 1],
      ).createShader(Offset.zero & size);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = _shaderCielo);
    // Luz cálida que entra desde arriba y reflejo frío del agua abajo.
    dibujarHalo(canvas, Offset(size.width * 0.18, size.height * 0.05), size.width * 0.95,
        const Color(0xFFFFF7E3), 0.55 + 0.1 * math.sin(t * 0.8));
    dibujarHalo(canvas, Offset(size.width * 0.7, size.height * 1.02), size.width * 0.85,
        const Color(0xFFC6E3F4), 0.5);
    // La intro nace del blanco del arranque nativo, sin parpadeos.
    final blanco = 1 - intervalo(t, 0, 0.2);
    if (blanco > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Paleta.blanco.withValues(alpha: blanco));
    }
  }

  void _lucesBokeh(Canvas canvas, Size size, double t) {
    final entrada = intervalo(t, 0.2, 1.4);
    for (final l in _luces) {
      final centro = Offset(
        l.x * size.width + math.sin(t * 0.15 * (1 + l.vel) + l.fase) * size.width * 0.04,
        l.y * size.height + math.cos(t * 0.2 + l.fase) * size.height * 0.02 - t * l.vel * 6,
      );
      final opacidad = (0.16 + 0.16 * l.tam) * entrada * (0.75 + 0.25 * math.sin(t * 0.9 + l.fase));
      dibujarHalo(canvas, centro, size.width * (0.05 + l.tam * 0.1), Paleta.blanco, opacidad);
    }
  }

  void _ondas(Canvas canvas, Escena e, double t) {
    final w = e.size.width;
    void emitir(double inicio, Offset centro, double radioMax, double vida, double fuerza) {
      final u = t - inicio;
      if (u < 0 || u > vida) return;
      final p = u / vida;
      dibujarOnda(canvas, centro, radioMax * suaveSalida(p), fuerza * math.pow(1 - p, 1.5),
          grosor: 1.6 - p * 0.6);
    }

    final impacto = e.superficie(0, Guion.letras.first);
    for (var k = 0; k < 3; k++) {
      emitir(Guion.letras.first + k * 0.14, impacto, w * (0.8 - k * 0.12), 2.8, 1 - k * 0.2);
    }
    emitir(Guion.rebote, impacto, w * 0.28, 1.6, 0.6);

    final abajo = Offset(w * 0.72, e.size.height * 0.88);
    for (var k = 0; k < 3; k++) {
      emitir(Guion.gotaInferior + k * 0.15, abajo, w * (0.34 - k * 0.06), 2.2, 0.85 - k * 0.2);
    }

    // Anillos de agua que rodean el logo cuando termina de formarse.
    for (var k = 0; k < 3; k++) {
      emitir(Guion.impactoLogo + k * 0.16, e.centro, w * (0.62 - k * 0.1), 2.0, 0.9 - k * 0.2);
    }
  }

  void _gotas(Canvas canvas, Escena e, double t) {
    final radio = e.tamLetra * 0.22;

    // La primera gota cae, toca el agua y de ella brota la S.
    final impacto = e.superficie(0, Guion.letras.first);
    if (t < Guion.letras.first) {
      final p = t / Guion.letras.first;
      final y = mezcla(-e.size.height * 0.04, impacto.dy - radio, p * p);
      dibujarGota(canvas, Offset(impacto.dx, y), radio, 1, estiramiento: 0.6 + p);
    } else {
      final u = t - Guion.letras.first;
      dibujarHalo(canvas, impacto, e.tamLetra * (1.6 + 1.4 * suaveSalida(intervalo(u, 0, 0.5))), Paleta.blanco,
          0.95 * (1 - intervalo(u, 0, 0.6)));
      dibujarSalpicadura(canvas, impacto, u, 2.4, 21, cantidad: 18);
      dibujarSalpicadura(canvas, impacto, t - Guion.rebote, 0.8, 33, cantidad: 6);
    }

    // Gota que cae al agua en la parte baja.
    final abajo = Offset(e.size.width * 0.72, e.size.height * 0.88);
    const caida = 0.24;
    final u = t - Guion.gotaInferior;
    if (u >= -caida && u < 0) {
      final p = intervalo(u, -caida, 0);
      final y = mezcla(e.size.height * 0.5, abajo.dy - radio * 0.6, p * p);
      dibujarGota(canvas, Offset(abajo.dx, y), radio * 0.6, intervalo(p, 0, 0.3), estiramiento: 0.6 + p);
    }
    dibujarSalpicadura(canvas, abajo, u, 1.1, 44, cantidad: 9);
  }

  /// Dos ondas de energía que fluyen por la pantalla desde la "E" de Eficiencia.
  void _cintasDeEnergia(Canvas canvas, Size size, double t) {
    final aparicion = intervalo(t, 1.0, 2.3);
    final permanencia = 1 - intervalo(t, 8.1, 8.7);
    if (aparicion <= 0 || permanencia <= 0) return;

    for (var c = 0; c < 2; c++) {
      final base = size.height * (c == 0 ? 0.28 : 0.72);
      final amplitud = size.height * (c == 0 ? 0.06 : 0.05);
      final frecuencia = c == 0 ? 1.2 : 0.9;
      final sentido = c == 0 ? 0.9 : -0.7;
      final cinta = Path();
      for (var s = 0; s <= 48; s++) {
        final x = s / 48;
        final y = base +
            amplitud * math.sin(x * math.pi * 2 * frecuencia + t * sentido + c * 2) +
            amplitud * 0.4 * math.sin(x * math.pi * 5 + t * 1.3);
        final px = size.width * (-0.1 + 1.2 * x);
        s == 0 ? cinta.moveTo(px, y) : cinta.lineTo(px, y);
      }
      final metrica = cinta.computeMetrics().first;
      final dibujado = metrica.length * suaveSalida(aparicion);
      final visible = metrica.extractPath(0, dibujado);
      final opacidad = permanencia * (c == 0 ? 0.8 : 0.6);

      canvas.drawPath(
        visible,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = Paleta.agua.withValues(alpha: opacidad * 0.28),
      );
      canvas.drawPath(
        visible,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Paleta.blanco.withValues(alpha: opacidad),
      );

      // Chispa en la punta mientras se dibuja y, luego, una que la recorre.
      final punta = metrica.getTangentForOffset(dibujado)?.position;
      if (punta != null) dibujarDestello(canvas, punta, 6, opacidad * (1 - aparicion) * 1.6);
      final viajera = metrica.getTangentForOffset(metrica.length * ((t * 0.16 + c * 0.5) % 1))?.position;
      if (viajera != null) dibujarDestello(canvas, viajera, 5, opacidad * intervalo(t, 2.3, 3.0) * 1.2);
    }
  }

  /// Burbujas de agua que suben; una de cada cuatro es una partícula cálida de gas.
  void _burbujasYGas(Canvas canvas, Size size, double t) {
    final salida = 1 - intervalo(t, 9.3, 10) * 0.6;
    for (var i = 0; i < _burbujas.length; i++) {
      final b = _burbujas[i];
      final esGas = i % 4 == 0;
      final inicio = esGas ? Guion.letras[4] + i * 0.05 : 0.9 + i * 0.12;
      if (t < inicio) continue;
      final vida = t - inicio;
      final x = b.x * size.width + math.sin(t * 1.5 + b.fase) * 8;
      final y = size.height * (1.05 - ((vida * (0.03 + b.vel * 0.05) + b.y) % 1.1));
      final opacidad = 0.55 * intervalo(vida, 0, 0.6) * salida;
      if (esGas) {
        dibujarHalo(canvas, Offset(x, y), 4 + b.tam * 4, Paleta.gas, opacidad * 0.6);
      } else {
        dibujarBurbuja(canvas, Offset(x, y), 1.2 + b.tam * 3.2, opacidad);
      }
    }
  }

  /// Ramas que crecen en las esquinas inferiores (Responsabilidad y Análisis).
  void _ramas(Canvas canvas, Size size, double t) {
    _rama(canvas, Offset(size.width + 6, size.height * 0.985), size.width * 0.32, -math.pi * 0.78,
        suaveSalida(intervalo(t, Guion.letras[2], Guion.letras[2] + 1.2)), t, 5);
    _rama(canvas, Offset(-6, size.height * 0.995), size.width * 0.22, -math.pi * 0.26,
        suaveSalida(intervalo(t, Guion.letras[5], Guion.letras[5] + 1.0)), t, 4);
  }

  void _rama(Canvas canvas, Offset base, double largo, double direccion, double crecimiento, double t,
      int hojas) {
    if (crecimiento <= 0) return;
    final fin = base + Offset(math.cos(direccion), math.sin(direccion)) * largo * crecimiento;
    final control =
        base + Offset(math.cos(direccion + 0.5), math.sin(direccion + 0.5)) * largo * 0.5 * crecimiento;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(control.dx, control.dy, fin.dx, fin.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Paleta.hoja.withValues(alpha: 0.55),
    );
    for (var k = 0; k < hojas; k++) {
      final f = (k + 1) / (hojas + 1);
      final brote = intervalo(crecimiento, f * 0.7, f * 0.7 + 0.3);
      if (brote <= 0) continue;
      final punto = puntoBezier(base, control, fin, f);
      final angulo = direccion + (k.isEven ? 0.9 : -0.9) + math.sin(t * 1.4 + k) * 0.06;
      final largoHoja = largo * 0.28 * (1 - f * 0.4) * rebote(brote);
      dibujarHoja(canvas, punto + Offset(math.cos(angulo), math.sin(angulo)) * largoHoja * 0.5, largoHoja,
          angulo, 0.9);
    }
  }

  /// Hojas que flotan con el viento; aparecen poco a poco desde la "R".
  void _hojasFlotando(Canvas canvas, Size size, double t) {
    for (var i = 0; i < _hojas.length; i++) {
      final h = _hojas[i];
      final inicio = Guion.letras[2] + i * 0.3;
      if (t < inicio) continue;
      final vida = t - inicio;
      final x = (h.x * size.width +
                  vida * size.width * (0.03 + 0.03 * h.vel) +
                  math.sin(vida * 1.6 + h.fase) * size.width * 0.03) %
              (size.width * 1.1) -
          size.width * 0.05;
      final y = (h.y * size.height * 0.9 + vida * size.height * (0.03 + 0.04 * h.vel)) % (size.height * 1.1) -
          size.height * 0.05;
      final angulo = h.fase + vida * (0.6 + h.vel) * (i.isEven ? 1 : -1) + math.sin(vida * 2 + h.fase) * 0.3;
      dibujarHoja(canvas, Offset(x, y), size.width * (0.022 + 0.02 * h.tam), angulo,
          0.85 * intervalo(vida, 0, 0.6));
    }
  }

  void _titileos(Canvas canvas, Size size, double t) {
    final presencia = intervalo(t, 1.0, 3.0);
    if (presencia <= 0) return;
    for (final c in _chispas) {
      final brillo = math.pow(math.max(0, math.sin(t * (1.2 + c.vel * 1.5) * math.pi + c.fase)), 3);
      dibujarDestello(canvas, Offset(c.x * size.width, c.y * size.height), 2.5 + c.tam * 3.5,
          0.7 * brillo * presencia);
    }
  }

  @override
  bool shouldRepaint(covariant FondoPainter oldDelegate) => oldDelegate.tiempo != tiempo;
}
