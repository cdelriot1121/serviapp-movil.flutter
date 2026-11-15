import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/admin/data/models/estadisticas.dart';
import 'package:serviapp/features/admin/data/services/admin_service.dart';
import 'package:serviapp/features/admin/presentation/views/admin_dashboard_screen.dart';

// Respuesta de Spring GET /api/mobile/admin/estadisticas (datos ficticios)
Map<String, dynamic> _respuesta({int usuarios = 42}) => {
  'generadoEn': '2026-11-13T20:00:00Z',
  'resumen': {
    'usuarios': usuarios,
    'administradores': 2,
    'usuariosActivos': usuarios - 3,
    'usuariosInhabilitados': 3,
    'usuariosConPredio': 30,
    'nuevosEsteMes': 5,
    'recibos': 120,
    'analisis': 80,
    'predicciones': 64,
    'fallas': 9,
    'consejos': 18,
    'consumosRegistrados': 210,
  },
  'usuarios': {
    'porEstrato': [
      {'etiqueta': '2', 'valor': 10},
      {'etiqueta': '3', 'valor': 15},
      {'etiqueta': '5', 'valor': 5},
    ],
    'porTipoPredio': [
      {'etiqueta': 'Casa', 'valor': 18},
      {'etiqueta': 'Apartamento', 'valor': 12},
    ],
    'topBarrios': [
      {'etiqueta': 'Manga', 'valor': 8},
      {'etiqueta': 'Bocagrande', 'valor': 6},
      {'etiqueta': 'El Bosque con un nombre muy largo', 'valor': 4},
    ],
    'serviciosRegistrados': [
      {'etiqueta': 'Energía', 'valor': 30},
      {'etiqueta': 'Agua', 'valor': 25},
      {'etiqueta': 'Gas', 'valor': 12},
    ],
  },
  'actividadMensual': [
    for (var m = 6; m <= 11; m++)
      {
        'periodo': '2026-${m.toString().padLeft(2, '0')}',
        'registros': m,
        'recibos': m * 3,
        'analisis': m * 2,
        'predicciones': m + 1,
      },
  ],
  'recibos': {
    'porServicio': [
      {'etiqueta': 'Energía', 'valor': 60},
      {'etiqueta': 'Agua', 'valor': 40},
      {'etiqueta': 'Gas', 'valor': 20},
    ],
    'pagados': 70,
    'pendientes': 50,
    'vencidos': 12,
    'valorFacturado': 18450300,
    'valorPromedioPorServicio': [
      {'etiqueta': 'Energía', 'valor': 210500.5},
      {'etiqueta': 'Agua', 'valor': 95000},
    ],
    'consumoPromedioPorServicio': [
      {'etiqueta': 'Energía', 'valor': 245.37, 'unidad': 'kWh'},
      {'etiqueta': 'Agua', 'valor': 15.6, 'unidad': 'm³'},
      {'etiqueta': 'Gas', 'valor': 21.2, 'unidad': 'm³'},
    ],
  },
  'analisis': {
    'porCategoria': [
      {'etiqueta': 'Bajo', 'valor': 30},
      {'etiqueta': 'Moderado', 'valor': 35},
      {'etiqueta': 'Elevado', 'valor': 15},
    ],
    'porServicio': [
      {'etiqueta': 'Energía', 'valor': 40},
      {'etiqueta': 'Agua', 'valor': 40},
    ],
    'irregulares': 11,
    'porcentajeIrregular': 13.75,
  },
  'predicciones': {
    'porServicio': [
      {'etiqueta': 'Agua', 'valor': 34},
      {'etiqueta': 'Energía', 'valor': 30},
    ],
    'porNivel': [
      {'etiqueta': 'Bajo', 'valor': 20},
      {'etiqueta': 'Moderado', 'valor': 44},
    ],
    'confianzaPromedio': 0.87,
  },
  'fallas': {
    'porEstado': [
      {'etiqueta': 'Pendiente', 'valor': 4},
      {'etiqueta': 'Recibido', 'valor': 3},
      {'etiqueta': 'Completado', 'valor': 2},
    ],
    'porServicio': [
      {'etiqueta': 'Energía', 'valor': 6},
      {'etiqueta': 'Agua', 'valor': 3},
    ],
  },
  'cortes': {'total': 7, 'activos': 1},
};

class _ServicioFalso extends AdminService {
  final List<Map<String, dynamic>> respuestas;
  int llamadas = 0;

  _ServicioFalso(this.respuestas);

  @override
  Future<Estadisticas> estadisticas() async {
    final datos = respuestas[llamadas.clamp(0, respuestas.length - 1)];
    llamadas++;
    return Estadisticas.fromJson(datos);
  }
}

Future<void> _abrir(WidgetTester tester, AdminService servicio) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: AdminDashboardScreen(nombre: 'Laura Admin', servicio: servicio),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  test('interpreta las estadísticas que envía Spring Boot', () {
    final e = Estadisticas.fromJson(_respuesta());

    expect(e.resumen.usuarios, 42);
    expect(e.resumen.predicciones, 64);
    expect(e.actividadMensual, hasLength(6));
    expect(e.actividadMensual.last.periodo, '2026-11');
    expect(e.valorFacturado, 18450300);
    expect(e.consumoPromedioPorServicio.first.unidad, 'kWh');
    expect(e.confianzaPromedio, 0.87);
    expect(e.cortesActivos, 1);
  });

  test('tolera una respuesta vacía', () {
    final e = Estadisticas.fromJson({});
    expect(e.resumen.usuarios, 0);
    expect(e.actividadMensual, isEmpty);
    expect(e.confianzaPromedio, isNull);
  });

  testWidgets('muestra el panel completo sin desbordes', (tester) async {
    await _abrir(tester, _ServicioFalso([_respuesta()]));

    expect(find.text('Panel de control'), findsOneWidget);
    expect(find.text('Usuarios registrados'), findsOneWidget);
    expect(find.text('42'), findsWidgets);
    expect(find.textContaining('En vivo'), findsOneWidget);

    // Recorre todo el panel para construir cada sección
    final lista = find.byType(Scrollable).first;
    for (final texto in [
      'Usuarios por estrato',
      'Barrios con más usuarios',
      'Nivel de consumo analizado',
      'Predicciones por servicio',
      'Valor total facturado',
      'Consumo promedio por recibo',
      'Cortes programados',
    ]) {
      await tester.scrollUntilVisible(find.text(texto), 300, scrollable: lista);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('se actualiza solo y marca el aumento', (tester) async {
    final servicio = _ServicioFalso([
      _respuesta(usuarios: 42),
      _respuesta(usuarios: 44),
    ]);
    await _abrir(tester, servicio);
    expect(find.text('+2'), findsNothing);

    // Pasa el intervalo de actualización en vivo
    await tester.pump(AdminDashboardScreen.intervalo);
    await tester.pump(const Duration(seconds: 2));

    expect(servicio.llamadas, greaterThanOrEqualTo(2));
    expect(find.text('44'), findsWidgets);
    expect(find.text('+2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('sin datos muestra los estados vacíos', (tester) async {
    await _abrir(tester, _ServicioFalso([{}]));
    expect(find.text('Panel de control'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
