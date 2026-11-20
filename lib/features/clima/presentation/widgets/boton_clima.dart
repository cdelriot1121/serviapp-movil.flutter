import 'package:flutter/material.dart';

import '../../data/clima_service.dart';
import '../../data/pronostico.dart';
import 'clima_sheet.dart';

/// Pastilla del clima en el encabezado del inicio. Al tocarla abre el
/// pronóstico por horas. Mientras carga o sin internet muestra [mientras].
class BotonClima extends StatelessWidget {
  final Widget mientras;

  const BotonClima({super.key, required this.mientras});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Pronostico?>(
      valueListenable: ClimaService.pronostico,
      builder: (context, pronostico, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (hijo, animacion) => FadeTransition(
          opacity: animacion,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animacion),
            child: hijo,
          ),
        ),
        layoutBuilder: (actual, anteriores) => Stack(
          alignment: Alignment.centerLeft,
          children: [...anteriores, ?actual],
        ),
        child: pronostico == null
            ? KeyedSubtree(key: const ValueKey('mientras'), child: mientras)
            : _Pastilla(key: const ValueKey('clima'), pronostico: pronostico),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final Pronostico pronostico;

  const _Pastilla({super.key, required this.pronostico});

  @override
  Widget build(BuildContext context) {
    final actual = pronostico.actual;

    return Semantics(
      button: true,
      label: 'Clima en Cartagena: ${grados(actual.temperatura)}, '
          '${actual.descripcion}. Ver pronóstico por horas',
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ClimaSheet.mostrar(context, pronostico),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(actual.icono, color: actual.color, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  grados(actual.temperatura),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${actual.descripcion} en Cartagena',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
