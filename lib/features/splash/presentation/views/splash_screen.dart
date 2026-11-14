import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../auth/presentation/views/login_screen.dart';
import '../painters/fondo_painter.dart';
import '../painters/letras_painter.dart';
import '../painters/splash_timeline.dart';

/// Intro de ServiApp: las letras S-E-R-V-I-A-P-P caen como gotas, cada una con
/// su palabra, y se funden en el logotipo, sincronizadas con el audio.
///
/// El reloj de la animación sigue la posición real del audio: si el teléfono
/// tarda en arrancar el sonido, la animación se ajusta suavemente para que
/// cada letra coincida con su campanada. El botón "Omitir" (o tocar la
/// pantalla) salta la intro y lleva directo al inicio de sesión.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _tiempo = ValueNotifier<double>(0);
  final _audio = AudioPlayer();
  late final Ticker _ticker = createTicker(_avanzar);
  late final _fondo = FondoPainter(_tiempo);
  late final _letras = LetrasPainter(_tiempo);
  StreamSubscription<Duration>? _posicionAudio;

  /// Segundos ya reproducidos antes del último arranque del ticker.
  double _base = 0;
  double _transcurrido = 0;

  /// Desfase frente al audio: se corrige poco a poco para no dar saltos.
  double _ajuste = 0;
  double _ajusteObjetivo = 0;

  bool _iniciado = false;
  bool _saliendo = false;

  /// El botón Omitir aparece al poco de abrir, aunque el audio aún no arranque.
  bool _mostrarOmitir = false;
  Timer? _temporizadorOmitir;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _temporizadorOmitir = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _mostrarOmitir = true);
    });
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      await _audio.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build(),
      );
      await _audio.setReleaseMode(ReleaseMode.stop);
      await _audio.setSource(AssetSource('audio/splash_intro.mp3')).timeout(const Duration(milliseconds: 800));
      _posicionAudio = _audio.onPositionChanged.listen(_sincronizar);
      await _audio.resume();
    } catch (_) {
      // Sin audio (error o demora) la intro se ve igual.
    }
    if (!mounted) return;
    _iniciado = true;
    _ticker.start();
  }

  double get _reloj => _base + _transcurrido;

  void _avanzar(Duration elapsed) {
    _transcurrido = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _ajuste += (_ajusteObjetivo - _ajuste) * 0.15;
    // El tiempo nunca retrocede: si el audio va atrasado, la animación lo espera.
    final t = math.max(_tiempo.value, math.min(_reloj + _ajuste, Guion.duracion));
    _tiempo.value = t;
    if (t >= Guion.duracion) _salir();
  }

  void _sincronizar(Duration posicion) {
    if (!_ticker.isActive || posicion == Duration.zero) return;
    _ajusteObjetivo = posicion.inMicroseconds / Duration.microsecondsPerSecond - _reloj;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_iniciado || _saliendo) return;
    if (state == AppLifecycleState.paused && _ticker.isActive) {
      _ticker.stop();
      _base = _tiempo.value;
      _transcurrido = _ajuste = _ajusteObjetivo = 0;
      _audio.pause();
    } else if (state == AppLifecycleState.resumed && !_ticker.isActive) {
      _audio.resume();
      _ticker.start();
    }
  }

  void _salir() {
    if (_saliendo) return;
    _saliendo = true;
    _ticker.stop();
    // Si se saltó la intro, el sonido se apaga en vez de cortarse en seco.
    if (_tiempo.value < Guion.duracion) unawaited(_apagarAudio());
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animacion, _, child) => FadeTransition(opacity: animacion, child: child),
      ),
    );
  }

  Future<void> _apagarAudio() async {
    try {
      for (final volumen in [0.6, 0.3, 0.1]) {
        await _audio.setVolume(volumen);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      await _audio.stop();
    } catch (_) {
      // El reproductor pudo cerrarse ya junto con la pantalla.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporizadorOmitir?.cancel();
    _ticker.dispose();
    _posicionAudio?.cancel();
    _audio.dispose();
    _letras.liberar();
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Paleta.cielo.first,
        body: Semantics(
          label: 'ServiApp',
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _iniciado ? _salir : null,
                child: SizedBox.expand(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _fondo, foregroundPainter: _letras),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 16, 0),
                    // Aparece al abrir y se va cuando el logo ya está formado (ahí la
                    // intro está por terminar). No depende del audio: si el sonido
                    // tarda en arrancar, igual se puede saltar.
                    child: ValueListenableBuilder<double>(
                      valueListenable: _tiempo,
                      builder: (context, t, boton) {
                        final visible = _mostrarOmitir && !_saliendo && t < Guion.impactoLogo;
                        return AnimatedOpacity(
                          opacity: visible ? 1 : 0,
                          duration: const Duration(milliseconds: 400),
                          child: IgnorePointer(ignoring: !visible, child: boton),
                        );
                      },
                      child: _BotonOmitir(onTap: _salir),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón para saltar la intro e ir directo al inicio de sesión.
class _BotonOmitir extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonOmitir({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Omitir la intro',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        shape: StadiumBorder(side: BorderSide(color: Paleta.palabra.withValues(alpha: 0.18))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Omitir',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Paleta.palabra,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.skip_next_rounded, size: 20, color: Paleta.palabra),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
