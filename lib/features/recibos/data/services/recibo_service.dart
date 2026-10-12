import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/recibo.dart';

/// Error con un mensaje listo para mostrar al usuario.
class ReciboException implements Exception {
  final String mensaje;
  final String? codigo;

  /// Id del recibo existente cuando [codigo] es RECIBO_DUPLICADO.
  final String? reciboId;

  const ReciboException(this.mensaje, {this.codigo, this.reciboId});

  bool get esDuplicado => codigo == 'RECIBO_DUPLICADO';
  bool get empresaNoReconocida => codigo == 'EMPRESA_NO_RECONOCIDA';
  bool get sesionExpirada => codigo == 'SESION_EXPIRADA';

  @override
  String toString() => mensaje;
}

class ReciboService {
  final Dio _spring = ApiClient.dio;
  final Dio _fastApi = ApiClient.fastApi;

  /// Envía la foto a FastAPI (OpenCV + OCR) y devuelve los datos extraídos.
  Future<ResultadoAnalisis> analizar(
    String rutaImagen, {
    Empresa? empresa,
    void Function(double progreso)? onProgreso,
  }) async {
    final formulario = FormData.fromMap({
      'imagen': await MultipartFile.fromFile(
        rutaImagen,
        filename: 'recibo.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
      if (empresa != null) 'empresa': empresa.codigo,
    });

    try {
      final respuesta = await _fastApi.post(
        ApiConfig.analizarReciboEndpoint,
        data: formulario,
        onSendProgress: (enviado, total) {
          if (total > 0) onProgreso?.call(enviado / total);
        },
      );
      return ResultadoAnalisis.fromJson(
        Map<String, dynamic>.from(respuesta.data as Map),
      );
    } on DioException catch (e) {
      throw _errorFastApi(e);
    }
  }

  /// Id del recibo si ya está guardado (mismo identificador y mes), o null.
  Future<String?> buscarDuplicado(Recibo recibo) async {
    if (recibo.identificador == null || recibo.periodoFacturado == null) {
      return null;
    }
    try {
      final respuesta = await _spring.get(
        '${ApiConfig.recibosEndpoint}/existe',
        queryParameters: {
          'empresa': recibo.empresa.codigo,
          'identificador': recibo.identificador,
          'periodo': recibo.periodoFacturado,
        },
      );
      final datos = Map<String, dynamic>.from(respuesta.data as Map);
      return datos['existe'] == true ? datos['reciboId'] as String? : null;
    } on DioException {
      // Si no se puede verificar ahora, el guardado lo volverá a validar
      return null;
    }
  }

  /// Guarda en Spring Boot (MongoDB) el recibo confirmado por el usuario.
  Future<Recibo> guardar(
    Recibo recibo, {
    required Map<String, double> confianza,
    required List<String> camposCorregidos,
    required String versionExtractor,
  }) async {
    try {
      final respuesta = await _spring.post(
        ApiConfig.recibosEndpoint,
        data: {
          ...recibo.toJson(),
          'confianzaOcr': confianza,
          'camposCorregidos': camposCorregidos,
          'versionExtractor': versionExtractor,
        },
      );
      return Recibo.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _errorSpring(e);
    }
  }

  /// Archivero del usuario. [tipoServicio]: ENERGIA, AGUA, GAS o null (todos).
  Future<List<Recibo>> listar({String? tipoServicio}) async {
    try {
      final respuesta = await _spring.get(
        ApiConfig.recibosEndpoint,
        queryParameters: {'tipoServicio': ?tipoServicio},
      );
      return [
        for (final item in respuesta.data as List)
          Recibo.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on DioException catch (e) {
      throw _errorSpring(e);
    }
  }

  Future<Recibo> obtener(String id) async {
    try {
      final respuesta = await _spring.get('${ApiConfig.recibosEndpoint}/$id');
      return Recibo.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _errorSpring(e);
    }
  }

  Future<void> eliminar(String id) async {
    try {
      await _spring.delete('${ApiConfig.recibosEndpoint}/$id');
    } on DioException catch (e) {
      throw _errorSpring(e);
    }
  }

  // ----------------------------------------------------------------- errores

  ReciboException _errorFastApi(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const ReciboException(
        'No fue posible conectar con el servicio de análisis. '
        'Verifica que el celular y el servidor estén en la misma red.',
      );
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return const ReciboException(
        'El análisis tardó demasiado. Intenta de nuevo con una foto más clara.',
      );
    }
    final detalle = _detalle(e.response?.data);
    return ReciboException(
      detalle?['mensaje'] as String? ??
          'No pudimos analizar el recibo. Intenta de nuevo.',
      codigo: detalle?['codigo'] as String?,
    );
  }

  ReciboException _errorSpring(DioException e) {
    final status = e.response?.statusCode;
    final datos = e.response?.data is Map
        ? Map<String, dynamic>.from(e.response!.data as Map)
        : null;

    if (status == 401 || status == 403) {
      return const ReciboException(
        'Tu sesión expiró. Cierra la app e inicia sesión de nuevo.',
        codigo: 'SESION_EXPIRADA',
      );
    }
    if (status == 409) {
      return ReciboException(
        datos?['mensaje'] as String? ??
            'Este recibo ya está registrado en tu historial.',
        codigo: 'RECIBO_DUPLICADO',
        reciboId: datos?['reciboId'] as String?,
      );
    }
    if (datos?['mensaje'] is String) {
      return ReciboException(datos!['mensaje'] as String,
          codigo: datos['codigo'] as String?);
    }
    return const ReciboException(
      'No fue posible conectar con ServiApp. Intenta nuevamente.',
    );
  }

  /// FastAPI responde los errores como {"detail": {"codigo", "mensaje"}}.
  Map<String, dynamic>? _detalle(dynamic datos) {
    if (datos is Map && datos['detail'] is Map) {
      return Map<String, dynamic>.from(datos['detail'] as Map);
    }
    return null;
  }
}
