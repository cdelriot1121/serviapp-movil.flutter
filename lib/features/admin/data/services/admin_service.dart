import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/estadisticas.dart';

/// Error con un mensaje listo para mostrar al administrador.
class AdminException implements Exception {
  final String mensaje;
  final String? codigo;

  const AdminException(this.mensaje, {this.codigo});

  /// Sin sesión (401) o la cuenta ya no es administradora (403).
  bool get sesionExpirada => codigo == 'SESION_EXPIRADA';

  @override
  String toString() => mensaje;
}

/// Estadísticas del panel de administradores. Spring Boot solo responde si
/// la sesión tiene ROLE_ADMINISTRADOR.
class AdminService {
  final Dio _dio = ApiClient.dio;

  Future<Estadisticas> estadisticas() async {
    try {
      final respuesta = await _dio.get(ApiConfig.adminEstadisticasEndpoint);
      return Estadisticas.fromJson(
        Map<String, dynamic>.from(respuesta.data as Map),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const AdminException(
          'Tu sesión de administrador expiró. Inicia sesión de nuevo.',
          codigo: 'SESION_EXPIRADA',
        );
      }
      throw const AdminException(
        'No fue posible conectar con ServiApp. Reintentando…',
      );
    }
  }
}
