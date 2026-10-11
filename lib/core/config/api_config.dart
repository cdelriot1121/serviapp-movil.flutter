
class ApiConfig {
  // Backend de producción
  static const String productionUrl =
      'https://serviapp.up.railway.app';

  // Backend de desarrollo
  static const String developmentUrl =
      'https://springclassroomproject-serviapp-development.up.railway.app';

  // Selecciona el entorno al ejecutar Flutter
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  static const String baseUrl =
      isProduction ? productionUrl : developmentUrl;

  // Endpoints de autenticación
  static const String loginEndpoint = '/api/mobile/auth/login';
  static const String sessionEndpoint = '/api/mobile/auth/me';
}
