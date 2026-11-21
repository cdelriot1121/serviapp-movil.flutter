import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/falla.dart';

/// Error con un mensaje listo para mostrar al usuario.
class FallaException implements Exception {
  final String mensaje;
  final String? codigo;

  const FallaException(this.mensaje, {this.codigo});

  bool get sesionExpirada => codigo == 'SESION_EXPIRADA';
  bool get repetida => codigo == 'FALLA_REPETIDA';

  @override
  String toString() => mensaje;
}

/// Reporte de fallas y filtro por barrio (igual que en la web).
class FallasService {
  final Dio _dio = ApiClient.dio;

  static const _base = ApiConfig.fallasEndpoint;

  Future<OpcionesFalla> opciones() => _pedir(() async {
        final r = await _dio.get('$_base/opciones');
        return OpcionesFalla.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  /// Historial de fallas que reportó el usuario.
  Future<List<Falla>> misFallas() => _pedir(() async {
        final r = await _dio.get(_base);
        return [
          for (final f in r.data as List) Falla.fromJson(Map<String, dynamic>.from(f as Map)),
        ];
      });

  /// Fallas activas y cortes programados del barrio del usuario.
  Future<ResumenBarrio> delBarrio() => _pedir(() async {
        final r = await _dio.get('$_base/barrio');
        return ResumenBarrio.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  /// Devuelve la falla creada y cuántos vecinos recibieron el aviso.
  /// [fotos] son JPEG ya comprimidos (ver FotosReporte).
  Future<({Falla falla, int vecinos})> reportar({
    required ServicioFalla servicio,
    required String barrio,
    required String horaInicio,
    String? comentarios,
    List<Uint8List> fotos = const [],
  }) =>
      _pedir(() async {
        final campos = {
          'servicio': servicio.valor,
          'barrio': barrio,
          'horaInicio': horaInicio,
          'comentarios': comentarios,
        };
        final r = fotos.isEmpty
            ? await _dio.post(_base, data: campos)
            : await _dio.post(
                _base,
                data: FormData.fromMap({
                  ...campos,
                  'fotos': [
                    for (var i = 0; i < fotos.length; i++)
                      MultipartFile.fromBytes(
                        fotos[i],
                        filename: 'foto_${i + 1}.jpg',
                        contentType: DioMediaType('image', 'jpeg'),
                      ),
                  ],
                }),
                // Subir fotos con datos móviles puede tardar más que una petición normal
                options: Options(sendTimeout: const Duration(seconds: 90), receiveTimeout: const Duration(seconds: 60)),
              );
        final datos = Map<String, dynamic>.from(r.data as Map);
        return (
          falla: Falla.fromJson(Map<String, dynamic>.from(datos['falla'] as Map)),
          vecinos: (datos['vecinosNotificados'] as num?)?.toInt() ?? 0,
        );
      });

  /// "A mí también me pasa". Activa o quita la confirmación.
  Future<({bool confirmada, int confirmaciones})> confirmar(String id) => _pedir(() async {
        final r = await _dio.post('$_base/$id/confirmar');
        final datos = Map<String, dynamic>.from(r.data as Map);
        return (
          confirmada: datos['confirmada'] == true,
          confirmaciones: (datos['confirmaciones'] as num?)?.toInt() ?? 0,
        );
      });

  Future<Falla> marcarSolucionada(String id) => _pedir(() async {
        final r = await _dio.put('$_base/$id/solucionada');
        return Falla.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> eliminar(String id) => _pedir(() => _dio.delete('$_base/$id'));

  /// Quita una foto de un reporte propio. Devuelve la falla actualizada.
  Future<Falla> eliminarFoto(String fallaId, String fotoId) => _pedir(() async {
        final r = await _dio.delete('$_base/$fallaId/fotos/$fotoId');
        return Falla.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<T> _pedir<T>(Future<T> Function() peticion) async {
    try {
      return await peticion();
    } on DioException catch (e) {
      throw errorDeFalla(e);
    }
  }
}

FallaException errorDeFalla(DioException e) {
  final status = e.response?.statusCode;
  final datos = e.response?.data;
  if (status == 401 || status == 403) {
    return const FallaException('Tu sesión expiró. Inicia sesión de nuevo.', codigo: 'SESION_EXPIRADA');
  }
  if (datos is Map && datos['mensaje'] is String) {
    return FallaException(datos['mensaje'] as String, codigo: datos['codigo']?.toString());
  }
  return const FallaException('No fue posible conectar con ServiApp. Intenta nuevamente.');
}
