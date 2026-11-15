import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
/// Si Firebase o el servidor no están listos, todo sigue funcionando con la
/// revisión periódica de NotificacionesService.
class PushService {
  PushService._();

  static bool _firebaseListo = false;
  static String? _token;
  static final List<StreamSubscription<dynamic>> _escuchas = [];

  /// Push llegado con la app abierta.
  static void Function(RemoteMessage mensaje)? alRecibir;

  /// Toque en una notificación push (datos del aviso).
  static void Function(Map<String, dynamic> datos)? alTocar;

  /// En main(), antes de runApp.
  static Future<void> inicializar() async {
    final opciones = DefaultFirebaseOptions.currentPlatform;
    if (opciones == null) return;
    try {
      await Firebase.initializeApp(options: opciones);
      _firebaseListo = true;
    } catch (e) {
      debugPrint('Firebase no se pudo iniciar; avisos sin push: $e');
    }
  }

  /// Tras el login: registra el celular en Spring y empieza a escuchar.
  /// Devuelve true si el servidor enviará los avisos por push.
  static Future<bool> iniciar() async {
    if (!_firebaseListo) return false;
    await _dejarDeEscuchar();
    try {
      final fcm = FirebaseMessaging.instance;
      final permiso = await fcm.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      _escuchas.addAll([
        FirebaseMessaging.onMessage.listen((m) => alRecibir?.call(m)),
        FirebaseMessaging.onMessageOpenedApp.listen(
          (m) => alTocar?.call(m.data),
        ),
        // ignore: deprecated_member_use
        fcm.onTokenRefresh.listen(_registrar),
      ]);

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

  /// Antes de cerrar la sesión en Spring (el borrado necesita la sesión).
  static Future<void> alCerrarSesion() async {
    await _dejarDeEscuchar();
    if (!_firebaseListo) return;
    final token = _token;
    _token = null;
    try {
      if (token != null) {
        await ApiClient.dio.delete(
          ApiConfig.dispositivosEndpoint,
          data: {'token': token},
        );
      }
    } catch (e) {
      debugPrint('No se pudo quitar el celular de los avisos: $e');
    }
    try {
      // El próximo usuario de este celular recibirá un token nuevo
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static Future<bool> _registrar(String token) async {
    try {
      final respuesta = await ApiClient.dio.post(
        ApiConfig.dispositivosEndpoint,
        data: {
          'token': token,
          'plataforma': Platform.isIOS ? 'IOS' : 'ANDROID',
        },
      );
      _token = token;
      final datos = respuesta.data;
      return datos is Map && datos['pushActivo'] == true;
    } catch (e) {
      debugPrint('No se pudo registrar el celular para avisos: $e');
      return false;
    }
  }

  static Future<void> _dejarDeEscuchar() async {
    for (final e in _escuchas) {
      await e.cancel();
    }
    _escuchas.clear();
  }
}
