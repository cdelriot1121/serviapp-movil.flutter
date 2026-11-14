import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/theme/app_colors.dart';
import '../fallas/data/services/fallas_service.dart';
import 'data/aviso.dart';
import 'push_service.dart';

/// Toque en una notificación de aviso: qué abrir en la app.
class ToqueAviso {
  final String avisoId;
  final TipoAviso tipo;

  const ToqueAviso(this.avisoId, this.tipo);
}

/// Avisos de fallas y cortes del barrio como notificaciones del celular.
///
/// Spring guarda un aviso para cada vecino del barrio cuando alguien reporta
/// una falla (y cuando cambia el estado de un reporte o se programa un corte).
/// Spring los envía al momento como push (PushService), aunque la app esté
/// cerrada. Además la app pregunta por avisos nuevos al volver a primer plano
/// (y cada [_intervalo] si el push no está activo) y los muestra con
/// flutter_local_notifications, por si alguno no llegó por push.
class NotificacionesService {
  NotificacionesService._();

  static const tipoPayload = 'aviso';
  static const _intervalo = Duration(seconds: 45);

  // Máximo de notificaciones sueltas por revisión; el resto va en un resumen
  static const _maxSueltas = 3;

  // Los recordatorios de pago usan IDs positivos; los avisos, negativos
  static const _idResumen = -1;

  /// Avisos sin leer, para la campana del inicio.
  static final ValueNotifier<int> noLeidas = ValueNotifier(0);

  /// Cambia cuando llegan avisos nuevos, para que las pantallas de fallas se recarguen.
  static final ValueNotifier<int> cambios = ValueNotifier(0);

  /// Último toque en una notificación de aviso; el inicio lo consume y lo pone en null.
  static final ValueNotifier<ToqueAviso?> toque = ValueNotifier(null);

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _api = AvisosApi();

  static Timer? _timer;
  static _Ciclo? _ciclo;
  static bool _revisando = false;

  static const _canal = AndroidNotificationChannel(
    'avisos_barrio',
    'Fallas y cortes en tu barrio',
    description:
        'Fallas que reportan tus vecinos, el estado de tus reportes y los cortes programados.',
    importance: Importance.high,
  );

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'avisos_barrio',
      'Fallas y cortes en tu barrio',
      channelDescription:
          'Fallas que reportan tus vecinos, el estado de tus reportes y los cortes programados.',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.orange,
      styleInformation: DefaultStyleInformation(true, true),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'avisos_barrio'),
  );

  // ------------------------------------------------------------- ciclo de vida

  /// Tras el login de un usuario (no administrador).
  static Future<void> iniciar() async {
    detener();
    _ciclo = _Ciclo();
    WidgetsBinding.instance.addObserver(_ciclo!);
    _timer = Timer.periodic(_intervalo, (_) => revisar());
    await _crearCanal();
    await _toqueAlAbrirLaApp();
    await revisar();

    // Con push activo los avisos llegan solos: ya no hace falta preguntar
    // cada 45 s. Se sigue revisando al abrir la app, por si alguno no llegó.
    PushService.alRecibir = _alRecibirPush;
    PushService.alTocar = alTocar;
    if (await PushService.iniciar() && _ciclo != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static void detener() {
    _timer?.cancel();
    _timer = null;
    if (_ciclo != null) WidgetsBinding.instance.removeObserver(_ciclo!);
    _ciclo = null;
  }

  /// Antes de cerrar la sesión en Spring: este celular deja de recibir push.
  static Future<void> alCerrarSesion() async {
    detener();
    noLeidas.value = 0;
    toque.value = null;
    PushService.alRecibir = null;
    PushService.alTocar = null;
    await PushService.alCerrarSesion();
  }

  // El canal debe existir antes del primer push, que Android muestra solo
  static Future<void> _crearCanal() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_canal);
    } catch (e) {
      debugPrint('No se pudo crear el canal de avisos: $e');
    }
  }

  // Con la app abierta Android no muestra el push: se muestra como los demás avisos
  static Future<void> _alRecibirPush(RemoteMessage mensaje) async {
    final datos = mensaje.data;
    if (datos['tipo'] != tipoPayload) return;
    final avisoId = datos['avisoId']?.toString() ?? '';
    try {
      await _plugin.show(
        id: _idDe(avisoId),
        title: mensaje.notification?.title ?? 'Nuevo aviso en tu barrio',
        body: mensaje.notification?.body ?? '',
        notificationDetails: _detalles,
        payload: jsonEncode({
          'tipo': tipoPayload,
          'avisoId': avisoId,
          'tipoAviso': datos['tipoAviso'],
        }),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el aviso: $e');
    }
    noLeidas.value++;
    cambios.value++;
  }

  // ------------------------------------------------------------- avisos

  /// Trae los avisos nuevos y los muestra como notificaciones.
  static Future<void> revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      final r = await _api.nuevas();
      noLeidas.value = r.noLeidas;
      if (r.avisos.isEmpty) return;

      await _mostrar(r.avisos);
      cambios.value++;
    } on FallaException catch (e) {
      // Sin sesión no tiene sentido seguir preguntando
      if (e.sesionExpirada) detener();
    } catch (e) {
      debugPrint('No se pudieron revisar los avisos: $e');
    } finally {
      _revisando = false;
    }
  }

  /// Después de leer avisos dentro de la app.
  static void actualizarNoLeidas(int valor) => noLeidas.value = valor;

  /// Llamado por RecordatoriosService cuando se toca una notificación de aviso.
  static void alTocar(Map<String, dynamic> datos) {
    final id = datos['avisoId']?.toString();
    final tipo = TipoAviso.de(datos['tipoAviso']?.toString());
    toque.value = ToqueAviso(id ?? '', tipo);
  }

  static Future<void> _mostrar(List<Aviso> avisos) async {
    try {
      // Los más recientes como notificación propia; si llegan muchos, un resumen
      final sueltas = avisos.length > _maxSueltas
          ? avisos.sublist(avisos.length - _maxSueltas)
          : avisos;
      for (final a in sueltas) {
        await _plugin.show(
          id: _idDe(a.id),
          title: a.titulo,
          body: a.mensaje,
          notificationDetails: _detalles,
          payload: jsonEncode({
            'tipo': tipoPayload,
            'avisoId': a.id,
            'tipoAviso': a.tipo.valor,
          }),
        );
      }
      final resto = avisos.length - sueltas.length;
      if (resto > 0) {
        await _plugin.show(
          id: _idResumen,
          title: 'Tienes $resto avisos más de tu barrio',
          body: 'Abre ServiApp para ver las fallas y cortes reportados.',
          notificationDetails: _detalles,
          payload: jsonEncode({
            'tipo': tipoPayload,
            'tipoAviso': TipoAviso.fallaBarrio.valor,
          }),
        );
      }
    } catch (e) {
      // Sin permiso de notificaciones el aviso igual queda en la campana
      debugPrint('No se pudo mostrar el aviso: $e');
    }
  }

  // Si la app se abrió tocando un aviso (estaba cerrada), se abre al entrar
  static Future<void> _toqueAlAbrirLaApp() async {
    try {
      final detalles = await _plugin.getNotificationAppLaunchDetails();
      final payload = detalles?.notificationResponse?.payload;
      if (detalles?.didNotificationLaunchApp != true || payload == null) return;
      final datos = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      if (datos['tipo'] == tipoPayload) alTocar(datos);
    } catch (_) {
      // Sin datos de arranque
    }
  }

  /// ID negativo y estable a partir del id de Mongo.
  static int _idDe(String avisoId) {
    var hash = 0x811c9dc5;
    for (final c in avisoId.codeUnits) {
      hash = ((hash ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return -((hash & 0x3FFFFFFF) + 2);
  }
}

// Revisa apenas la app vuelve a primer plano
class _Ciclo extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) NotificacionesService.revisar();
  }
}
