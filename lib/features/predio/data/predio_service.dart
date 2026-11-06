import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';

/// Opciones del formulario del predio, tal como las envía Spring Boot.
class OpcionesPredio {
  final List<String> barrios;
  final List<int> estratos;
  final List<String> tiposPredio;

  const OpcionesPredio({
    required this.barrios,
    required this.estratos,
    required this.tiposPredio,
  });

  factory OpcionesPredio.fromJson(Map<String, dynamic> json) {
    return OpcionesPredio(
      barrios: [for (final b in json['barrios'] as List) b.toString()],
      estratos: [for (final e in json['estratos'] as List) (e as num).toInt()],
      tiposPredio: [for (final t in json['tiposPredio'] as List) t.toString()],
    );
  }
}

class PredioException implements Exception {
  final String mensaje;

  const PredioException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Registro obligatorio del predio (igual que en la web).
class PredioService {
  final Dio _spring = ApiClient.dio;

  Future<OpcionesPredio> opciones() async {
    try {
      final respuesta = await _spring.get('${ApiConfig.predioEndpoint}/opciones');
      return OpcionesPredio.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  Future<void> registrar({
    required String direccion,
    required String barrio,
    required int estrato,
    required String tipoPredio,
  }) async {
    try {
      await _spring.post(ApiConfig.predioEndpoint, data: {
        'direccion': direccion,
        'barrio': barrio,
        'estrato': estrato,
        'tipoPredio': tipoPredio,
      });
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  PredioException _error(DioException e) {
    final status = e.response?.statusCode;
    final datos = e.response?.data;
    if (status == 401 || status == 403) {
      return const PredioException('Tu sesión expiró. Inicia sesión de nuevo.');
    }
    if (datos is Map && datos['mensaje'] is String) {
      return PredioException(datos['mensaje'] as String);
    }
    return const PredioException('No fue posible conectar con ServiApp. Intenta nuevamente.');
  }
}
