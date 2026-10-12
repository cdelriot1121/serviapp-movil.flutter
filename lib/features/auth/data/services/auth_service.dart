
import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';

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
        throw Exception('Correo o contraseña incorrectos.');
      }

      if (e.response?.statusCode == 429) {
        throw Exception(
          'Demasiados intentos. Intenta nuevamente en unos minutos.',
        );
      }

      if (e.response?.statusCode == 400) {
        throw Exception('Debes ingresar tu correo y contraseña.');
      }

      throw Exception(
        'No fue posible conectar con ServiApp. Intenta nuevamente.',
      );
    }
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
}
