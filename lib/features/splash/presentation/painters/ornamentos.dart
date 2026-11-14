import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'splash_timeline.dart';
import 'trazos.dart';

/// Pequeño gráfico que acompaña a cada palabra: servicios, energía, naturaleza,
/// gráficas de consumo, tendencias e indicadores. [progreso] va de 0 a 1.
void dibujarAdorno(Canvas canvas, int indice, Rect zona, double progreso, double opacidad, double t) {
  if (progreso <= 0 || opacidad <= 0.01) return;
  final op = opacidad * 0.9;
  switch (indice) {
    case 0:
      _servicios(canvas, zona, progreso, op);
    case 1:
      _ondaEnergia(canvas, zona, progreso, op, t);
    case 2:
      _brote(canvas, zona, progreso, op, t);
    case 3:
      _barras(canvas, zona, progreso, op);
    case 4:
      _idea(canvas, zona, progreso, op, t);
    case 5:
      _tendencia(canvas, zona, progreso, op);
    case 6:
      _prediccion(canvas, zona, progreso, op);
    case 7:
      _indicador(canvas, zona, progreso, op);
  }
}

Paint _trazo(Color color, double grosor) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = grosor
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

void _icono(Canvas canvas, IconData icono, Offset centro, double tam, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icono.codePoint),
      style: TextStyle(fontFamily: icono.fontFamily, package: icono.fontPackage, fontSize: tam, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

/// Agua, energía y gas: los tres servicios que analiza ServiApp.
void _servicios(Canvas canvas, Rect zona, double p, double op) {
  const iconos = [Icons.water_drop_rounded, Icons.bolt_rounded, Icons.local_fire_department_rounded];
  const colores = [Paleta.logo, Paleta.energia, Paleta.gas];
  for (var k = 0; k < 3; k++) {
    final aparicion = intervalo(p, k * 0.2, k * 0.2 + 0.5);
    if (aparicion <= 0) continue;
    final tam = zona.height * 0.62 * rebote(aparicion);
    final centro = Offset(zona.left + zona.width * (0.17 + 0.33 * k), zona.center.dy);
    _icono(canvas, iconos[k], centro, tam, colores[k].withValues(alpha: op * intervalo(aparicion, 0, 0.4)));
  }
}

void _ondaEnergia(Canvas canvas, Rect zona, double p, double op, double t) {
  final onda = Path();
  for (var s = 0; s <= 32; s++) {
    final x = s / 32;
    final envolvente = math.sin(x * math.pi);
    final y = zona.center.dy + zona.height * 0.38 * envolvente * math.sin(x * math.pi * 3 - t * 4);
    s == 0 ? onda.moveTo(zona.left + zona.width * x, y) : onda.lineTo(zona.left + zona.width * x, y);
  }
  final metrica = onda.computeMetrics().first;
  final visible = metrica.extractPath(0, metrica.length * suaveSalida(p));
  canvas.drawPath(
    visible,
    _trazo(Paleta.hoja, 2.2)
      ..shader = LinearGradient(colors: [
        Paleta.hoja.withValues(alpha: op),
        Paleta.logo.withValues(alpha: op),
      ]).createShader(zona),
  );
  final pulso = metrica.getTangentForOffset(metrica.length * ((t * 0.5) % 1))?.position;
  if (pulso != null && p >= 1) dibujarHalo(canvas, pulso, zona.height * 0.25, Paleta.logo, op * 0.7);
}

void _brote(Canvas canvas, Rect zona, double p, double op, double t) {
  final base = Offset(zona.left + zona.width * 0.35, zona.bottom);
  final tallo = suaveSalida(intervalo(p, 0, 0.5));
  final punta = base - Offset(0, zona.height * 0.85 * tallo);
  canvas.drawLine(base, punta, _trazo(Paleta.hoja.withValues(alpha: op), 2));
  final vaiven = math.sin(t * 2) * 0.08;
  final hojaA = rebote(intervalo(p, 0.35, 0.8));
  final hojaB = rebote(intervalo(p, 0.5, 1));
  final medio = base - Offset(0, zona.height * 0.5 * tallo);
  dibujarHoja(canvas, medio + Offset(zona.height * 0.28 * hojaA, -zona.height * 0.08), zona.height * 0.55 * hojaA,
      -0.5 + vaiven, op);
  dibujarHoja(canvas, punta + Offset(-zona.height * 0.25 * hojaB, 0), zona.height * 0.5 * hojaB,
      math.pi + 0.5 + vaiven, op);
  // Gota de rocío que cae junto al brote.
  final rocio = intervalo(p, 0.7, 1);
  if (rocio > 0) dibujarBurbuja(canvas, Offset(zona.left + zona.width * 0.72, zona.center.dy), 2.6 * rocio, op);
}

/// Gráfica de consumo con barras que crecen.
void _barras(Canvas canvas, Rect zona, double p, double op) {
  const alturas = [0.35, 0.55, 0.45, 0.75, 0.95];
  final ancho = zona.width / 9;
  canvas.drawLine(zona.bottomLeft, zona.bottomRight, _trazo(Paleta.palabra.withValues(alpha: op * 0.25), 1));
  for (var k = 0; k < alturas.length; k++) {
    final crecimiento = suaveSalida(intervalo(p, k * 0.1, k * 0.1 + 0.5));
    if (crecimiento <= 0) continue;
    final alto = zona.height * alturas[k] * crecimiento;
    final barra = Rect.fromLTWH(zona.left + ancho * (0.5 + k * 1.7), zona.bottom - alto, ancho, alto);
    canvas.drawRRect(
      RRect.fromRectAndCorners(barra, topLeft: Radius.circular(ancho / 2), topRight: Radius.circular(ancho / 2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Paleta.logo.withValues(alpha: op), Paleta.agua.withValues(alpha: op * 0.45)],
        ).createShader(barra),
    );
  }
}

/// Innovación: una idea que se enciende y suelta chispas.
void _idea(Canvas canvas, Rect zona, double p, double op, double t) {
  final centro = Offset(zona.left + zona.width * 0.3, zona.center.dy);
  final encendido = rebote(intervalo(p, 0, 0.5));
  dibujarHalo(canvas, centro, zona.height * (0.6 + 0.08 * math.sin(t * 5)), Paleta.energia,
      op * 0.45 * intervalo(p, 0.3, 0.8));
  _icono(canvas, Icons.lightbulb_outline_rounded, centro, zona.height * 0.7 * encendido,
      Paleta.logo.withValues(alpha: op * intervalo(p, 0, 0.3)));
  for (var k = 0; k < 3; k++) {
    final vida = (t * 0.8 + k / 3) % 1;
    final chispa = Offset(zona.left + zona.width * (0.55 + 0.15 * k), zona.bottom - zona.height * vida);
    dibujarDestello(canvas, chispa, 3.2, op * intervalo(p, 0.5, 1) * math.sin(vida * math.pi));
  }
}

List<Offset> _puntos(Rect zona, List<double> alturas) => [
      for (var k = 0; k < alturas.length; k++)
        Offset(zona.left + zona.width * k / (alturas.length - 1), zona.bottom - zona.height * alturas[k]),
    ];

/// Análisis: línea de tendencia que se traza con sus puntos.
void _tendencia(Canvas canvas, Rect zona, double p, double op) {
  final puntos = _puntos(zona, const [0.2, 0.45, 0.35, 0.7, 0.9]);
  final linea = Path()..addPolygon(puntos, false);
  final metrica = linea.computeMetrics().first;
  final avance = suaveSalida(p);
  final relleno = Path.from(linea)
    ..lineTo(zona.right, zona.bottom)
    ..lineTo(zona.left, zona.bottom)
    ..close();
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(zona.left, zona.top - 4, zona.left + zona.width * avance, zona.bottom));
  canvas.drawPath(
    relleno,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Paleta.logo.withValues(alpha: op * 0.25), Paleta.logo.withValues(alpha: 0)],
      ).createShader(zona),
  );
  canvas.restore();
  canvas.drawPath(metrica.extractPath(0, metrica.length * avance), _trazo(Paleta.logo.withValues(alpha: op), 2));
  for (var k = 0; k < puntos.length; k++) {
    final llegada = intervalo(avance, k / (puntos.length - 1) - 0.05, k / (puntos.length - 1) + 0.1);
    if (llegada <= 0) continue;
    canvas.drawCircle(puntos[k], 2.6 * rebote(llegada), Paint()..color = Paleta.blanco.withValues(alpha: op));
    canvas.drawCircle(puntos[k], 2.6 * rebote(llegada), _trazo(Paleta.logo.withValues(alpha: op), 1.4));
  }
}

/// Predicción: datos reales y su proyección punteada hacia adelante.
void _prediccion(Canvas canvas, Rect zona, double p, double op) {
  final puntos = _puntos(zona, const [0.25, 0.4, 0.35, 0.55, 0.92]);
  final real = Path()..addPolygon(puntos.sublist(0, 4), false);
  final avanceReal = suaveSalida(intervalo(p, 0, 0.55));
  final metricaReal = real.computeMetrics().first;
  canvas.drawPath(
      metricaReal.extractPath(0, metricaReal.length * avanceReal), _trazo(Paleta.logo.withValues(alpha: op), 2));

  final proyeccion = suaveSalida(intervalo(p, 0.5, 1));
  if (proyeccion <= 0) return;
  final desde = puntos[3];
  final hasta = Offset.lerp(desde, puntos[4], proyeccion)!;
  final distancia = (hasta - desde).distance;
  final direccion = (puntos[4] - desde) / (puntos[4] - desde).distance;
  final guion = _trazo(Paleta.hoja.withValues(alpha: op), 2);
  for (var d = 0.0; d < distancia; d += 6) {
    canvas.drawLine(desde + direccion * d, desde + direccion * math.min(d + 3, distancia), guion);
  }
  if (proyeccion >= 0.95) {
    final normal = Offset(-direccion.dy, direccion.dx);
    canvas.drawPath(
      Path()
        ..moveTo(hasta.dx, hasta.dy)
        ..lineTo((hasta - direccion * 6 + normal * 4).dx, (hasta - direccion * 6 + normal * 4).dy)
        ..lineTo((hasta - direccion * 6 - normal * 4).dx, (hasta - direccion * 6 - normal * 4).dy)
        ..close(),
      Paint()..color = Paleta.hoja.withValues(alpha: op),
    );
  }
}

/// Prevención: indicador que se llena hasta la zona segura.
void _indicador(Canvas canvas, Rect zona, double p, double op) {
  final radio = math.min(zona.height * 0.62, zona.width * 0.4);
  final centro = Offset(zona.left + zona.width * 0.4, zona.bottom - 1);
  final arco = Rect.fromCircle(center: centro, radius: radio);
  canvas.drawArc(arco, math.pi, math.pi, false, _trazo(Paleta.palabra.withValues(alpha: op * 0.2), 3.2));
  final llenado = suaveSalida(p) * 0.75;
  canvas.drawArc(
    arco,
    math.pi,
    math.pi * llenado,
    false,
    _trazo(Paleta.hoja, 3.2)
      ..shader = SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: [Paleta.logo.withValues(alpha: op), Paleta.hoja.withValues(alpha: op)],
      ).createShader(arco),
  );
  final angulo = math.pi + math.pi * llenado;
  canvas.drawLine(
    centro,
    centro + Offset(math.cos(angulo), math.sin(angulo)) * radio * 0.75,
    _trazo(Paleta.palabra.withValues(alpha: op * 0.8), 1.6),
  );
  canvas.drawCircle(centro, 2.4, Paint()..color = Paleta.palabra.withValues(alpha: op));
}
