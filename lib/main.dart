import 'package:flutter/material.dart';
import 'app/app.dart';
import 'features/notificaciones/notificaciones_service.dart';
import 'features/notificaciones/push_service.dart';
import 'features/recordatorios/recordatorios_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase para los avisos push de fallas y cortes (llegan con o sin sesión)
  await PushService.inicializar();
  await NotificacionesService.prepararPush();
  // Notificaciones locales de los recordatorios de pago
  await RecordatoriosService.inicializar();
  runApp(const ServiApp());
}
