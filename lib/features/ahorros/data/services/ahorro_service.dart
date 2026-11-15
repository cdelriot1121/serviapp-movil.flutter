import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/resumen_ahorro.dart';

/// Error con un mensaje listo para mostrar al usuario.
class AhorroException implements Exception {
  final String mensaje;

  const AhorroException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Gestor de ahorros: todo el cálculo lo hace Spring Boot con los recibos
/// escaneados del usuario.
class AhorroService {
  final Dio _spring = ApiClient.dio;

  Future<ResumenAhorro> resumen() async {
    try {
      final respuesta = await _spring.get(ApiConfig.ahorrosEndpoint);
      return ResumenAhorro.fromJson(
        Map<String, dynamic>.from(respuesta.data as Map),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const AhorroException(
          'Tu sesión expiró. Cierra la app e inicia sesión de nuevo.',
        );
      }
      final datos = e.response?.data;
      if (datos is Map && datos['mensaje'] is String) {
        throw AhorroException(datos['mensaje'] as String);
      }
      throw const AhorroException(
        'No fue posible conectar con ServiApp. Intenta nuevamente.',
      );
    }
  }
}
