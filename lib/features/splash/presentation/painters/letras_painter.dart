import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'ornamentos.dart';
import 'splash_timeline.dart';
import 'trazos.dart';

/// Letras S-E-R-V-I-A-P-P con sus palabras, la fusión en el logotipo y el
/// destello final. Cada letra se dibuja una sola vez por cuadro y en una
/// posición calculada a partir del tiempo, así nunca se duplica ni se desordena.
class LetrasPainter extends CustomPainter {
  LetrasPainter(this.tiempo) : super(repaint: tiempo);

  final ValueListenable<double> tiempo;

  static const int _total = 8;

  Escena? _escena;
  List<TextPainter> _mayusculas = const [];
  List<TextPainter> _mayusculasBlancas = const [];
  List<TextPainter> _palabras = const [];
  List<TextPainter> _logo = const [];
  List<TextPainter> _logoBlanco = const [];
  List<Offset> _posicionesLogo = const [];
  Rect _rectLogo = Rect.zero;

  void _preparar(Escena e) {
    if (identical(_escena, e)) return;
    liberar();
    _escena = e;

    final sombraLetra = [Shadow(color: Paleta.logo.withValues(alpha: 0.28), blurRadius: e.tamLetra * 0.3)];
    final sombraLogo = [Shadow(color: Paleta.logo.withValues(alpha: 0.25), blurRadius: e.tamLogo * 0.3)];
    _mayusculas = [for (final l in letrasIntro) textoMedido(l, estiloLetra(e.tamLetra, sombras: sombraLetra))];
    _mayusculasBlancas = [
      for (final l in letrasIntro) textoMedido(l, estiloLetra(e.tamLetra, color: Paleta.blanco)),
    ];
    _palabras = [for (final p in palabrasIntro) textoMedido('— $p', estiloPalabra(e.tamPalabra))];

    // El logo se mide completo (con su interletrado real) y luego cada glifo
    // se coloca en su posición exacta: al terminar la fusión se ve idéntico
    // al logotipo de ServiApp.
    final completo = textoMedido(textoLogo, estiloLetra(e.tamLogo));
    final origen = Offset((e.size.width - completo.width) / 2, e.centroY - completo.height / 2);
    _rectLogo = origen & completo.size;
    final glifos = textoLogo.split('');
    _logo = [for (final g in glifos) textoMedido(g, estiloLetra(e.tamLogo, sombras: sombraLogo))];
    _logoBlanco = [for (final g in glifos) textoMedido(g, estiloLetra(e.tamLogo, color: Paleta.blanco))];
    _posicionesLogo = [
      for (var k = 0; k < glifos.length; k++)
        origen +
            Offset(
              completo.getOffsetForCaret(TextPosition(offset: k), Rect.zero).dx + _logo[k].width / 2,
              _logo[k].height / 2,
            ),
    ];
    completo.dispose();
  }

  /// Libera los textos medidos (al cambiar de tamaño o al cerrar el splash).
  void liberar() {
    for (final tp in [..._mayusculas, ..._mayusculasBlancas, ..._palabras, ..._logo, ..._logoBlanco]) {
      tp.dispose();
    }
    _mayusculas = _mayusculasBlancas = _palabras = _logo = _logoBlanco = const [];
    _escena = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final e = Escena.de(size);
    _preparar(e);
    final t = tiempo.value;

    if (t >= 8.25) _climaxDetras(canvas, e, t);
    for (var i = 0; i < _total; i++) {
      _llegada(canvas, e, i, t);
      _palabra(canvas, e, i, t);
      _letra(canvas, e, i, t);
    }
    if (t >= Guion.impactoLogo) _climaxDelante(canvas, e, t);
  }

  // -------------------------------------------------------------------------
  // Letras
  // -------------------------------------------------------------------------

  /// Gota que cae, onda, salpicadura y halo del aterrizaje de cada letra.
  void _llegada(Canvas canvas, Escena e, int i, double t) {
    if (t >= Guion.fusionInicio) return;
    final u = t - Guion.letras[i];
    final centro = e.fila(i, t);
    final agua = e.superficie(i, t);

    // La primera gota y su gran salpicadura las pinta el fondo.
    if (i > 0) {
      if (u >= -0.22 && u < 0) {
        final p = intervalo(u, -0.22, 0);
        final y = agua.dy - e.altoFila * 1.4 * (1 - p * p);
        dibujarGota(canvas, Offset(agua.dx, y), e.tamLetra * 0.11, intervalo(p, 0, 0.25), estiramiento: 0.5 + p);
      }
      if (u >= 0 && u < 0.8) {
        dibujarOnda(canvas, agua, e.tamLetra * (0.35 + 1.15 * suaveSalida(u / 0.8)), (1 - u / 0.8) * 0.85,
            aplanado: 0.28);
      }
      dibujarSalpicadura(canvas, agua, u, 0.75, 50 + i, cantidad: 7);
    }
    if (u >= 0 && u < 1.5) {
      final apertura = suaveSalida(intervalo(u, 0, 0.5));
      dibujarHalo(canvas, centro, e.tamLetra * (0.9 + 0.6 * apertura), Paleta.espuma, 0.85 * math.exp(-u * 3.2));
      dibujarHalo(canvas, centro, e.tamLetra * (1.2 + 0.8 * apertura), Paleta.agua, 0.3 * math.exp(-u * 3.2));
    }
  }

  void _letra(Canvas canvas, Escena e, int i, double t) {
    final u = t - Guion.letras[i];
    if (u < 0) return;

    var enColumna = e.fila(i, t);
    // La S brota del agua; las demás florecen donde cayó su gota.
    if (i == 0) enColumna += Offset(0, (1 - suaveSalida(intervalo(u, 0, 0.32))) * e.altoFila * 0.35);
    final escala = u < 0.38 ? 0.55 + 0.45 * rebote(u / 0.38) : 1.0;
    final opacidad = intervalo(u, 0, 0.12);
    final flash = math.exp(-u * 5) * 0.75;

    final viaje = suaveAmbos(
        intervalo(t, Guion.fusionInicio + i * 0.012, Guion.fusionFin - (_total - 1 - i) * 0.012));
    if (viaje <= 0) {
      _glifo(canvas, _mayusculas[i], enColumna, escala, opacidad);
      _glifo(canvas, _mayusculasBlancas[i], enColumna, escala, opacidad * flash);
      return;
    }

    // Fusión: primero se abre en horizontal y luego cae a su sitio en el logo.
    // Como cada letra tiene su propia fila y su propia columna de destino,
    // las trayectorias nunca se cruzan.
    final destino = _centroLogo(i, t);
    final control = Offset(mezcla(enColumna.dx, destino.dx, 0.9), mezcla(enColumna.dy, destino.dy, 0.1));
    final posicion = puntoBezier(enColumna, control, destino, viaje);
    final relacion = e.tamLogo / e.tamLetra;
    final cambio = intervalo(viaje, 0.38, 0.72);

    if (viaje < 1) {
      for (var j = 1; j <= 5; j++) {
        final atras = viaje - j * 0.035;
        if (atras <= 0) break;
        dibujarHalo(canvas, puntoBezier(enColumna, control, destino, atras), e.tamLetra * (0.34 - j * 0.04),
            Paleta.espuma, (1 - viaje) * 0.55 * (1 - j / 6));
      }
    }
    final escalaLogo = mezcla(1 / relacion, 1, viaje) * _pulso(t);
    _glifo(canvas, _mayusculas[i], posicion, mezcla(1, relacion, viaje), 1 - cambio);
    _glifo(canvas, _logo[i], posicion, escalaLogo, cambio);
    _glifo(canvas, _logoBlanco[i], posicion, escalaLogo, math.sin(math.pi * cambio) * 0.8);
  }

  void _palabra(Canvas canvas, Escena e, int i, double t) {
    final u = t - Guion.letras[i];
    final entrada = suaveSalida(intervalo(u, 0.06, 0.52));
    if (entrada <= 0) return;
    final salida =
        suaveAmbos(intervalo(t, Guion.palabrasFuera + i * 0.03, Guion.palabrasFuera + 0.32 + i * 0.03));
    if (salida >= 1) return;

    final fila = e.fila(i, t);
    final desplazamiento = -(1 - entrada) * e.tamLetra * 0.25 + salida * e.tamLetra * 0.35;
    final tp = _palabras[i];
    final origen = Offset(e.palabraX + desplazamiento, fila.dy - e.tamLetra * 0.06 - tp.height / 2);

    if (entrada >= 1 && salida <= 0) {
      tp.paint(canvas, origen);
    } else {
      // Aparece barriendo de izquierda a derecha con un borde suave.
      final zona = (origen & tp.size).inflate(4);
      final borde = entrada * 1.15;
      canvas.saveLayer(zona, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - salida));
      tp.paint(canvas, origen);
      if (entrada < 1) {
        canvas.drawRect(
          zona,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = LinearGradient(
              colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
              stops: [0, math.max(0, borde - 0.15), math.min(1, borde)],
            ).createShader(zona),
        );
      }
      canvas.restore();
    }

    final zonaAdorno = Rect.fromLTWH(
      e.adornoX + salida * e.tamLetra * 0.35,
      fila.dy - e.tamLetra * 0.06 - e.altoFila * 0.3,
      e.anchoAdorno,
      e.altoFila * 0.6,
    );
    dibujarAdorno(canvas, i, zonaAdorno, intervalo(u, 0.18, 0.95), 1 - salida, t);
  }

  void _glifo(Canvas canvas, TextPainter tp, Offset centro, double escala, double opacidad) {
    if (opacidad <= 0.01 || escala <= 0.01) return;
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.scale(escala);
    final origen = Offset(-tp.width / 2, -tp.height / 2);
    if (opacidad < 0.99) {
      canvas.saveLayer((origen & tp.size).inflate(tp.height * 0.5), Paint()..color = Color.fromRGBO(0, 0, 0, opacidad));
      tp.paint(canvas, origen);
      canvas.restore();
    } else {
      tp.paint(canvas, origen);
    }
    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // Logo final
  // -------------------------------------------------------------------------

  /// Latido del logo con el golpe grave del audio.
  double _pulso(double t) => 1 + 0.07 * math.sin(math.pi * intervalo(t, Guion.impactoLogo - 0.02, 9.42));

  Offset _centroLogo(int i, double t) => _escena!.centro + (_posicionesLogo[i] - _escena!.centro) * _pulso(t);

  /// Remolino de gotas que se cierra sobre el logo, estallido del anillo de
  /// agua, halo de luz y hojas que salen despedidas.
  void _climaxDetras(Canvas canvas, Escena e, double t) {
    final w = e.size.width;
    final centro = e.centro;
    final remolino = intervalo(t, 8.25, Guion.impactoLogo);
    final estallido = intervalo(t, Guion.impactoLogo, Guion.impactoLogo + 0.9);
    final despues = t >= Guion.impactoLogo;

    // Halo: crece con el remolino, destella con el golpe y queda suave.
    final destello = despues ? math.exp(-(t - Guion.impactoLogo) * 3.5) : remolino * remolino * 0.4;
    final calma = intervalo(t, Guion.impactoLogo, 9.5);
    dibujarHalo(canvas, centro, w * (0.45 + 0.25 * estallido), Paleta.blanco,
        0.85 * destello + 0.32 * calma + 0.04 * math.sin(t * 3) * calma);
    dibujarHalo(canvas, centro, w * (0.6 + 0.2 * estallido), Paleta.agua, 0.22 * math.max(destello, calma));

    // Gotas en órbita.
    for (var j = 0; j < 22; j++) {
      final base = j / 22 * math.pi * 2;
      final tam = e.tamLetra * 0.075 * (1 + (j % 3) * 0.3);
      double radio, angulo, opacidad;
      if (!despues) {
        if (remolino <= 0) break;
        radio = w * (0.62 - 0.42 * remolino * remolino);
        angulo = base + remolino * 2.6;
        opacidad = 0.9 * intervalo(remolino, 0, 0.3);
      } else {
        radio = w * (0.2 + 0.42 * suaveSalida(estallido));
        angulo = base + 2.6 + estallido * 0.4;
        opacidad = 0.9 * (1 - estallido);
      }
      final punto = centro + Offset(math.cos(angulo) * radio, math.sin(angulo) * radio * 0.62);
      dibujarBurbuja(canvas, punto, tam * (despues ? 1 - estallido * 0.5 : 1), opacidad);
    }

    if (!despues) return;

    // Corona de agua irregular que se expande.
    if (estallido < 1) {
      final radio = w * (0.2 + 0.26 * suaveSalida(estallido));
      final corona = Path();
      for (var s = 0; s <= 72; s++) {
        final a = s / 72 * math.pi * 2;
        final r = radio * (1 + 0.025 * math.sin(a * 9 + t * 6) + 0.015 * math.sin(a * 17));
        final punto = centro + Offset(math.cos(a) * r, math.sin(a) * r * 0.62);
        s == 0 ? corona.moveTo(punto.dx, punto.dy) : corona.lineTo(punto.dx, punto.dy);
      }
      canvas.drawPath(
        corona,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * (1 - estallido)
          ..color = Paleta.agua.withValues(alpha: 0.25 * (1 - estallido)),
      );
      canvas.drawPath(
        corona,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * (1 - estallido) + 0.4
          ..color = Paleta.blanco.withValues(alpha: 0.85 * (1 - estallido)),
      );
    }

    // Hojas despedidas.
    final vuelo = suaveSalida(intervalo(t, Guion.impactoLogo, 10));
    final opacidadHojas = intervalo(t, Guion.impactoLogo, Guion.impactoLogo + 0.08) * (1 - intervalo(t, 9.55, 10));
    for (var j = 0; j < 10; j++) {
      final a = j / 10 * math.pi * 2 + 0.3;
      final distancia = w * (0.1 + 0.48 * vuelo) * (0.85 + 0.3 * ((j * 7) % 5) / 5);
      final punto = centro + Offset(math.cos(a) * distancia, math.sin(a) * distancia * 0.8);
      dibujarHoja(canvas, punto, w * 0.035, a + vuelo * 3 * (j.isEven ? 1 : -1), opacidadHojas * 0.9);
    }
  }

  /// Destello blanco del golpe, línea de luz y brillo que recorre el logo.
  void _climaxDelante(Canvas canvas, Escena e, double t) {
    final w = e.size.width;
    final pulso = _pulso(t);

    final blanco = 0.6 * (1 - intervalo(t, Guion.impactoLogo, 9.22));
    for (var i = 0; i < _total; i++) {
      _glifo(canvas, _logoBlanco[i], _centroLogo(i, t), pulso, blanco);
    }

    // Línea de luz horizontal.
    final linea = 1 - intervalo(t, 9.0, 9.6);
    if (linea > 0) {
      final largo = w * 1.3 * suaveSalida(intervalo(t, Guion.impactoLogo, 9.3));
      for (final (alto, fuerza) in [(10.0, 0.22), (2.2, 0.85)]) {
        final rect = Rect.fromCenter(center: e.centro, width: largo, height: alto);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(colors: [
              Paleta.blanco.withValues(alpha: 0),
              Paleta.blanco.withValues(alpha: fuerza * linea),
              Paleta.blanco.withValues(alpha: 0),
            ]).createShader(rect),
        );
      }
    }

    // Brillo que recorre las letras del logo.
    final barrido = intervalo(t, Guion.destelloLogo, Guion.destelloLogo + 0.55);
    if (barrido > 0 && barrido < 1) {
      final zona = Rect.fromCenter(
        center: e.centro,
        width: _rectLogo.width * pulso,
        height: _rectLogo.height * pulso,
      ).inflate(6);
      final ancho = zona.width * 0.36;
      final banda = Rect.fromCenter(
        center: Offset(zona.left + zona.width * mezcla(-0.2, 1.2, suaveAmbos(barrido)), zona.center.dy),
        width: ancho,
        height: zona.height,
      );
      canvas.saveLayer(zona, Paint());
      for (var i = 0; i < _total; i++) {
        _glifo(canvas, _logoBlanco[i], _centroLogo(i, t), pulso, 1);
      }
      // Fuera de la banda el gradiente queda transparente: solo brilla la franja.
      canvas.drawRect(
        zona,
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = LinearGradient(
            begin: const Alignment(-1, -0.5),
            end: const Alignment(1, 0.5),
            colors: [
              Paleta.blanco.withValues(alpha: 0),
              Paleta.blanco.withValues(alpha: 0.9),
              Paleta.blanco.withValues(alpha: 0),
            ],
          ).createShader(banda),
      );
      canvas.restore();
    }

    // Destellos que titilan alrededor del logo.
    final presencia = intervalo(t, 9.05, 9.4);
    for (var j = 0; j < 7; j++) {
      final punto = Offset(
        _rectLogo.left + _rectLogo.width * ((j * 0.37 + 0.08) % 1),
        _rectLogo.center.dy + _rectLogo.height * (j.isEven ? -0.75 : 0.8) * (0.8 + (j % 3) * 0.15),
      );
      final brillo = math.pow(math.max(0, math.sin(t * 5 + j * 1.7)), 2);
      dibujarDestello(canvas, punto, 3 + (j % 3) * 1.6, 0.85 * brillo * presencia);
    }
  }

  @override
  bool shouldRepaint(covariant LetrasPainter oldDelegate) => oldDelegate.tiempo != tiempo;
}
