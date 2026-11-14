import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../recibos/data/models/recibo.dart';

/// Servicio afectado, con los mismos valores del formulario de la web.
enum ServicioFalla {
  energia('energia', Empresa.afinia),
  agua('agua', Empresa.aguasDeCartagena),
  gas('gas', Empresa.surtigas);

  const ServicioFalla(this.valor, this.empresa);

  final String valor;
  final Empresa empresa;

  String get nombre => empresa.servicio;
  IconData get icono => empresa.icono;
  Color get color => empresa.color;

  /// Acepta "energia", "ENERGIA" o "energía" (los cortes usan mayúsculas).
  static ServicioFalla? de(String? valor) {
    final clave = valor?.trim().toLowerCase().replaceAll('í', 'i');
    for (final s in values) {
      if (s.valor == clave) return s;
    }
    return null;
  }
}

/// Estados de una falla en Spring Boot.
enum EstadoFalla {
  pendiente('PENDIENTE', 'Pendiente', Icons.schedule_rounded, AppColors.orange),
  recibido('RECIBIDO', 'En revisión', Icons.engineering_rounded, AppColors.primary),
  completado('COMPLETADO', 'Solucionada', Icons.check_circle_rounded, AppColors.green);

  const EstadoFalla(this.valor, this.texto, this.icono, this.color);

  final String valor;
  final String texto;
  final IconData icono;
  final Color color;

  static EstadoFalla de(String? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => pendiente);
}

class Falla {
  final String id;
  final ServicioFalla? servicio;
  final String barrio;
  final String? comentarios;
  final EstadoFalla estado;

  /// Hora aproximada en que empezó la falla.
  final DateTime? hora;
  final DateTime? fechaReporte;
  final DateTime? fechaSolucion;

  /// Vecinos que marcaron "A mí también".
  final int confirmaciones;
  final bool esMia;
  final bool yoConfirme;

  // Solo en el panel de administradores
  final String? usuarioNombre;
  final String? usuarioEmail;

  const Falla({
    required this.id,
    required this.servicio,
    required this.barrio,
    required this.comentarios,
    required this.estado,
    required this.hora,
    required this.fechaReporte,
    required this.fechaSolucion,
    required this.confirmaciones,
    required this.esMia,
    required this.yoConfirme,
    this.usuarioNombre,
    this.usuarioEmail,
  });

  factory Falla.fromJson(Map<String, dynamic> json) => Falla(
        id: json['id'].toString(),
        servicio: ServicioFalla.de(json['servicio']?.toString()),
        barrio: json['barrio']?.toString() ?? '',
        comentarios: json['comentarios']?.toString(),
        estado: EstadoFalla.de(json['estado']?.toString()),
        hora: fechaIso(json['hora']),
        fechaReporte: fechaIso(json['fechaReporte']),
        fechaSolucion: fechaIso(json['fechaSolucion']),
        confirmaciones: (json['confirmaciones'] as num?)?.toInt() ?? 0,
        esMia: json['esMia'] == true,
        yoConfirme: json['yoConfirme'] == true,
        usuarioNombre: json['usuarioNombre']?.toString(),
        usuarioEmail: json['usuarioEmail']?.toString(),
      );

  bool get activa => estado != EstadoFalla.completado;

  String get nombreServicio => servicio?.nombre ?? 'Servicio';

  Falla copiar({EstadoFalla? estado, DateTime? fechaSolucion, int? confirmaciones, bool? yoConfirme}) => Falla(
        id: id,
        servicio: servicio,
        barrio: barrio,
        comentarios: comentarios,
        estado: estado ?? this.estado,
        hora: hora,
        fechaReporte: fechaReporte,
        fechaSolucion: fechaSolucion ?? this.fechaSolucion,
        confirmaciones: confirmaciones ?? this.confirmaciones,
        esMia: esMia,
        yoConfirme: yoConfirme ?? this.yoConfirme,
        usuarioNombre: usuarioNombre,
        usuarioEmail: usuarioEmail,
      );
}

/// Corte programado por un administrador en el barrio del usuario.
class CorteProgramado {
  final String id;
  final ServicioFalla? servicio;

  /// Día del calendario (sin hora).
  final DateTime? fecha;
  final String? horaInicio;
  final String? horaFinal;
  final String? motivo;

  const CorteProgramado({
    required this.id,
    required this.servicio,
    required this.fecha,
    required this.horaInicio,
    required this.horaFinal,
    required this.motivo,
  });

  factory CorteProgramado.fromJson(Map<String, dynamic> json) => CorteProgramado(
        id: json['id'].toString(),
        servicio: ServicioFalla.de(json['servicio']?.toString()),
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        horaInicio: json['horaInicio']?.toString(),
        horaFinal: json['horaFinal']?.toString(),
        motivo: json['motivo']?.toString(),
      );
}

/// Fallas activas y cortes del barrio del predio.
class ResumenBarrio {
  final String? barrio;
  final List<Falla> fallas;
  final List<CorteProgramado> cortes;

  const ResumenBarrio({required this.barrio, required this.fallas, required this.cortes});

  factory ResumenBarrio.fromJson(Map<String, dynamic> json) => ResumenBarrio(
        barrio: json['barrio']?.toString(),
        fallas: [
          for (final f in json['fallas'] as List? ?? const [])
            Falla.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        cortes: [
          for (final c in json['cortes'] as List? ?? const [])
            CorteProgramado.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
      );
}

class OpcionesFalla {
  final List<String> barrios;
  final String? miBarrio;

  const OpcionesFalla({required this.barrios, required this.miBarrio});

  factory OpcionesFalla.fromJson(Map<String, dynamic> json) => OpcionesFalla(
        barrios: [for (final b in json['barrios'] as List? ?? const []) b.toString()],
        miBarrio: json['miBarrio']?.toString(),
      );
}

/// ISO de Spring (UTC) -> hora local del celular.
DateTime? fechaIso(Object? valor) => valor == null ? null : DateTime.tryParse(valor.toString())?.toLocal();

/// "ALCIBIA" -> "Alcibia", "SAN DIEGO" -> "San Diego"
String nombreBarrio(String? barrio) {
  if (barrio == null || barrio.trim().isEmpty) return '';
  return barrio
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

/// "hace 5 min", "hace 2 h", "ayer", "12/11/2026"
String haceCuanto(DateTime? cuando) {
  if (cuando == null) return '';
  final diferencia = DateTime.now().difference(cuando);
  if (diferencia.inMinutes < 1) return 'ahora';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'ayer';
  if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} días';
  return '${cuando.day.toString().padLeft(2, '0')}/${cuando.month.toString().padLeft(2, '0')}/${cuando.year}';
}

/// 15:40 -> "3:40 p. m."
String horaCorta(DateTime? cuando) {
  if (cuando == null) return '—';
  final h = cuando.hour % 12 == 0 ? 12 : cuando.hour % 12;
  final m = cuando.minute.toString().padLeft(2, '0');
  return '$h:$m ${cuando.hour < 12 ? 'a. m.' : 'p. m.'}';
}
