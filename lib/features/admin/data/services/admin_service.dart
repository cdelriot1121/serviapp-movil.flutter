import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../fallas/data/models/falla.dart';
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

/// Estadísticas y gestión de fallas del panel de administradores. Spring Boot
/// solo responde si la sesión tiene ROLE_ADMINISTRADOR.
class AdminService {
  final Dio _dio = ApiClient.dio;

  Future<Estadisticas> estadisticas() async {
    try {
      final respuesta = await _dio.get(ApiConfig.adminEstadisticasEndpoint);
      return Estadisticas.fromJson(
        Map<String, dynamic>.from(respuesta.data as Map),
      );
    } on DioException catch (e) {
      throw _error(e, 'No fue posible conectar con ServiApp. Reintentando…');
    }
  }

  /// Fallas reportadas por los usuarios; [estado] null = todas.
  Future<List<Falla>> fallas({EstadoFalla? estado}) async {
    try {
      final respuesta = await _dio.get(
        ApiConfig.adminFallasEndpoint,
        queryParameters: {if (estado != null) 'estado': estado.valor},
      );
      return [
        for (final f in respuesta.data as List)
          Falla.fromJson(Map<String, dynamic>.from(f as Map)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'No fue posible cargar las fallas. Intenta nuevamente.');
    }
  }

  /// Cambia el estado de una falla; Spring avisa a quien la reportó.
  Future<void> cambiarEstadoFalla(String id, EstadoFalla estado) async {
    try {
      await _dio.put(
        '${ApiConfig.adminFallasEndpoint}/$id/estado',
        data: {'estado': estado.valor},
      );
    } on DioException catch (e) {
      throw _error(e, 'No fue posible actualizar la falla. Intenta nuevamente.');
    }
  }

  AdminException _error(DioException e, String sinConexion) {
    final status = e.response?.statusCode;
    final datos = e.response?.data;
    if (status == 401 || status == 403) {
      return const AdminException(
        'Tu sesión de administrador expiró. Inicia sesión de nuevo.',
        codigo: 'SESION_EXPIRADA',
      );
    }
    if (datos is Map && datos['mensaje'] is String) {
      return AdminException(datos['mensaje'] as String, codigo: datos['codigo']?.toString());
    }
    return AdminException(sinConexion);
  }
}
