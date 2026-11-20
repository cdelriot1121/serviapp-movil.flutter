import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../data/pronostico.dart';

/// Los tres servicios con la tendencia de consumo que se espera para el día.
class ConsumosDelDia extends StatelessWidget {
  final TipoDia tipo;

  const ConsumosDelDia({super.key, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final servicios = [
      (Empresa.afinia, tipo.energia),
      (Empresa.aguasDeCartagena, tipo.agua),
      (Empresa.surtigas, tipo.gas),
    ];

    return Row(
      children: [
        for (final (i, (empresa, tendencia)) in servicios.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _Servicio(empresa: empresa, tendencia: tendencia)),
        ],
      ],
    );
  }
}

class _Servicio extends StatelessWidget {
  final Empresa empresa;
  final Tendencia tendencia;

  const _Servicio({required this.empresa, required this.tendencia});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${empresa.servicio}: ${tendencia.texto}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: empresa.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(empresa.icono, color: empresa.color, size: 21),
            ),
            const SizedBox(height: 6),
            Text(
              empresa.servicio,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tendencia.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tendencia.icono, color: tendencia.color, size: 14),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      tendencia.texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tendencia.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
