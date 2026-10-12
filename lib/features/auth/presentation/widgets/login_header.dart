
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LoginHeader extends StatefulWidget {
  const LoginHeader({super.key});

  @override
  State<LoginHeader> createState() => _LoginHeaderState();
}

class _LoginHeaderState extends State<LoginHeader>
    with TickerProviderStateMixin {

  // Controlador de la animación de entrada
  late final AnimationController _entradaController;

  // Controlador del movimiento continuo
  late final AnimationController _movimientoController;

  late final Animation<double> _escalaLogo;
  late final Animation<double> _opacidad;
  late final Animation<Offset> _desplazamientoTexto;

  @override
  void initState() {
    super.initState();

    // Animación inicial: se ejecuta una sola vez
    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Animación continua: movimiento suave del fondo
    _movimientoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    // Efecto de rebote del logo
    _escalaLogo = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entradaController,
        curve: Curves.elasticOut,
      ),
    );

    // Aparición progresiva
    _opacidad = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entradaController,
        curve: const Interval(
          0.0,
          0.65,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Desplazamiento del nombre ServiApp
    _desplazamientoTexto = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entradaController,
        curve: const Interval(
          0.3,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // Iniciamos ambas animaciones
    _entradaController.forward();
    _movimientoController.repeat();
  }

  @override
  void dispose() {
    // Liberamos los controladores al cerrar la pantalla
    _entradaController.dispose();
    _movimientoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),

      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),

        child: Stack(
          children: [

            // FONDO ANIMADO
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _movimientoController,
                builder: (context, child) {
                  final movimiento =
                      _movimientoController.value * 2 * math.pi;

                  return Stack(
                    children: [
                      // Círculo superior derecho
                      Positioned(
                        top: -65 + math.sin(movimiento) * 15,
                        right: -55 + math.cos(movimiento) * 10,
                        child: _crearCirculo(
                          190,
                          0.08,
                        ),
                      ),

                      // Círculo inferior izquierdo
                      Positioned(
                        bottom: -75 + math.cos(movimiento) * 12,
                        left: -60 + math.sin(movimiento) * 15,
                        child: _crearCirculo(
                          180,
                          0.07,
                        ),
                      ),

                      // Círculo pequeño decorativo
                      Positioned(
                        top: 115 + math.sin(movimiento) * 10,
                        left: 35,
                        child: _crearCirculo(
                          35,
                          0.10,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // CONTENIDO PRINCIPAL
            SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // LOGO ANIMADO
                    FadeTransition(
                      opacity: _opacidad,
                      child: ScaleTransition(
                        scale: _escalaLogo,

                        child: Container(
                          padding: const EdgeInsets.all(18),

                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(22),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),

                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // AGUA
                              _iconoAnimado(
                                Icons.water_drop,
                                AppColors.primary,
                                0,
                              ),

                              const SizedBox(width: 12),

                              // ENERGÍA
                              _iconoAnimado(
                                Icons.bolt,
                                AppColors.orange,
                                1,
                              ),

                              const SizedBox(width: 12),

                              // GAS
                              _iconoAnimado(
                                Icons.local_fire_department,
                                AppColors.green,
                                2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // NOMBRE ANIMADO
                    FadeTransition(
                      opacity: _opacidad,
                      child: SlideTransition(
                        position: _desplazamientoTexto,
                        child: const Text(
                          'ServiApp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FUNCIÓN PARA CREAR CÍRCULOS DECORATIVOS
  Widget _crearCirculo(double tamano, double opacidad) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(
          alpha: opacidad,
        ),
      ),
    );
  }

  // FUNCIÓN PARA ANIMAR LOS ICONOS
  Widget _iconoAnimado(
    IconData icono,
    Color color,
    int posicion,
  ) {
    return AnimatedBuilder(
      animation: _movimientoController,
      builder: (context, child) {
        final tiempo =
            _movimientoController.value * 2 * math.pi;

        // Cada icono se mueve con un pequeño desfase
        final desplazamiento =
            math.sin(tiempo + posicion * 0.8) * 3;

        return Transform.translate(
          offset: Offset(0, desplazamiento),
          child: child,
        );
      },
      child: Icon(
        icono,
        color: color,
        size: 32,
      ),
    );
  }
}
