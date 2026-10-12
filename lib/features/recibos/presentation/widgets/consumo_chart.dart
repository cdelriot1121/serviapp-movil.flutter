import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';
import '../utils/formatos.dart';

/// Gráfica de barras del historial de consumo (el mes actual resaltado).
class ConsumoChart extends StatelessWidget {
  final List<ConsumoMensual> historial;
  final Color color;
  final String unidad;

  const ConsumoChart({
    super.key,
    required this.historial,
    required this.color,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    final maximo = historial.fold<double>(
      0,
      (m, c) => c.consumo != null && c.consumo! > m ? c.consumo! : m,
    );

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final c in historial)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      c.consumo == null ? '?' : formatearNumero(c.consumo),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: c.esActual ? FontWeight.bold : FontWeight.w500,
                        color: c.esActual ? color : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maximo > 0 && c.consumo != null ? c.consumo! / maximo : 0,
                      ),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, fraccion, _) => Container(
                        height: 4 + 110 * fraccion,
                        decoration: BoxDecoration(
                          color: c.esActual ? color : color.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
