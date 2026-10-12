import 'package:flutter/material.dart';
import 'app/app.dart';
import 'features/recordatorios/recordatorios_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Notificaciones locales de los recordatorios de pago
  await RecordatoriosService.inicializar();
  runApp(const ServiApp());
}
