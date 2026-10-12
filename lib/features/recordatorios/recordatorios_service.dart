import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/theme/app_colors.dart';
import '../recibos/data/models/recibo.dart';
import '../recibos/data/services/recibo_service.dart';
import '../recibos/presentation/utils/formatos.dart';

/// Momentos del recordatorio respecto a la fecha de pago oportuno.
enum _Etapa {
  antes(-1, 9),
  hoy(0, 8),
  vencido(1, 9);

  const _Etapa(this.desfaseDias, this.hora);

  final int desfaseDias;
  final int hora;
}

/// Recordatorios locales de pago: un día antes, el día y un día después de la
/// fecha de pago oportuno de cada recibo que no esté marcado como pagado.
///
/// El botón "Ya lo pagué" de la notificación funciona con la app cerrada: el
/// pago se guarda en el celular y se sube a Spring en el siguiente inicio de
/// sesión (la cookie de sesión solo vive mientras la app está abierta).
class RecordatoriosService {
  RecordatoriosService._();

  static const accionPagado = 'pagado';
  static const accionDespues = 'despues';

  static const _categoriaIos = 'recordatorio_pago';
  static const _clavePendientes = 'pagos_sin_sincronizar';
  static const _claveNombre = 'nombre_recordatorios';
  static const _posponer = Duration(hours: 3);

  // IDs menores a 2^30: hash del recibo * 4 + etapa (3 = confirmación).
  // Desde 2^30: recordatorios pospuestos con "Recordar más tarde".
  static const _basePospuestos = 1 << 30;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _prefs = SharedPreferencesAsync();

  /// Cambia cuando un recibo se marca o desmarca como pagado, para que las
  /// pantallas abiertas se recarguen.
  static final ValueNotifier<int> cambios = ValueNotifier(0);

  static bool _listo = false;

  static final _ajustes = InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      // El permiso se pide después del login, no al abrir la app
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _categoriaIos,
          actions: [
            DarwinNotificationAction.plain(accionPagado, 'Ya lo pagué'),
            DarwinNotificationAction.plain(accionDespues, 'Recordar más tarde'),
          ],
        ),
      ],
    ),
  );

  // ------------------------------------------------------------- ciclo de vida

  /// Se llama en main() antes de runApp.
  static Future<void> inicializar() async {
    if (_listo) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final zona = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zona.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('America/Bogota'));
      }
      await _plugin.initialize(
        settings: _ajustes,
        onDidReceiveNotificationResponse: (r) => _procesar(r, enApp: true),
        onDidReceiveBackgroundNotificationResponse: recordatorioEnSegundoPlano,
      );
      _listo = true;
    } catch (e) {
      // Sin notificaciones la app sigue funcionando
      debugPrint('Recordatorios no disponibles: $e');
    }
  }

  /// Tras el login: pide permiso, sube los pagos marcados desde notificaciones
  /// y vuelve a programar todos los recordatorios. Devuelve los recibos, o
  /// null si no se pudieron cargar.
  static Future<List<Recibo>?> alIniciarSesion(String nombre) async {
    final primerNombre = nombre.trim().split(RegExp(r'\s+')).first;
    await _prefs.setString(_claveNombre, primerNombre);
    if (_listo) await _pedirPermiso();

    try {
      final recibos = await recibosActualizados();
      if (_listo) await _programarTodos(recibos, primerNombre);
      return recibos;
    } on ReciboException {
      return null;
    }
  }

  static Future<void> alCerrarSesion() async {
    await _prefs.remove(_claveNombre);
    if (_listo) await _plugin.cancelAll();
  }

  // ------------------------------------------------------------- recibos

  /// Recibos del servidor con los pagos hechos desde notificaciones ya
  /// aplicados (aunque todavía no se hayan podido subir).
  static Future<List<Recibo>> recibosActualizados({String? tipoServicio}) async {
    await sincronizarPagos();
    final recibos = await ReciboService().listar(tipoServicio: tipoServicio);
    final pendientes = await _pagosSinSincronizar();
    return [
      for (final r in recibos)
        if (!r.pagado && pendientes.containsKey(r.id))
          r.conPago(pagado: true, fechaPago: DateTime.tryParse(pendientes[r.id]!))
        else
          r,
    ];
  }

  /// Sube a Spring los pagos marcados con el botón de la notificación.
  static Future<void> sincronizarPagos() async {
    final pendientes = await _pagosSinSincronizar();
    if (pendientes.isEmpty) return;

    final service = ReciboService();
    for (final pago in Map.of(pendientes).entries) {
      try {
        await service.marcarPago(
          pago.key,
          pagado: true,
          fechaPago: DateTime.tryParse(pago.value),
        );
        pendientes.remove(pago.key);
      } on ReciboException catch (e) {
        // Sin conexión o sin sesión se reintenta luego; si el servidor lo
        // rechaza (recibo eliminado, de otra cuenta...) se descarta
        if (e.sesionExpirada || e.codigo == null) break;
        pendientes.remove(pago.key);
      }
    }
    await _guardarPendientes(pendientes);
  }

  /// Llamar después de guardar un recibo o de marcarlo / desmarcarlo como pagado.
  static Future<void> actualizarRecibo(Recibo recibo) async {
    final id = recibo.id;
    if (id == null) return;
    if (recibo.pagado) {
      final pendientes = await _pagosSinSincronizar();
      if (pendientes.remove(id) != null) await _guardarPendientes(pendientes);
    }
    if (_listo) {
      await _cancelarDeRecibo(id);
      if (!recibo.pagado) {
        await _programarRecibo(recibo, await _prefs.getString(_claveNombre) ?? '');
      }
    }
    cambios.value++;
  }

  static Future<void> reciboEliminado(String id) async {
    if (_listo) await _cancelarDeRecibo(id);
    cambios.value++;
  }

  // ------------------------------------------------------------- programación

  static Future<void> _programarTodos(List<Recibo> recibos, String nombre) async {
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id < _basePospuestos) await _plugin.cancel(id: p.id);
    }
    for (final r in recibos) {
      if (!r.pagado) await _programarRecibo(r, nombre);
    }
  }

  static Future<void> _programarRecibo(Recibo r, String nombre) async {
    final limite = r.fechaLimitePago;
    final id = r.id;
    if (limite == null || id == null) return;

    final ahora = tz.TZDateTime.now(tz.local);
    for (final etapa in _Etapa.values) {
      final dia = DateTime(limite.year, limite.month, limite.day + etapa.desfaseDias);
      final cuando = tz.TZDateTime(tz.local, dia.year, dia.month, dia.day, etapa.hora);
      // Solo momentos futuros: así no se repiten avisos al volver a entrar
      if (!cuando.isAfter(ahora)) continue;

      final texto = _texto(etapa, r, nombre);
      await _plugin.zonedSchedule(
        id: _idBase(id) + etapa.index,
        scheduledDate: cuando,
        notificationDetails: _detalles(texto.cuerpo),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: texto.titulo,
        body: texto.cuerpo,
        payload: jsonEncode({
          'reciboId': id,
          'servicio': r.empresa.servicio.toLowerCase(),
          'titulo': texto.titulo,
          'cuerpo': texto.cuerpo,
        }),
      );
    }
  }

  static ({String titulo, String cuerpo}) _texto(_Etapa etapa, Recibo r, String nombre) {
    final hola = nombre.isEmpty ? 'Hola' : 'Hola $nombre';
    final servicio = r.empresa.servicio.toLowerCase();
    final recibo = 'tu recibo de $servicio de ${r.empresa.nombre}';
    final valor = r.valorTotal == null ? '' : ' por ${formatearPesos(r.valorTotal)}';

    switch (etapa) {
      case _Etapa.antes:
        return (
          titulo: 'Mañana vence tu recibo de $servicio',
          cuerpo: '$hola, recuerda que $recibo$valor vence mañana '
              '(${formatearFecha(r.fechaLimitePago)}). Págalo a tiempo y evita recargos.',
        );
      case _Etapa.hoy:
        return (
          titulo: 'Hoy es el último día para pagar',
          cuerpo: '$hola, hoy vence $recibo$valor. Es el último día para '
              'pagarlo sin intereses ni recargos.',
        );
      case _Etapa.vencido:
        final corte = r.fechaSuspension == null
            ? ''
            : ' Fecha de corte: ${formatearFecha(r.fechaSuspension)}.';
        return (
          titulo: 'Tu recibo de $servicio está vencido',
          cuerpo: '$hola, $recibo venció ayer y aún no lo has marcado como '
              'pagado. Págalo pronto para evitar cortes o cobros adicionales.$corte',
        );
    }
  }

  static NotificationDetails _detalles(String cuerpo) => NotificationDetails(
        android: AndroidNotificationDetails(
          'recordatorios_pago',
          'Recordatorios de pago',
          channelDescription:
              'Avisos antes, durante y después de la fecha de pago de tus recibos.',
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.primary,
          styleInformation: BigTextStyleInformation(cuerpo),
          actions: const [
            AndroidNotificationAction(accionPagado, 'Ya lo pagué'),
            AndroidNotificationAction(accionDespues, 'Recordar más tarde'),
          ],
        ),
        iOS: const DarwinNotificationDetails(categoryIdentifier: _categoriaIos),
      );

  static const _detallesConfirmacion = NotificationDetails(
    android: AndroidNotificationDetails(
      'confirmaciones_pago',
      'Confirmaciones de pago',
      channelDescription: 'Confirma cuando marcas un recibo como pagado.',
      importance: Importance.low,
      priority: Priority.low,
      color: AppColors.green,
      timeoutAfter: 8000,
    ),
  );

  // ------------------------------------------------------------- respuestas

  static Future<void> _procesar(NotificationResponse respuesta, {required bool enApp}) async {
    final datos = _leerPayload(respuesta.payload);
    final reciboId = datos?['reciboId'] as String?;
    if (datos == null || reciboId == null) return;

    switch (respuesta.actionId) {
      case accionPagado:
        final pendientes = await _pagosSinSincronizar();
        pendientes[reciboId] = Recibo.iso(DateTime.now())!;
        await _guardarPendientes(pendientes);
        await _cancelarDeRecibo(reciboId);
        await _plugin.show(
          id: _idBase(reciboId) + 3,
          title: '¡Listo! Recibo pagado',
          body: 'Marcamos tu recibo de ${datos['servicio']} como pagado. '
              'No te enviaremos más recordatorios de este mes.',
          notificationDetails: _detallesConfirmacion,
        );
        if (enApp) {
          try {
            await sincronizarPagos();
          } catch (_) {
            // Se reintenta en el siguiente inicio de sesión
          }
          cambios.value++;
        }
      case accionDespues:
        await _plugin.zonedSchedule(
          id: _basePospuestos + (DateTime.now().millisecondsSinceEpoch ~/ 1000) % _basePospuestos,
          scheduledDate: tz.TZDateTime.now(tz.UTC).add(_posponer),
          notificationDetails: _detalles(datos['cuerpo'] as String? ?? ''),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: datos['titulo'] as String?,
          body: datos['cuerpo'] as String?,
          payload: respuesta.payload,
        );
    }
  }

  // ------------------------------------------------------------- utilidades

  static Future<void> _cancelarDeRecibo(String reciboId) async {
    final base = _idBase(reciboId);
    for (var i = 0; i < _Etapa.values.length; i++) {
      await _plugin.cancel(id: base + i);
    }
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= _basePospuestos && _leerPayload(p.payload)?['reciboId'] == reciboId) {
        await _plugin.cancel(id: p.id);
      }
    }
  }

  static Future<void> _pedirPermiso() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('No se pudo pedir el permiso de notificaciones: $e');
    }
  }

  /// Hash FNV-1a estable del id de Mongo, para IDs de notificación fijos.
  static int _idBase(String reciboId) {
    var hash = 0x811c9dc5;
    for (final c in reciboId.codeUnits) {
      hash = ((hash ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash & 0x0FFFFFFF) * 4;
  }

  static Map<String, dynamic>? _leerPayload(String? payload) {
    if (payload == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _pagosSinSincronizar() async {
    final texto = await _prefs.getString(_clavePendientes);
    if (texto == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(texto) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _guardarPendientes(Map<String, String> pendientes) =>
      _prefs.setString(_clavePendientes, jsonEncode(pendientes));
}

/// Botones de la notificación con la app cerrada (corre en otro isolate).
@pragma('vm:entry-point')
Future<void> recordatorioEnSegundoPlano(NotificationResponse respuesta) async {
  DartPluginRegistrant.ensureInitialized();
  tzdata.initializeTimeZones();
  await RecordatoriosService._plugin.initialize(
    settings: RecordatoriosService._ajustes,
    onDidReceiveBackgroundNotificationResponse: recordatorioEnSegundoPlano,
  );
  await RecordatoriosService._procesar(respuesta, enApp: false);
}
