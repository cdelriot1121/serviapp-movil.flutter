import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../fallas/data/models/falla.dart';
import '../models/corte_admin.dart';
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

/// Estadísticas, gestión de fallas y cortes programados del panel de
/// administradores. Spring Boot solo responde si la sesión tiene
/// ROLE_ADMINISTRADOR.
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

  /// Todas las fallas reportadas por los usuarios, las más recientes primero.
  Future<List<Falla>> fallas() async {
    try {
      final respuesta = await _dio.get(ApiConfig.adminFallasEndpoint);
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

  /// Quita una foto inapropiada de una falla. Devuelve la falla actualizada.
  Future<Falla> eliminarFotoFalla(String fallaId, String fotoId) async {
    try {
      final respuesta = await _dio.delete('${ApiConfig.adminFallasEndpoint}/$fallaId/fotos/$fotoId');
      return Falla.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _error(e, 'No fue posible quitar la foto. Intenta nuevamente.');
    }
  }

  // ------------------------------------------------------------- cortes

  /// Vigentes primero (el más próximo arriba) y luego los ya terminados.
  Future<List<CorteAdmin>> cortes() async {
    try {
      final respuesta = await _dio.get(ApiConfig.adminCortesEndpoint);
      return [
        for (final c in respuesta.data as List)
          CorteAdmin.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'No fue posible cargar los cortes. Intenta nuevamente.');
    }
  }

  Future<OpcionesCorte> opcionesCorte() async {
    try {
      final respuesta = await _dio.get('${ApiConfig.adminCortesEndpoint}/opciones');
      return OpcionesCorte.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _error(e, 'No fue posible cargar los barrios. Intenta nuevamente.');
    }
  }

  /// Programa el corte; Spring avisa por push a los usuarios de esos barrios.
  /// Devuelve el corte y a cuántos usuarios les llegó el aviso.
  Future<({CorteAdmin corte, int usuariosNotificados})> programarCorte({
    required ServicioFalla servicio,
    required DateTime fecha,
    required String horaInicio,
    required String horaFinal,
    required String motivo,
    required List<String> barrios,
  }) async {
    try {
      final respuesta = await _dio.post(
        ApiConfig.adminCortesEndpoint,
        data: {
          'servicio': servicio.valor,
          'fecha': '${fecha.year}-${_dos(fecha.month)}-${_dos(fecha.day)}',
          'horaInicio': horaInicio,
          'horaFinal': horaFinal,
          'motivo': motivo,
          'barrios': barrios,
        },
      );
      final datos = Map<String, dynamic>.from(respuesta.data as Map);
      return (
        corte: CorteAdmin.fromJson(Map<String, dynamic>.from(datos['corte'] as Map)),
        usuariosNotificados: (datos['usuariosNotificados'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw _error(e, 'No fue posible programar el corte. Intenta nuevamente.');
    }
  }

  /// Cancela el corte. Devuelve a cuántos usuarios se les avisó que ya no va.
  Future<int> cancelarCorte(String id) async {
    try {
      final respuesta = await _dio.delete('${ApiConfig.adminCortesEndpoint}/$id');
      final datos = respuesta.data;
      return datos is Map ? (datos['usuariosNotificados'] as num?)?.toInt() ?? 0 : 0;
    } on DioException catch (e) {
      throw _error(e, 'No fue posible cancelar el corte. Intenta nuevamente.');
    }
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

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
