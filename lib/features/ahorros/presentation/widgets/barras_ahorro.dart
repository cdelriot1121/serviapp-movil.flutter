import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/widgets/graficas.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../data/models/resumen_ahorro.dart';

/// Barras del ahorro de cada mes: hacia arriba en verde los meses con
/// ahorro y hacia abajo en rojo los meses en que se gastó de más.
/// Mismo estilo que la gráfica de consumo de los recibos.
class BarrasAhorro extends StatelessWidget {
  final List<AhorroMes> meses;

  const BarrasAhorro({super.key, required this.meses});

  static const double _alto = 120;

  @override
  Widget build(BuildContext context) {
    if (meses.isEmpty) return const SinDatos();

    final maximo = meses.fold<int>(0, (m, e) => math.max(m, e.ahorro.abs()));
    final hayPositivos = meses.any((m) => m.ahorro > 0);
    final hayNegativos = meses.any((m) => m.ahorro < 0);

    // El eje queda al medio solo si hay meses de los dos tipos
    final altoArriba = hayNegativos ? (hayPositivos ? _alto / 2 : 0.0) : _alto;
    final altoAbajo = _alto - altoArriba;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final mes in meses)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Columna(
                mes: mes,
                fraccion: maximo > 0 ? mes.ahorro.abs() / maximo : 0,
                altoArriba: altoArriba,
                altoAbajo: altoAbajo,
              ),
            ),
          ),
      ],
    );
  }
}

class _Columna extends StatelessWidget {
  final AhorroMes mes;
  final double fraccion;
  final double altoArriba;
  final double altoAbajo;

  const _Columna({
    required this.mes,
    required this.fraccion,
    required this.altoArriba,
    required this.altoAbajo,
  });

  @override
  Widget build(BuildContext context) {
    final estado = EstadoAhorro.dePesos(mes.ahorro);
    final color = estado.color;

    Widget barra(double alto, {required bool haciaArriba}) =>
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraccion),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => Container(
            height: math.max(4, alto * f),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: haciaArriba
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                end: haciaArriba ? Alignment.topCenter : Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.75), color],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _pesosCortos(mes.ahorro),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: mes.ahorro == 0 ? AppColors.textSecondary : color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: altoArriba,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: mes.ahorro > 0 ? barra(altoArriba, haciaArriba: true) : null,
          ),
        ),
        Container(height: 1.5, color: AppColors.border),
        SizedBox(
          height: altoAbajo,
          child: Align(
            alignment: Alignment.topCenter,
            child: mes.ahorro < 0 ? barra(altoAbajo, haciaArriba: false) : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          mesCorto(mes.periodo),
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// 40000 -> "+$40 mil", -1250000 -> "-$1,3 M"
  static String _pesosCortos(int valor) {
    if (valor == 0) return '\$0';
    final signo = valor > 0 ? '+' : '-';
    final abs = valor.abs();
    if (abs >= 1000000) {
      return '$signo\$${(abs / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    if (abs >= 1000) return '$signo\$${(abs / 1000).round()} mil';
    return '$signo\$$abs';
  }
}
