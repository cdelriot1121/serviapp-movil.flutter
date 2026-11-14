import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../predio/data/predio_service.dart';
import '../../recibos/data/models/recibo.dart';

/// Servicio del hogar (agua, energía o gas) que el usuario ha escaneado, con
/// los datos de su último recibo. Solo aparecen los servicios con recibos.
class ServicioHogar {
  /// ENERGIA, AGUA o GAS.
  final String tipoServicio;

  /// Código de la empresa del recibo (AFINIA, AGUAS_DE_CARTAGENA o SURTIGAS).
  final String empresa;

  /// NIC, póliza o contrato del último recibo.
  final String identificador;
  final int habitantes;
  final int recibos;
  final String? ultimoPeriodo;

  const ServicioHogar({
    required this.tipoServicio,
    required this.empresa,
    required this.identificador,
    required this.habitantes,
    required this.recibos,
    required this.ultimoPeriodo,
  });

  factory ServicioHogar.fromJson(Map<String, dynamic> json) {
    return ServicioHogar(
      tipoServicio: json['tipoServicio']?.toString() ?? '',
      empresa: json['empresa']?.toString() ?? '',
      identificador: json['identificador']?.toString() ?? '',
      habitantes: (json['habitantes'] as num?)?.toInt() ?? 0,
      recibos: (json['recibos'] as num?)?.toInt() ?? 0,
      ultimoPeriodo: json['ultimoPeriodo']?.toString(),
    );
  }

  ServicioHogar conHabitantes(int nuevos) => ServicioHogar(
    tipoServicio: tipoServicio,
    empresa: empresa,
    identificador: identificador,
    habitantes: nuevos,
    recibos: recibos,
    ultimoPeriodo: ultimoPeriodo,
  );

  /// Nombre, icono y color de la empresa en la app.
  Empresa? get datosEmpresa => Empresa.desdeCodigo(empresa);
}

/// Lo que el usuario ha hecho en ServiApp.
class ActividadPerfil {
  final int recibos;
  final int pagados;
  final int analisis;

  const ActividadPerfil({
    required this.recibos,
    required this.pagados,
    required this.analisis,
  });

  factory ActividadPerfil.fromJson(Map<String, dynamic> json) {
    int numero(String clave) => (json[clave] as num?)?.toInt() ?? 0;
    return ActividadPerfil(
      recibos: numero('recibos'),
      pagados: numero('pagados'),
      analisis: numero('analisis'),
    );
  }
}

/// Datos del usuario tal como están en MongoDB.
class Perfil {
  final String nombre;
  final String email;
  final DateTime? miembroDesde;
  final Predio? predio;
  final List<ServicioHogar> servicios;
  final ActividadPerfil actividad;

  const Perfil({
    required this.nombre,
    required this.email,
    required this.miembroDesde,
    required this.predio,
    required this.servicios,
    required this.actividad,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    final predio = json['predio'];
    final actividad = json['actividad'];
    return Perfil(
      nombre: json['nombre']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      miembroDesde: DateTime.tryParse(json['miembroDesde']?.toString() ?? ''),
      predio: predio is Map
          ? Predio.fromJson(Map<String, dynamic>.from(predio))
          : null,
      servicios: [
        for (final s in (json['servicios'] as List? ?? const []))
          ServicioHogar.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      actividad: ActividadPerfil.fromJson(
        actividad is Map ? Map<String, dynamic>.from(actividad) : const {},
      ),
    );
  }
}

class PerfilException implements Exception {
  final String mensaje;

  const PerfilException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Perfil del usuario: lo mismo que "Mi perfil" de la web.
class PerfilService {
  final Dio _spring = ApiClient.dio;

  Future<Perfil> obtener() async {
    try {
      final respuesta = await _spring.get(ApiConfig.perfilEndpoint);
      return Perfil.fromJson(Map<String, dynamic>.from(respuesta.data as Map));
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  /// Devuelve el nombre tal como quedó guardado.
  Future<String> actualizarNombre(String nombre) async {
    try {
      final respuesta = await _spring.put(
        '${ApiConfig.perfilEndpoint}/nombre',
        data: {'nombre': nombre},
      );
      return (respuesta.data as Map)['nombre'].toString();
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  }) async {
    try {
      await _spring.put(
        '${ApiConfig.perfilEndpoint}/contrasena',
        data: {'actual': actual, 'nueva': nueva},
      );
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  /// [tipoServicio]: ENERGIA, AGUA o GAS.
  Future<void> actualizarHabitantes(String tipoServicio, int habitantes) async {
    try {
      await _spring.put(
        '${ApiConfig.perfilEndpoint}/servicios/$tipoServicio/habitantes',
        data: {'habitantes': habitantes},
      );
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  PerfilException _error(DioException e) {
    final status = e.response?.statusCode;
    final datos = e.response?.data;
    if (status == 401 || status == 403) {
      return const PerfilException('Tu sesión expiró. Inicia sesión de nuevo.');
    }
    if (datos is Map && datos['mensaje'] is String) {
      return PerfilException(datos['mensaje'] as String);
    }
    return const PerfilException(
      'No fue posible conectar con ServiApp. Intenta nuevamente.',
    );
  }
}
