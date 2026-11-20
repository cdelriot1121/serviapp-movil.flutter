import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../data/explicacion_consumo.dart';
import '../../data/pronostico.dart';
import '../views/por_que_cambio_screen.dart';

/// Colores e icono de cada explicación, tomados de los tipos de día.
extension EstiloExplicacion on ExplicacionConsumo {
  bool get _masLluvioso =>
      climaActual.lluviosos > climaAnterior.lluviosos;

  List<Color> get colores => switch ((causa, subio)) {
        (Causa.estable, _) => TipoDia.normal.colores,
        (Causa.clima, true) => TipoDia.caluroso.colores,
        (Causa.clima, false) =>
          (_masLluvioso ? TipoDia.lluvioso : TipoDia.fresco).colores,
        (Causa.dias, _) => const [AppColors.logo, AppColors.primary],
        (Causa.hogar, true) => const [Color(0xFFFF8A65), AppColors.red],
        (Causa.hogar, false) => const [AppColors.leafLight, AppColors.green],
      };

  IconData get icono => switch ((causa, subio)) {
        (Causa.estable, _) => Icons.balance_rounded,
        (Causa.clima, true) => TipoDia.caluroso.icono,
        (Causa.clima, false) =>
          (_masLluvioso ? TipoDia.lluvioso : TipoDia.fresco).icono,
        (Causa.dias, _) => Icons.calendar_month_rounded,
        (Causa.hogar, true) => Icons.manage_search_rounded,
        (Causa.hogar, false) => Icons.emoji_events_rounded,
      };

  /// Pregunta que responde la pantalla.
  String get pregunta => causa == Causa.estable
      ? '¿Cómo te fue este mes?'
      : subio
          ? '¿Por qué subió tu recibo?'
          : '¿Por qué bajó tu recibo?';
}

/// Tarjeta del detalle del recibo que lleva a "¿Por qué subió mi recibo?".
/// No aparece si no hay un periodo anterior con qué comparar.
class TarjetaPorQue extends StatefulWidget {
  final Recibo recibo;

  const TarjetaPorQue({super.key, required this.recibo});

  @override
  State<TarjetaPorQue> createState() => _TarjetaPorQueState();
}

class _TarjetaPorQueState extends State<TarjetaPorQue> {
  late final _explicacion = ExplicacionConsumo.de(widget.recibo);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExplicacionConsumo?>(
      future: _explicacion,
      builder: (context, snapshot) {
        final e = snapshot.data;
        return AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: e == null ? const SizedBox(width: double.infinity) : _Tarjeta(e),
        );
      },
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final ExplicacionConsumo e;

  const _Tarjeta(this.e);

  @override
  Widget build(BuildContext context) {
    final colores = e.colores;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PorQueCambioScreen(explicacion: e)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colores.last.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colores.first.withValues(alpha: 0.10),
                  AppColors.surface,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colores,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colores.last.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(e.icono, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.pregunta,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(e.titulo, style: estiloTitulo(16)),
                      const SizedBox(height: 4),
                      Text(
                        '${porcentaje(e.cambio)} de ${e.empresa.servicio.toLowerCase()} '
                        'frente al mes anterior',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colores.last,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colores.last),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
