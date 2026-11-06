import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';

/// Error con un mensaje listo para mostrar al usuario.
class AuthException implements Exception {
  final String mensaje;
  final String? codigo;

  const AuthException(this.mensaje, {this.codigo});

  /// El correo ya tiene cuenta: la app lo manda a iniciar sesión.
  bool get emailRegistrado => codigo == 'EMAIL_REGISTRADO';

  @override
  String toString() => mensaje;
}

/// Inicio de sesión, registro y recuperación de contraseña.
/// Todo lo valida y procesa Spring Boot.
class AuthService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginEndpoint,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      return Map<String, dynamic>.from(response.data);

    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Correo o contraseña incorrectos.');
      }

      if (e.response?.statusCode == 429) {
        throw const AuthException(
          'Demasiados intentos. Intenta nuevamente en unos minutos.',
        );
      }

      if (e.response?.statusCode == 400) {
        throw const AuthException('Debes ingresar tu correo y contraseña.');
      }

      throw const AuthException(
        'No fue posible conectar con ServiApp. Intenta nuevamente.',
      );
    }
  }

  /// Paso 1 del registro: envía el código al correo.
  /// Lanza [AuthException] con [AuthException.emailRegistrado] si ya tiene cuenta.
  Future<void> enviarCodigo(String email) async {
    await _post('${ApiConfig.registroEndpoint}/enviar-codigo', {'email': email});
  }

  /// Paso 2 del registro: valida el código de 6 dígitos.
  Future<void> verificarCodigo({required String email, required String codigo}) async {
    await _post('${ApiConfig.registroEndpoint}/verificar-codigo', {
      'email': email,
      'codigo': codigo,
    });
  }

  /// Paso 3 del registro: crea la cuenta con el correo ya verificado.
  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
  }) async {
    await _post(ApiConfig.registroEndpoint, {
      'nombre': nombre,
      'email': email,
      'password': password,
    });
  }

  /// Envía el enlace para crear una nueva contraseña (el mismo de la web).
  /// Devuelve el mensaje de Spring.
  Future<String> recuperarContrasena(String email) async {
    final datos = await _post(ApiConfig.recuperarContrasenaEndpoint, {'email': email});
    return datos['mensaje'] as String? ??
        'Si el correo está registrado, recibirás un enlace de recuperación.';
  }

  /// Cierra la sesión en Spring y borra la cookie local. Las credenciales
  /// de la huella se conservan para poder volver a entrar con ella.
  Future<void> logout() async {
    try {
      await _dio.post(ApiConfig.logoutEndpoint);
    } on DioException {
      // Sin conexión: igual se cierra la sesión en el celular.
    } finally {
      await ApiClient.cookieJar.deleteAll();
    }
  }

  Future<Map<String, dynamic>> _post(String ruta, Map<String, dynamic> datos) async {
    try {
      final respuesta = await _dio.post(ruta, data: datos);
      return respuesta.data is Map ? Map<String, dynamic>.from(respuesta.data as Map) : {};
    } on DioException catch (e) {
      final cuerpo = e.response?.data;
      if (cuerpo is Map && cuerpo['mensaje'] is String) {
        throw AuthException(cuerpo['mensaje'] as String, codigo: cuerpo['codigo'] as String?);
      }
      throw const AuthException('No fue posible conectar con ServiApp. Intenta nuevamente.');
    }
  }
}
