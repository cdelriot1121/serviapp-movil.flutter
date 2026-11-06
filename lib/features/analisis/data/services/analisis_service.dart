import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/analisis_consumo.dart';

/// Error con un mensaje listo para mostrar al usuario.
class AnalisisException implements Exception {
  final String mensaje;
  final String? codigo;

  /// Servicio (AGUA, ENERGIA o GAS) cuando [codigo] es HABITANTES_REQUERIDOS.
  final String? tipoServicio;

  const AnalisisException(this.mensaje, {this.codigo, this.tipoServicio});

  bool get habitantesRequeridos => codigo == 'HABITANTES_REQUERIDOS';
  bool get noEncontrado => codigo == 'NOT_FOUND';
  bool get sesionExpirada => codigo == 'SESION_EXPIRADA';

  @override
  String toString() => mensaje;
}

/// Análisis de consumo: todo el cálculo lo hace Spring Boot.
class AnalisisService {
  final Dio _spring = ApiClient.dio;

  /// Analiza el consumo del recibo guardado y lo agrega al historial.
  /// [habitantes] solo se envía cuando Spring responde HABITANTES_REQUERIDOS.
  Future<AnalisisConsumo> analizarRecibo(String reciboId, {int? habitantes}) async {
    try {
      final respuesta = await _spring.post(
        '${ApiConfig.analisisEndpoint}/recibo/$reciboId',
        data: {'habitantes': ?habitantes},
      );
      return AnalisisConsumo.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  /// Último análisis del recibo, o null si aún no se ha analizado.
  Future<AnalisisConsumo?> obtenerPorRecibo(String reciboId) async {
    try {
      final respuesta = await _spring.get('${ApiConfig.analisisEndpoint}/recibo/$reciboId');
      return AnalisisConsumo.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      final error = _error(e);
      if (error.noEncontrado) return null;
      throw error;
    }
  }

  /// Historial de análisis, del mes más reciente al más antiguo.
  Future<List<AnalisisConsumo>> historial() async {
    try {
      final respuesta = await _spring.get(ApiConfig.analisisEndpoint);
      return [
        for (final item in respuesta.data as List)
          AnalisisConsumo.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  Future<void> eliminar(String id) async {
    try {
      await _spring.delete('${ApiConfig.analisisEndpoint}/$id');
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  AnalisisException _error(DioException e) {
    final status = e.response?.statusCode;
    final datos = e.response?.data is Map
        ? Map<String, dynamic>.from(e.response!.data as Map)
        : null;

    if (status == 401 || status == 403) {
      return const AnalisisException(
        'Tu sesión expiró. Cierra la app e inicia sesión de nuevo.',
        codigo: 'SESION_EXPIRADA',
      );
    }
    if (datos?['mensaje'] is String) {
      return AnalisisException(
        datos!['mensaje'] as String,
        codigo: datos['codigo'] as String?,
        tipoServicio: datos['tipoServicio'] as String?,
      );
    }
    if (status == 404) {
      return const AnalisisException('Análisis no encontrado', codigo: 'NOT_FOUND');
    }
    return const AnalisisException(
      'No fue posible conectar con ServiApp. Intenta nuevamente.',
    );
  }
}
