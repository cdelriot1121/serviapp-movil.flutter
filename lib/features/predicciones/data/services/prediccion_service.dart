import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../recibos/data/models/recibo.dart';
import '../models/prediccion.dart';

/// Error con un mensaje listo para mostrar al usuario.
class PrediccionException implements Exception {
  final String mensaje;

  const PrediccionException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Predicción del consumo del próximo mes. FastAPI pide a Spring los últimos
/// 5 meses y los datos del hogar, y ejecuta la red neuronal LSTM. El
/// historial de predicciones se guarda en Spring.
class PrediccionService {
  final Dio _fastApi = ApiClient.fastApi;
  final Dio _spring = ApiClient.dio;

  /// Guarda la predicción y la devuelve con la categoría del estrato.
  Future<Prediccion> guardar(Prediccion prediccion) async {
    try {
      final respuesta = await _spring.post(
        ApiConfig.historialPrediccionesEndpoint,
        data: prediccion.toJson(),
      );
      return Prediccion.desdeSpring(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _errorSpring(e);
    } on FormatException {
      throw const PrediccionException('No pudimos guardar la predicción en tu historial.');
    }
  }

  Future<HistorialPredicciones> historial() async {
    try {
      final respuesta = await _spring.get(ApiConfig.historialPrediccionesEndpoint);
      return HistorialPredicciones.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _errorSpring(e);
    }
  }

  PrediccionException _errorSpring(DioException e) {
    final status = e.response?.statusCode;
    final datos = e.response?.data;
    if (status == 401 || status == 403) {
      return const PrediccionException('Tu sesión expiró. Cierra la app e inicia sesión de nuevo.');
    }
    if (datos is Map && datos['mensaje'] is String) {
      return PrediccionException(datos['mensaje'] as String);
    }
    return const PrediccionException('No fue posible conectar con ServiApp. Intenta nuevamente.');
  }

  Future<Prediccion> predecir({
    required Empresa empresa,
    required String usuarioId,
  }) async {
    try {
      final respuesta = await _fastApi.post(
        '${ApiConfig.prediccionesEndpoint}/${empresa.tipoServicio.toLowerCase()}',
        data: {'usuarioId': usuarioId},
      );
      return Prediccion.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _error(e);
    } on FormatException {
      throw const PrediccionException(
        'La predicción llegó incompleta. Intenta de nuevo en un momento.',
      );
    }
  }

  PrediccionException _error(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const PrediccionException(
        'No fue posible conectar con el servicio de predicciones. '
        'Revisa tu conexión e intenta de nuevo.',
      );
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return const PrediccionException(
        'La predicción tardó demasiado. Intenta de nuevo en un momento.',
      );
    }

    // Los errores de datos (404, 422) vienen de Spring con un mensaje claro;
    // los de configuración (401, 503) no le sirven al usuario.
    final status = e.response?.statusCode;
    final mensaje = _mensaje(e.response?.data);
    if ((status == 404 || status == 422) && mensaje != null) {
      return PrediccionException(mensaje);
    }
    return const PrediccionException(
      'El servicio de predicciones no está disponible en este momento. '
      'Intenta más tarde.',
    );
  }

  /// FastAPI responde {"detail": ...}. Si el error viene de Spring, detail
  /// es el texto de su JSON {"codigo", "mensaje"}.
  String? _mensaje(dynamic datos) {
    dynamic detalle = datos is Map ? datos['detail'] : null;
    if (detalle is String) {
      try {
        detalle = jsonDecode(detalle);
      } on FormatException {
        return detalle as String;
      }
    }
    if (detalle is Map && detalle['mensaje'] is String) return detalle['mensaje'] as String;
    return detalle is String ? detalle : null;
  }
}
