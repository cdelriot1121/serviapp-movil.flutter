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

  // Permite apuntar a un Spring Boot local:
  // flutter run --dart-define=SPRING_URL=http://192.168.1.55:8080
  static const String _springUrl = String.fromEnvironment('SPRING_URL');

  static const String baseUrl = _springUrl != ''
      ? _springUrl
      : (isProduction ? productionUrl : developmentUrl);

  // Servicio FastAPI de análisis de recibos (OpenCV + OCR).
  // Por defecto el PC de desarrollo en la red Wi-Fi local; se cambia con:
  // flutter run --dart-define=FASTAPI_URL=http://IP_DEL_PC:8000
  static const String fastApiUrl = String.fromEnvironment(
    'FASTAPI_URL',
    defaultValue: 'http://192.168.1.55:8000',
  );

  // Solo si FastAPI se configuró con SERVIAPP_API_KEY
  static const String fastApiKey = String.fromEnvironment('FASTAPI_KEY');

  // Endpoints de autenticación
  static const String loginEndpoint = '/api/mobile/auth/login';
  static const String sessionEndpoint = '/api/mobile/auth/me';

  // Endpoints de recibos
  static const String recibosEndpoint = '/api/mobile/recibos';
  static const String analizarReciboEndpoint = '/recibos/analizar';
}
