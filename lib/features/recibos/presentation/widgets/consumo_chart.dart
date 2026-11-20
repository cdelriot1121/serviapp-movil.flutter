import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';
import '../utils/formatos.dart';

/// Gráfica de barras del historial de consumo (el mes actual resaltado).
///
/// Con [estimados] (periodo → consumo predicho) marca cada predicción con una
/// raya oscura; si ese mes aún no tiene consumo real, la barra va sin relleno.
class ConsumoChart extends StatelessWidget {
  final List<ConsumoMensual> historial;
  final Color color;
  final String unidad;
  final Map<String, double> estimados;

  const ConsumoChart({
    super.key,
    required this.historial,
    required this.color,
    required this.unidad,
    this.estimados = const {},
  });

  static const _alto = 110.0;

  @override
  Widget build(BuildContext context) {
    var maximo = 0.0;
    for (final c in historial) {
      maximo = math.max(maximo, math.max(c.consumo ?? 0, estimados[c.periodo] ?? 0));
    }

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final c in historial)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _columna(c, estimados[c.periodo], maximo),
              ),
            ),
        ],
      ),
    );
  }

  Widget _columna(ConsumoMensual c, double? estimado, double maximo) {
    final real = c.consumo;
    final soloEstimado = real == null && estimado != null;
    final valor = real ?? estimado;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          valor == null ? '?' : formatearNumero(valor),
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: 11,
            fontWeight: c.esActual ? FontWeight.bold : FontWeight.w500,
            fontStyle: soloEstimado ? FontStyle.italic : FontStyle.normal,
            color: c.esActual ? color : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            double alto(double? v) => maximo > 0 && v != null ? 4 + _alto * (v / maximo) * t : 4;
            final barra = alto(real ?? estimado);
            final marca = estimado == null || soloEstimado ? null : alto(estimado);

            return SizedBox(
              height: math.max(barra, (marca ?? 0) + 2),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: barra,
                    decoration: BoxDecoration(
                      color: soloEstimado
                          ? color.withValues(alpha: 0.08)
                          : c.esActual
                          ? color
                          : color.withValues(alpha: 0.28),
                      border: soloEstimado ? Border.all(color: color, width: 1.4) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  if (marca != null)
                    Positioned(
                      left: -2,
                      right: -2,
                      bottom: marca - 2,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          mesCorto(c.periodo),
          style: TextStyle(
            fontSize: 11,
            fontWeight: c.esActual ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
