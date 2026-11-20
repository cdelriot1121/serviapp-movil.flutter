import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/pronostico.dart';
import 'clima_sheet.dart';
import 'consumos_del_dia.dart';

/// Alerta de la primera entrada del día: qué clima viene y cómo afectará
/// los consumos del hogar.
class AlertaClima extends StatelessWidget {
  final Pronostico pronostico;

  const AlertaClima({super.key, required this.pronostico});

  static Future<void> mostrar(BuildContext context, Pronostico pronostico) async {
    final verHoras = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, _, _) => AlertaClima(pronostico: pronostico),
      // Entra con un pequeño rebote, como un sweet alert
      transitionBuilder: (_, animacion, _, hijo) => FadeTransition(
        opacity: CurvedAnimation(parent: animacion, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.82, end: 1.0).animate(
            CurvedAnimation(
              parent: animacion,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
          ),
          child: hijo,
        ),
      ),
    );

    if (verHoras == true && context.mounted) {
      await ClimaSheet.mostrar(context, pronostico);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = pronostico.hoy;
    final tipo = hoy.tipo;

    final pronosticoTexto = StringBuffer(
      'En Cartagena se pronostica una máxima de ${grados(hoy.maxima)}C '
      'con sensación térmica de ${grados(hoy.sensacionMaxima)}C',
    );
    if (hoy.probLluvia >= 40) {
      pronosticoTexto.write(' y ${hoy.probLluvia} % de probabilidad de lluvia');
    }
    pronosticoTexto.write('.');

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Cabecera(tipo: tipo, temperatura: hoy.maxima),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                      child: Column(
                        children: [
                          Text(
                            tipo.titulo,
                            textAlign: TextAlign.center,
                            style: estiloTitulo(21),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pronosticoTexto.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Así irán tus consumos hoy',
                              style: estiloTitulo(15),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ConsumosDelDia(tipo: tipo),
                          const SizedBox(height: 12),
                          Text(
                            tipo.motivo,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Consejo(texto: tipo.consejo, color: tipo.colores.last),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('¡Entendido!'),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.schedule_rounded, size: 19),
                            label: const Text('Ver el pronóstico por horas'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Franja de color del tipo de día con el icono animado y la temperatura.
class _Cabecera extends StatefulWidget {
  final TipoDia tipo;
  final double temperatura;

  const _Cabecera({required this.tipo, required this.temperatura});

  @override
  State<_Cabecera> createState() => _CabeceraState();
}

class _CabeceraState extends State<_Cabecera>
    with SingleTickerProviderStateMixin {
  late final _control = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.tipo;
    // El sol gira despacio; lo demás flota
    final gira = tipo == TipoDia.caluroso;

    return Container(
      height: 168,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tipo.colores,
        ),
      ),
      child: AnimatedBuilder(
        animation: _control,
        builder: (context, _) {
          final t = _control.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Burbujas decorativas
              Positioned(
                left: -30,
                top: -40,
                child: _Circulo(tam: 130, alfa: 0.12),
              ),
              Positioned(
                right: -20,
                bottom: -50,
                child: _Circulo(tam: 150, alfa: 0.10),
              ),
              Positioned(
                right: 46,
                top: 22 + math.sin(t) * 4,
                child: _Circulo(tam: 14, alfa: 0.35),
              ),
              Positioned(
                left: 58,
                bottom: 30 + math.cos(t) * 4,
                child: _Circulo(tam: 9, alfa: 0.4),
              ),

              // Halo que late detrás del icono
              Transform.scale(
                scale: 1 + (math.sin(t * 2) + 1) * 0.06,
                child: _Circulo(tam: 112, alfa: 0.16),
              ),
              Transform.translate(
                offset: Offset(0, gira ? 0 : math.sin(t) * 5),
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Transform.rotate(
                    // 45° por ciclo: el sol tiene 8 rayos y el reinicio no se nota
                    angle: gira ? _control.value * math.pi / 4 : 0,
                    child: Icon(tipo.icono, color: Colors.white, size: 48),
                  ),
                ),
              ),

              // Temperatura máxima del día
              Positioned(
                right: 18,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    grados(widget.temperatura),
                    style: estiloTitulo(17, color: tipo.colores.last),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  final double tam;
  final double alfa;

  const _Circulo({required this.tam, required this.alfa});

  @override
  Widget build(BuildContext context) => Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alfa),
          shape: BoxShape.circle,
        ),
      );
}

class _Consejo extends StatelessWidget {
  final String texto;
  final Color color;

  const _Consejo({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
