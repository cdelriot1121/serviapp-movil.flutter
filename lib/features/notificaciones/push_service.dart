import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../firebase_options.dart';

/// Avisos push con Firebase Cloud Messaging: llegan aunque la app esté cerrada.
///
/// - App cerrada o en segundo plano: Android muestra la notificación solo.
/// - App abierta: llega a [alRecibir] y la app la muestra ella misma.
/// - Al tocarla: llega a [alTocar] con los mismos datos que las notificaciones
///   locales de avisos ({tipo, avisoId, tipoAviso}).
///
/// Desde el primer inicio de sesión, el celular recibe los avisos de ese
/// usuario siempre, aunque cierre sesión: el registro en Spring solo cambia
/// de dueño cuando otra persona inicia sesión en el celular.
///
/// Si Firebase o el servidor no están listos, todo sigue funcionando con la
/// revisión periódica de NotificacionesService.
class PushService {
  PushService._();

  // Último token registrado en Spring (sirve para renovarlo sin sesión)
  static const _claveToken = 'push_token_registrado';

  static final _prefs = SharedPreferencesAsync();
  static bool _firebaseListo = false;
  static bool _conSesion = false;

  /// Push llegado con la app abierta.
  static void Function(RemoteMessage mensaje)? alRecibir;

  /// Toque en una notificación push (datos del aviso).
  static void Function(Map<String, dynamic> datos)? alTocar;

  /// En main(), antes de runApp. Escucha los push desde que abre la app,
  /// con o sin sesión.
  static Future<void> inicializar() async {
    final opciones = DefaultFirebaseOptions.currentPlatform;
    if (opciones == null) return;
    try {
      await Firebase.initializeApp(options: opciones);
      _firebaseListo = true;
    } catch (e) {
      debugPrint('Firebase no se pudo iniciar; avisos sin push: $e');
      return;
    }

    FirebaseMessaging.onMessage.listen((m) => alRecibir?.call(m));
    FirebaseMessaging.onMessageOpenedApp.listen((m) => alTocar?.call(m.data));
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen(_tokenCambiado);

    // Firebase pudo cambiar el token mientras la app estaba cerrada
    unawaited(_revisarToken());
  }

  /// Tras el login: registra el celular para este usuario.
  /// Devuelve true si el servidor enviará los avisos por push.
  static Future<bool> iniciar() async {
    if (!_firebaseListo) return false;
    _conSesion = true;
    try {
      final fcm = FirebaseMessaging.instance;
      final permiso = await fcm.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      // La app estaba cerrada y se abrió tocando un push
      final inicial = await fcm.getInitialMessage();
      if (inicial != null) alTocar?.call(inicial.data);

      // Se usa el token clásico de FCM a propósito: el nuevo register()
      // entrega un ID de instalación que el SDK de Spring aún no sabe usar.
      // ignore: deprecated_member_use
      final token = await fcm.getToken();
      return token != null && await _registrar(token);
    } catch (e) {
      debugPrint('No se pudo activar el push: $e');
      return false;
    }
  }

  /// Al cerrar sesión el celular sigue registrado: los avisos siguen llegando.
  static void alCerrarSesion() => _conSesion = false;

  static Future<bool> _registrar(String token) async {
    try {
      final respuesta = await ApiClient.dio.post(
        ApiConfig.dispositivosEndpoint,
        data: {'token': token, 'plataforma': _plataforma},
      );
      await _prefs.setString(_claveToken, token);
      final datos = respuesta.data;
      return datos is Map && datos['pushActivo'] == true;
    } catch (e) {
      debugPrint('No se pudo registrar el celular para avisos: $e');
      return false;
    }
  }

  static Future<void> _tokenCambiado(String token) async {
    if (_conSesion) {
      await _registrar(token);
    } else {
      await _renovar(token);
    }
  }

  static Future<void> _revisarToken() async {
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _renovar(token);
    } catch (e) {
      debugPrint('No se pudo revisar el token de avisos: $e');
    }
  }

  /// Sin sesión: el token anterior le prueba a Spring que es el mismo celular.
  static Future<void> _renovar(String token) async {
    try {
      final anterior = await _prefs.getString(_claveToken);
      // Nunca ha iniciado sesión aquí, o el token no cambió
      if (anterior == null || anterior == token) return;
      await ApiClient.dio.post(
        '${ApiConfig.dispositivosEndpoint}/renovar',
        data: {
          'tokenAnterior': anterior,
          'token': token,
          'plataforma': _plataforma,
        },
      );
      await _prefs.setString(_claveToken, token);
    } on DioException catch (e) {
      // Spring ya no tiene el celular: se registra de nuevo al iniciar sesión
      if (e.response?.statusCode == 404) await _prefs.remove(_claveToken);
      debugPrint('No se pudo renovar el celular para avisos: $e');
    } catch (e) {
      debugPrint('No se pudo renovar el celular para avisos: $e');
    }
  }

  static String get _plataforma => Platform.isIOS ? 'IOS' : 'ANDROID';
}
