import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../config/api_config.dart';

class ApiClient {
  // Guarda la cookie de sesión que crea Spring en el login, para que las
  // siguientes peticiones (recibos, etc.) vayan autenticadas.
  static final CookieJar cookieJar = CookieJar();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(CookieManager(cookieJar));

  // Servicio FastAPI de análisis de imágenes. El OCR puede tardar varios
  // segundos, por eso los tiempos de espera son más largos.
  static final Dio fastApi = Dio(
    BaseOptions(
      baseUrl: ApiConfig.fastApiUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Accept': 'application/json',
        if (ApiConfig.fastApiKey.isNotEmpty) 'X-API-Key': ApiConfig.fastApiKey,
      },
    ),
  );
}
