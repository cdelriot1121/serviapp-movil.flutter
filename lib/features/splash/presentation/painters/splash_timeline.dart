import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';

/// Guion de la intro, en segundos. Cada marca coincide con un golpe del audio
/// `assets/audio/splash_intro.mp3` (medidos sobre su forma de onda), así que
/// cada gota, letra y destello suena exactamente cuando aparece en pantalla.
abstract final class Guion {
  static const double duracion = 10.0;

  /// Campanada de cada letra: la letra cae como gota y florece en ese instante.
  /// El ritmo se acelera levemente hacia la última P.
  static const List<double> letras = [0.24, 1.18, 2.13, 3.14, 4.11, 5.14, 6.06, 6.95];

  /// "Plop" de rebote de la primera gota.
  static const double rebote = 0.74;

  /// Gota que cae sobre el agua en la parte baja de la pantalla.
  static const double gotaInferior = 6.40;

  static const double palabrasFuera = 7.85;
  static const double fusionInicio = 8.02;
  static const double fusionFin = 8.86;

  /// Golpe grave del audio: el logo queda formado y estalla el anillo de agua.
  static const double impactoLogo = 8.98;

  /// Brillo que recorre el logo con el acorde final.
  static const double destelloLogo = 9.45;
}

const List<String> letrasIntro = ['S', 'E', 'R', 'V', 'I', 'A', 'P', 'P'];

const List<String> palabrasIntro = [
  'Servicios',
  'Eficiencia',
  'Responsabilidad',
  'Visualización',
  'Innovación',
  'Análisis',
  'Predicción',
  'Prevención',
];

/// Cada letra de la columna se transforma en el glifo de la misma posición.
const String textoLogo = 'ServiApp';

abstract final class Paleta {
  static const Color logo = AppColors.logo;
  static const Color palabra = Color(0xFF4A6580);
  static const Color agua = Color(0xFF7CC8F0);
  static const Color aguaOscura = Color(0xFF3E9FD6);
  static const Color espuma = Color(0xFFF2FBFF);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color hojaClara = Color(0xFF9AD47F);
  static const Color hoja = AppColors.green;
  static const Color gas = AppColors.orange;
  static const Color energia = Color(0xFFF6C344);
  static const List<Color> cielo = [
    Color(0xFFFCF8EE),
    Color(0xFFEDF6FA),
    Color(0xFFD6EBF7),
    Color(0xFFBFE0F3),
  ];
}

TextStyle estiloLetra(double tam, {Color color = Paleta.logo, List<Shadow>? sombras}) => TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w800,
      fontSize: tam,
      height: 1,
      color: color,
      shadows: sombras,
    );

TextStyle estiloPalabra(double tam) => TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w500,
      fontSize: tam,
      height: 1,
      letterSpacing: tam * 0.02,
      color: Paleta.palabra,
    );

TextPainter textoMedido(String texto, TextStyle estilo) =>
    TextPainter(text: TextSpan(text: texto, style: estilo), textDirection: TextDirection.ltr)..layout();

double _anchoTexto(String texto, TextStyle estilo) {
  final tp = textoMedido(texto, estilo);
  final ancho = tp.width;
  tp.dispose();
  return ancho;
}

// ---------------------------------------------------------------------------
// Curvas de tiempo
// ---------------------------------------------------------------------------

/// Progreso 0..1 de [t] dentro del tramo [a, b].
double intervalo(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

double suaveSalida(double x) => 1 - math.pow(1 - x, 3).toDouble();

double suaveAmbos(double x) => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

/// Llega pasándose un poco y vuelve: da la sensación de "florecer".
double rebote(double x) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2);
}

double mezcla(double a, double b, double t) => a + (b - a) * t;

Offset puntoBezier(Offset a, Offset control, Offset b, double t) =>
    a * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + b * (t * t);

// ---------------------------------------------------------------------------
// Distribución de la escena según el tamaño de pantalla
// ---------------------------------------------------------------------------

/// Medidas compartidas por los painters del splash. Todo escala con el ancho
/// para verse igual en cualquier teléfono.
class Escena {
  factory Escena.de(Size size) {
    final previa = _ultima;
    if (previa != null && previa.size == size) return previa;
    return _ultima = Escena._(size);
  }

  static Escena? _ultima;

  Escena._(this.size) {
    final w = size.width;
    final h = size.height;

    // Ancho del bloque "letra — palabra  adorno" expresado en tamaños de letra.
    final palabraMasLarga =
        palabrasIntro.map((p) => _anchoTexto('— $p', estiloPalabra(40)) / 100).reduce(math.max);
    final anchoBloque = _cajaLetra + _separacion + palabraMasLarga + _aireAdorno + _anchoAdorno;

    final letra = math.min(math.min(w * 0.12, h * 0.066).clamp(26.0, 56.0), w * 0.9 / anchoBloque);
    final izquierda = (w - anchoBloque * letra) / 2;

    tamLetra = letra;
    tamPalabra = letra * 0.40;
    altoFila = letra * 1.42;
    columnaX = izquierda + letra * _cajaLetra / 2;
    palabraX = izquierda + letra * (_cajaLetra + _separacion);
    adornoX = palabraX + letra * (palabraMasLarga + _aireAdorno);
    anchoAdorno = letra * _anchoAdorno;
    centroY = h * 0.47;
    centro = Offset(w / 2, centroY);

    final logoA100 = _anchoTexto(textoLogo, estiloLetra(100));
    tamLogo = math.min(100 * w * 0.70 / logoA100, letra * 1.75);
  }

  static const double _cajaLetra = 0.9;
  static const double _separacion = 0.22;
  static const double _aireAdorno = 0.3;
  static const double _anchoAdorno = 1.25;

  final Size size;
  late final double tamLetra;
  late final double tamPalabra;
  late final double altoFila;
  late final double columnaX;
  late final double palabraX;
  late final double adornoX;
  late final double anchoAdorno;
  late final double centroY;
  late final Offset centro;
  late final double tamLogo;

  /// Filas visibles (fraccionario): la columna se recentra suavemente justo
  /// antes de que llegue cada letra, sin saltos.
  static double filasVisibles(double t) {
    var n = 1.0;
    for (var i = 1; i < Guion.letras.length; i++) {
      n += suaveAmbos(intervalo(t, Guion.letras[i] - 0.42, Guion.letras[i] + 0.08));
    }
    return n;
  }

  /// Centro de la letra [i] en la columna en el instante [t].
  Offset fila(int i, double t) =>
      Offset(columnaX, centroY + (i + 0.5 - filasVisibles(t) / 2) * altoFila);

  /// Punto del "agua" bajo la letra donde caen las gotas.
  Offset superficie(int i, double t) => fila(i, t) + Offset(0, tamLetra * 0.42);
}
