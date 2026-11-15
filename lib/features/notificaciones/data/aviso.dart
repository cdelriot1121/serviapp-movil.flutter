import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../fallas/data/models/falla.dart';
import '../../fallas/data/services/fallas_service.dart';

/// Tipos de aviso que crea Spring Boot (NotificacionModel.Tipo).
enum TipoAviso {
  fallaBarrio('FALLA_BARRIO', Icons.report_problem_rounded, AppColors.orange),
  estadoFalla('ESTADO_FALLA', Icons.assignment_turned_in_rounded, AppColors.primary),
  fallaSolucionada('FALLA_SOLUCIONADA', Icons.check_circle_rounded, AppColors.green),
  corteProgramado('CORTE_PROGRAMADO', Icons.event_busy_rounded, AppColors.red);

  const TipoAviso(this.valor, this.icono, this.color);

  final String valor;
  final IconData icono;
  final Color color;

  static TipoAviso de(String? valor) =>
      values.firstWhere((t) => t.valor == valor, orElse: () => fallaBarrio);

  /// Los avisos de sus propios reportes se ven en "Mis reportes"; el resto en "Mi barrio".
  bool get esDeMisReportes => this == estadoFalla;
}

class Aviso {
  final String id;
  final TipoAviso tipo;
  final String titulo;
  final String mensaje;
  final ServicioFalla? servicio;
  final String? barrio;
  final String? referenciaId;
  final DateTime? fecha;
  final bool leida;

  const Aviso({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.servicio,
    required this.barrio,
    required this.referenciaId,
    required this.fecha,
    required this.leida,
  });

  factory Aviso.fromJson(Map<String, dynamic> json) => Aviso(
        id: json['id'].toString(),
        tipo: TipoAviso.de(json['tipo']?.toString()),
        titulo: json['titulo']?.toString() ?? 'ServiApp',
        mensaje: json['mensaje']?.toString() ?? '',
        servicio: ServicioFalla.de(json['servicio']?.toString()),
        barrio: json['barrio']?.toString(),
        referenciaId: json['referenciaId']?.toString(),
        fecha: fechaIso(json['fecha']),
        leida: json['leida'] == true,
      );

  Aviso leido() => Aviso(
        id: id,
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        servicio: servicio,
        barrio: barrio,
        referenciaId: referenciaId,
        fecha: fecha,
        leida: true,
      );
}

/// Bandeja de avisos en Spring Boot.
class AvisosApi {
  final Dio _dio = ApiClient.dio;

  static const _base = ApiConfig.notificacionesEndpoint;

  /// Últimos avisos y cuántos faltan por leer.
  Future<({List<Aviso> avisos, int noLeidas})> listar() => _leer(_base);

  /// Avisos que aún no se mostraron en este celular (Spring los marca como entregados).
  Future<({List<Aviso> avisos, int noLeidas})> nuevas() => _leer('$_base/nuevas');

  Future<int> marcarLeida(String id) async {
    try {
      final r = await _dio.put('$_base/$id/leida');
      return (r.data['noLeidas'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw errorDeFalla(e);
    }
  }

  Future<void> marcarTodasLeidas() async {
    try {
      await _dio.put('$_base/leidas');
    } on DioException catch (e) {
      throw errorDeFalla(e);
    }
  }

  Future<({List<Aviso> avisos, int noLeidas})> _leer(String ruta) async {
    try {
      final r = await _dio.get(ruta);
      final datos = Map<String, dynamic>.from(r.data as Map);
      return (
        avisos: [
          for (final a in datos['notificaciones'] as List? ?? const [])
            Aviso.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
        noLeidas: (datos['noLeidas'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw errorDeFalla(e);
    }
  }
}
