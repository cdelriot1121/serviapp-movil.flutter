import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/pronostico.dart';
import 'consumos_del_dia.dart';

/// Ventana con el clima de ahora, las próximas horas y cómo irán los consumos.
class ClimaSheet extends StatelessWidget {
  final Pronostico pronostico;

  const ClimaSheet({super.key, required this.pronostico});

  static Future<void> mostrar(BuildContext context, Pronostico pronostico) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClimaSheet(pronostico: pronostico),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.of(context).padding.bottom;
    final actual = pronostico.actual;
    final tipo = pronostico.hoy.tipo;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + inferior),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clima en Cartagena',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Actualizado ${_horaConMinutos(actual.hora)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TarjetaAhora(pronostico: pronostico),
            const SizedBox(height: 22),
            Text('Próximas horas', style: estiloTitulo(16)),
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pronostico.horas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) =>
                    _Hora(hora: pronostico.horas[i], esAhora: i == 0),
              ),
            ),
            const SizedBox(height: 22),
            Text('Tus consumos hoy', style: estiloTitulo(16)),
            const SizedBox(height: 4),
            Text(
              tipo.motivo,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ConsumosDelDia(tipo: tipo),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }

  static String _horaConMinutos(DateTime hora) {
    final h = hora.hour % 12 == 0 ? 12 : hora.hour % 12;
    final m = hora.minute.toString().padLeft(2, '0');
    return 'a las $h:$m ${hora.hour < 12 ? 'a. m.' : 'p. m.'}';
  }
}

// Clima de este momento sobre el degradado del tipo de día.
class _TarjetaAhora extends StatelessWidget {
  final Pronostico pronostico;

  const _TarjetaAhora({required this.pronostico});

  @override
  Widget build(BuildContext context) {
    final actual = pronostico.actual;
    final hoy = pronostico.hoy;
    final colores = hoy.tipo.colores;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colores,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colores.last.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Icono grande de fondo, como marca de agua
          Positioned(
            right: -26,
            top: -30,
            child: Icon(
              actual.icono,
              size: 130,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grados(actual.temperatura),
                          style: estiloTitulo(50, color: Colors.white)
                              .copyWith(height: 1),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(actual.icono, color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actual.descripcion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Máx. ${grados(hoy.maxima)} · Mín. ${grados(hoy.minima)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Dato(
                    icono: Icons.thermostat_rounded,
                    texto: 'Sensación ${grados(actual.sensacion)}',
                  ),
                  const SizedBox(height: 8),
                  _Dato(
                    icono: Icons.water_rounded,
                    texto: 'Humedad ${actual.humedad} %',
                  ),
                  const SizedBox(height: 8),
                  _Dato(
                    icono: Icons.umbrella_rounded,
                    texto: 'Lluvia ${hoy.probLluvia} %',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Dato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Una hora del pronóstico, como en el buscador.
class _Hora extends StatelessWidget {
  final ClimaHora hora;
  final bool esAhora;

  const _Hora({required this.hora, required this.esAhora});

  @override
  Widget build(BuildContext context) {
    final lluvia = hora.probLluvia >= 10;

    return Container(
      width: 66,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: esAhora
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esAhora
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            esAhora ? 'Ahora' : formatearHora(hora.hora),
            style: TextStyle(
              fontSize: 12,
              fontWeight: esAhora ? FontWeight.w800 : FontWeight.w600,
              color: esAhora ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          Icon(
            hora.cielo.icono(esDeDia: hora.esDeDia),
            color: hora.cielo.color(esDeDia: hora.esDeDia),
            size: 26,
          ),
          Text(
            grados(hora.temperatura),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          // Se deja el espacio aunque no llueva para que todas midan igual
          Opacity(
            opacity: lluvia ? 1 : 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.water_drop_rounded,
                  size: 11,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  '${hora.probLluvia} %',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
