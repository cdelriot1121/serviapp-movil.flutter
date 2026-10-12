import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';
import 'formatos.dart';

const _rojo = Color(0xFFE5484D);

/// Estado de pago de un recibo respecto a su fecha de pago oportuno.
class EstadoPago {
  final String texto;
  final IconData icono;
  final Color color;

  /// Días que faltan para el pago oportuno (negativo si ya pasó).
  final int? dias;

  const EstadoPago._(this.texto, this.icono, this.color, this.dias);

  bool get vencido => dias != null && dias! < 0;

  factory EstadoPago.de(Recibo recibo, {DateTime? ahora}) {
    if (recibo.pagado) {
      final fecha = recibo.fechaPago;
      return EstadoPago._(
        fecha == null ? 'Pagado' : 'Pagado el ${formatearFecha(fecha)}',
        Icons.check_circle_rounded,
        AppColors.green,
        null,
      );
    }

    final limite = recibo.fechaLimitePago;
    if (limite == null) {
      return const EstadoPago._(
        'Pendiente de pago',
        Icons.schedule_rounded,
        AppColors.textSecondary,
        null,
      );
    }

    final dias = diasHasta(limite, ahora: ahora);
    if (dias < 0) {
      return EstadoPago._(
        dias == -1 ? 'Venció ayer' : 'Vencido hace ${-dias} días',
        Icons.error_rounded,
        _rojo,
        dias,
      );
    }
    if (dias == 0) {
      return EstadoPago._('Vence hoy', Icons.warning_rounded, _rojo, dias);
    }
    if (dias == 1) {
      return EstadoPago._('Vence mañana', Icons.warning_rounded, AppColors.orange, dias);
    }
    return EstadoPago._(
      'Vence el ${formatearFecha(limite)}',
      Icons.schedule_rounded,
      dias <= 5 ? AppColors.orange : AppColors.primary,
      dias,
    );
  }
}

/// Días de calendario entre hoy y [fecha] (0 = hoy).
int diasHasta(DateTime fecha, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final a = DateTime.utc(hoy.year, hoy.month, hoy.day);
  final b = DateTime.utc(fecha.year, fecha.month, fecha.day);
  return b.difference(a).inDays;
}

/// Último recibo de cada servicio (empresa + identificador) sin pagar,
/// ordenado por la fecha de pago más cercana. Alimenta "Tus pagos" del inicio.
List<Recibo> pagosPendientes(List<Recibo> recibos) {
  final ultimos = <String, Recibo>{};
  for (final r in recibos) {
    final clave = '${r.empresa.codigo}|${r.identificador}';
    final actual = ultimos[clave];
    final periodo = Periodo.parse(r.periodoFacturado);
    final periodoActual = Periodo.parse(actual?.periodoFacturado);
    if (actual == null ||
        (periodo != null && (periodoActual == null || periodo.compareTo(periodoActual) > 0))) {
      ultimos[clave] = r;
    }
  }
  final pendientes = [
    for (final r in ultimos.values)
      if (!r.pagado && r.fechaLimitePago != null) r,
  ]..sort((a, b) => a.fechaLimitePago!.compareTo(b.fechaLimitePago!));
  return pendientes;
}
