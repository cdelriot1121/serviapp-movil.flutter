import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/admin/data/models/corte_admin.dart';
import 'package:serviapp/features/admin/data/services/admin_service.dart';
import 'package:serviapp/features/admin/presentation/views/admin_cortes_screen.dart';
import 'package:serviapp/features/admin/presentation/views/admin_fallas_screen.dart';
import 'package:serviapp/features/admin/presentation/views/programar_corte_screen.dart';
import 'package:serviapp/features/fallas/data/models/falla.dart';

String _dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Respuesta de Spring GET /api/mobile/admin/cortes (datos ficticios)
List<Map<String, dynamic>> _cortes() {
  final hoy = DateTime.now();
  return [
    {
      'id': 'c1',
      'servicio': 'Agua',
      'fecha': _dia(hoy),
      'horaInicio': '08:00',
      'horaFinal': '23:59',
      'motivo': 'Cambio de tubería en la calle 30',
      'barrios': ['MANGA', 'CENTRO', 'CRESPO', 'EL BOSQUE', 'LA MATUNA', 'GETSEMANI', 'BOCAGRANDE'],
      'vigente': true,
      'usuariosAfectados': 12,
    },
    {
      'id': 'c2',
      'servicio': 'Energia',
      'fecha': _dia(hoy.subtract(const Duration(days: 9))),
      'horaInicio': '09:00',
      'horaFinal': '11:00',
      'motivo': 'Mantenimiento del transformador',
      'barrios': ['ALCIBIA'],
      'vigente': false,
      'usuariosAfectados': 1,
    },
  ];
}

const _opciones = {
  'barrios': ['ALCIBIA', 'CENTRO', 'MANGA', 'SAN DIEGO'],
  'usuariosPorBarrio': {'MANGA': 7, 'CENTRO': 2, 'SAN DIEGO': 1},
};

Map<String, dynamic> _falla(String id, String estado, {int horas = 2, int confirmaciones = 0, String servicio = 'agua'}) => {
      'id': id,
      'servicio': servicio,
      'barrio': 'MANGA',
      'comentarios': 'Sin agua desde la mañana',
      'estado': estado,
      'hora': DateTime.now().subtract(Duration(hours: horas + 1)).toUtc().toIso8601String(),
      'fechaReporte': DateTime.now().subtract(Duration(hours: horas)).toUtc().toIso8601String(),
      'confirmaciones': confirmaciones,
      'esMia': false,
      'yoConfirme': false,
      'usuarioNombre': 'Ana Pérez',
      'usuarioEmail': 'ana@test.com',
    };

class _ServicioFalso extends AdminService {
  final List<CorteAdmin> lista = [for (final c in _cortes()) CorteAdmin.fromJson(c)];
  final List<Falla> fallasGuardadas = [
    Falla.fromJson(_falla('f1', 'PENDIENTE', horas: 30, confirmaciones: 2)),
    Falla.fromJson(_falla('f2', 'PENDIENTE', servicio: 'energia')),
    Falla.fromJson(_falla('f3', 'RECIBIDO')),
    Falla.fromJson(_falla('f4', 'COMPLETADO')),
  ];
  Map<String, Object?>? programado;
  String? cancelado;

  // Simula que ya hay un corte en ese horario: Spring pide confirmar
  bool superpuesto = false;
  bool confirmoSuperposicion = false;
  final List<(String, EstadoFalla)> cambios = [];

  @override
  Future<List<CorteAdmin>> cortes() async => List.of(lista);

  @override
  Future<OpcionesCorte> opcionesCorte() async => OpcionesCorte.fromJson(_opciones);

  @override
  Future<({CorteAdmin corte, int usuariosNotificados})> programarCorte({
    required ServicioFalla servicio,
    required DateTime fecha,
    required String horaInicio,
    required String horaFinal,
    required String motivo,
    required List<String> barrios,
    bool confirmarSuperposicion = false,
  }) async {
    if (superpuesto && !confirmarSuperposicion) {
      throw const AdminException(
        'Ya hay un corte de agua ese día de 09:00 a 11:00 en MANGA. ¿Quieres programar este de todos modos?',
        codigo: 'CORTE_SUPERPUESTO',
      );
    }
    confirmoSuperposicion = confirmarSuperposicion;
    programado = {
      'servicio': servicio,
      'fecha': fecha,
      'horaInicio': horaInicio,
      'horaFinal': horaFinal,
      'motivo': motivo,
      'barrios': barrios,
    };
    final corte = CorteAdmin.fromJson({
      'id': 'nuevo',
      'servicio': servicio.valor,
      'fecha': _dia(fecha),
      'horaInicio': horaInicio,
      'horaFinal': horaFinal,
      'motivo': motivo,
      'barrios': barrios,
      'vigente': true,
      'usuariosAfectados': 9,
    });
    lista.insert(0, corte);
    return (corte: corte, usuariosNotificados: 9);
  }

  @override
  Future<int> cancelarCorte(String id) async {
    cancelado = id;
    lista.removeWhere((c) => c.id == id);
    return 12;
  }

  @override
  Future<List<Falla>> fallas() async => List.of(fallasGuardadas);

  @override
  Future<void> cambiarEstadoFalla(String id, EstadoFalla estado) async => cambios.add((id, estado));
}

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  // Celular angosto: 360 x 780
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: pantalla));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Modelos', () {
    test('lee el corte del administrador', () {
      final c = CorteAdmin.fromJson(_cortes().first);
      expect(c.servicio, ServicioFalla.agua);
      expect(c.barrios, hasLength(7));
      expect(c.vigente, isTrue);
      expect(c.usuariosAfectados, 12);
      expect(c.horario, '08:00 – 23:59');
    });

    test('suma los usuarios de los barrios elegidos', () {
      final o = OpcionesCorte.fromJson(_opciones);
      expect(o.usuariosEn(['MANGA', 'CENTRO', 'ALCIBIA']), 9);
      expect(o.usuariosEn(const []), 0);
    });

    test('nombra el día del corte', () {
      final hoy = DateTime(2026, 11, 20, 10);
      expect(diaRelativo(DateTime(2026, 11, 20), hoy: hoy), 'Hoy');
      expect(diaRelativo(DateTime(2026, 11, 21), hoy: hoy), 'Mañana');
      expect(diaRelativo(DateTime(2026, 11, 24), hoy: hoy), 'Martes 24 de noviembre');
    });
  });

  group('AdminCortesScreen', () {
    testWidgets('separa vigentes e historial y resume los barrios', (tester) async {
      await _mostrar(tester, AdminCortesScreen(servicio: _ServicioFalso()));

      expect(find.text('Vigentes · 1'), findsOneWidget);
      expect(find.text('Historial · 1'), findsOneWidget);
      expect(find.text('Corte de agua'), findsOneWidget);
      expect(find.text('Hoy · 08:00 – 23:59'), findsOneWidget);
      // 6 barrios visibles y el resto agrupado
      expect(find.text('+1 más'), findsOneWidget);
      expect(find.text('7 barrios · 12 usuarios en la zona'), findsOneWidget);

      await tester.tap(find.text('Historial · 1'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Corte de energía'), findsOneWidget);
      expect(find.text('Terminado'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar pide confirmación y avisa a cuántos se informó', (tester) async {
      final servicio = _ServicioFalso();
      await _mostrar(tester, AdminCortesScreen(servicio: servicio));

      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¿Cancelar este corte?'), findsOneWidget);
      expect(find.textContaining('Avisaremos a los 12 usuarios'), findsOneWidget);

      await tester.tap(find.text('Cancelar corte'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(servicio.cancelado, 'c1');
      expect(find.text('Corte cancelado. Avisamos a 12 usuarios.'), findsOneWidget);
      expect(find.text('Vigentes · 0'), findsOneWidget);
      expect(find.textContaining('No hay cortes programados'), findsOneWidget);
    });
  });

  group('ProgramarCorteScreen', () {
    testWidgets('arma el corte, muestra la notificación y lo envía', (tester) async {
      final servicio = _ServicioFalso()..superpuesto = true;
      CorteProgramadoResultado? resultado;
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await Navigator.of(context).push<CorteProgramadoResultado>(
                  MaterialPageRoute(
                    builder: (_) => ProgramarCorteScreen(servicio: servicio, ahora: DateTime(2026, 11, 20, 10)),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Por defecto: mañana de 08:00 a 12:00, y aún falta todo lo demás
      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('sábado 21 de noviembre'), findsOneWidget);
      expect(find.text('Elige el servicio que se cortará.'), findsOneWidget);

      await tester.tap(find.text('Agua'));
      await tester.pump();
      expect(find.text('Elige al menos un barrio afectado.'), findsOneWidget);

      // Barrios: busca y marca dos
      await tester.ensureVisible(find.text('Elegir barrios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir barrios'));
      await tester.pumpAndSettle();
      // El buscador es el último campo de texto (el de la hoja)
      final buscador = find.byType(TextField).last;
      await tester.enterText(buscador, 'man');
      await tester.pump();
      expect(find.text('Centro'), findsNothing);
      await tester.tap(find.text('Manga'));
      await tester.pump();
      await tester.enterText(buscador, '');
      await tester.pump();
      await tester.tap(find.text('Centro'));
      await tester.pump();
      expect(find.text('Listo · 2 barrios · 9 usuarios'), findsOneWidget);
      await tester.tap(find.text('Listo · 2 barrios · 9 usuarios'));
      await tester.pumpAndSettle();

      final motivo = find.widgetWithText(TextField, 'Ej.: Mantenimiento de la red en la calle 30');
      await tester.ensureVisible(motivo);
      await tester.enterText(motivo, 'Lavado de tanques');
      await tester.pump();

      expect(find.text('9 usuarios recibirán la notificación.'), findsOneWidget);
      expect(find.text('Corte de agua programado en Manga'), findsOneWidget);
      expect(
        find.text('Habrá un corte de agua en tu barrio el sábado 21 de noviembre de 08:00 a 12:00. '
            'Motivo: Lavado de tanques.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Programar y avisar'));
      await tester.pumpAndSettle();

      // Se cruza con otro corte: el administrador decide programarlo igual
      expect(find.text('Ya hay un corte en ese horario'), findsOneWidget);
      expect(servicio.programado, isNull);
      await tester.tap(find.text('Programar igual'));
      await tester.pumpAndSettle();
      expect(servicio.confirmoSuperposicion, isTrue);

      expect(servicio.programado, {
        'servicio': ServicioFalla.agua,
        'fecha': DateTime(2026, 11, 21),
        'horaInicio': '08:00',
        'horaFinal': '12:00',
        'motivo': 'Lavado de tanques',
        'barrios': ['MANGA', 'CENTRO'],
      });
      expect(resultado?.usuariosNotificados, 9);
    });
  });

  group('AdminFallasScreen', () {
    testWidgets('cuenta por estado, filtra por servicio y cambia el estado', (tester) async {
      final servicio = _ServicioFalso();
      await _mostrar(tester, AdminFallasScreen(servicio: servicio));

      expect(find.text('Pendiente · 2'), findsOneWidget);
      expect(find.text('En revisión · 1'), findsOneWidget);
      expect(find.text('1 falla lleva más de un día sin revisar.'), findsOneWidget);
      expect(find.text('Lleva más de un día sin revisar'), findsOneWidget);

      // La primera pendiente se cierra directamente como solucionada
      await tester.tap(find.text('Solucionada').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(servicio.cambios, [('f1', EstadoFalla.completado)]);
      expect(find.textContaining('y a 2 vecinos'), findsOneWidget);
      expect(find.text('Pendiente · 1'), findsOneWidget);

      // Los chips de servicio se desplazan de lado
      await tester.ensureVisible(find.text('Energía'));
      await tester.pump();
      await tester.tap(find.text('Energía'));
      await tester.pump();
      expect(find.text('Pendiente · 1'), findsOneWidget);
      expect(find.text('Falla de energía'), findsOneWidget);
      expect(find.text('Falla de agua'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
