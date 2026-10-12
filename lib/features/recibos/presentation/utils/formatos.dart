import '../../data/models/recibo.dart';

const _mesesCortos = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

const mesesLargos = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// 427630 -> "$ 427.630"
String formatearPesos(int? valor) {
  if (valor == null) return '—';
  return '\$ ${_miles(valor.toString())}';
}

/// 502.0 -> "502", 15.61 -> "15,61"
String formatearNumero(double? valor) {
  if (valor == null) return '—';
  if (valor == valor.roundToDouble()) return _miles(valor.toInt().toString());
  return valor.toStringAsFixed(2).replaceAll('.', ',');
}

String _miles(String digitos) {
  final negativo = digitos.startsWith('-');
  final limpio = negativo ? digitos.substring(1) : digitos;
  final buffer = StringBuffer();
  for (var i = 0; i < limpio.length; i++) {
    if (i > 0 && (limpio.length - i) % 3 == 0) buffer.write('.');
    buffer.write(limpio[i]);
  }
  return '${negativo ? '-' : ''}$buffer';
}

/// DateTime -> "17/09/2026"
String formatearFecha(DateTime? fecha) {
  if (fecha == null) return '—';
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

/// "2026-09" -> "Sep 2026"
String formatearPeriodoCorto(String? periodo) {
  final p = Periodo.parse(periodo);
  if (p == null) return periodo ?? '—';
  return '${_mesesCortos[p.mes - 1]} ${p.anio}';
}

/// "2026-09" -> "Septiembre 2026"
String formatearPeriodoLargo(String? periodo) {
  final p = Periodo.parse(periodo);
  if (p == null) return periodo ?? '—';
  return '${mesesLargos[p.mes - 1]} ${p.anio}';
}

/// "2026-09" -> "Sep"
String mesCorto(String periodo) {
  final p = Periodo.parse(periodo);
  return p == null ? periodo : _mesesCortos[p.mes - 1];
}
