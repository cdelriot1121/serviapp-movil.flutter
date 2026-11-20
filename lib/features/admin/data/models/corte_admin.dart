import '../../../fallas/data/models/falla.dart';

/// Corte programado tal como lo ve el administrador: con sus barrios, si
/// sigue vigente y a cuántos usuarios les llegó el aviso.
class CorteAdmin {
  final String id;
  final ServicioFalla? servicio;

  /// Día del calendario (sin hora).
  final DateTime? fecha;
  final String? horaInicio;
  final String? horaFinal;
  final String? motivo;
  final List<String> barrios;

  /// Aún no termina (los usuarios lo ven en "Mi barrio").
  final bool vigente;

  /// Usuarios que viven en los barrios afectados.
  final int usuariosAfectados;

  const CorteAdmin({
    required this.id,
    required this.servicio,
    required this.fecha,
    required this.horaInicio,
    required this.horaFinal,
    required this.motivo,
    required this.barrios,
    required this.vigente,
    required this.usuariosAfectados,
  });

  factory CorteAdmin.fromJson(Map<String, dynamic> json) => CorteAdmin(
        id: json['id'].toString(),
        servicio: ServicioFalla.de(json['servicio']?.toString()),
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        horaInicio: json['horaInicio']?.toString(),
        horaFinal: json['horaFinal']?.toString(),
        motivo: json['motivo']?.toString(),
        barrios: [for (final b in json['barrios'] as List? ?? const []) b.toString()],
        vigente: json['vigente'] == true,
        usuariosAfectados: (json['usuariosAfectados'] as num?)?.toInt() ?? 0,
      );

  String get nombreServicio => servicio?.nombre ?? 'Servicio';

  /// "08:00 – 12:00"
  String get horario =>
      horaInicio == null ? 'Todo el día' : '$horaInicio – ${horaFinal ?? ''}';
}

/// Lo necesario para programar un corte.
class OpcionesCorte {
  final List<String> barrios;

  /// Usuarios que viven en cada barrio (los que recibirán el aviso).
  final Map<String, int> usuariosPorBarrio;

  const OpcionesCorte({required this.barrios, required this.usuariosPorBarrio});

  factory OpcionesCorte.fromJson(Map<String, dynamic> json) {
    final usuarios = json['usuariosPorBarrio'];
    return OpcionesCorte(
      barrios: [for (final b in json['barrios'] as List? ?? const []) b.toString()],
      usuariosPorBarrio: {
        if (usuarios is Map)
          for (final e in usuarios.entries)
            e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      },
    );
  }

  int usuariosEn(Iterable<String> barrios) =>
      barrios.fold(0, (total, b) => total + (usuariosPorBarrio[b] ?? 0));
}

/// "lunes 24 de noviembre"
String fechaLarga(DateTime? fecha) {
  if (fecha == null) return '—';
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${dias[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1]}';
}

/// Hoy, mañana o la fecha larga.
String diaRelativo(DateTime? fecha, {DateTime? hoy}) {
  if (fecha == null) return '—';
  final ahora = hoy ?? DateTime.now();
  final dias = DateTime(fecha.year, fecha.month, fecha.day)
      .difference(DateTime(ahora.year, ahora.month, ahora.day))
      .inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Mañana';
  final texto = fechaLarga(fecha);
  return texto[0].toUpperCase() + texto.substring(1);
}
