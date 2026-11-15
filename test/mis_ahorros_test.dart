import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/ahorros/data/models/resumen_ahorro.dart';
import 'package:serviapp/features/ahorros/data/services/ahorro_service.dart';
import 'package:serviapp/features/ahorros/presentation/views/mis_ahorros_screen.dart';

// Respuesta de Spring GET /api/mobile/ahorros (datos ficticios)
Map<String, dynamic> _respuesta({int ahorroOctubre = 90000}) => {
  'ahorroTotal': 40000 + ahorroOctubre,
  'ultimoPeriodo': '2026-10',
  'ahorroUltimoMes': ahorroOctubre,
  'rachaMeses': ahorroOctubre > 0 ? 2 : 0,
  'mejorPeriodo': ahorroOctubre > 40000 ? '2026-10' : '2026-09',
  'mejorAhorro': ahorroOctubre > 40000 ? ahorroOctubre : 40000,
  'mesesEvaluados': 2,
  'mesesConAhorro': ahorroOctubre > 0 ? 2 : 1,
  'meses': [
    {'periodo': '2026-09', 'ahorro': 40000, 'servicios': 1},
    {'periodo': '2026-10', 'ahorro': ahorroOctubre, 'servicios': 2},
  ],
  'servicios': [
    {
      'tipoServicio': 'ENERGIA',
      'empresa': 'AFINIA',
      'identificador': '1146251',
      'unidad': 'kWh',
      'inicio': '2026-09',
      'lineaBase': 300.0,
      'mesesLineaBase': 3,
      'precioUnidad': 800.0,
      'ahorroTotal': 120000,
      'ahorroConsumo': 150.0,
      'mesesConAhorro': 2,
      'consumoMesAnterior': 250.0,
      'variacionMesAnterior': -20.0,
      'meses': [
        {
          'periodo': '2026-09',
          'consumo': 250.0,
          'fuente': 'FACTURADO',
          'valorTotal': 200000,
          'diferencia': 50.0,
          'porcentaje': 16.67,
          'ahorro': 40000,
          'estado': 'AHORRO',
        },
        {
          'periodo': '2026-10',
          'consumo': 200.0,
          'fuente': 'FACTURADO',
          'valorTotal': 160000,
          'diferencia': 100.0,
          'porcentaje': 33.33,
          'ahorro': 80000,
          'estado': 'AHORRO',
        },
      ],
      'historial': [
        {'periodo': '2026-06', 'consumo': 300.0, 'antesDeServiApp': true},
        {'periodo': '2026-07', 'consumo': 320.0, 'antesDeServiApp': true},
        {'periodo': '2026-08', 'consumo': 280.0, 'antesDeServiApp': true},
        {'periodo': '2026-09', 'consumo': 250.0, 'antesDeServiApp': false},
        {'periodo': '2026-10', 'consumo': 200.0, 'antesDeServiApp': false},
      ],
    },
    {
      'tipoServicio': 'AGUA',
      'empresa': 'AGUAS_DE_CARTAGENA',
      'identificador': '9001',
      'unidad': 'm3',
      'inicio': '2026-10',
      'lineaBase': 20.0,
      'mesesLineaBase': 1,
      'precioUnidad': 5000.0,
      'ahorroTotal': ahorroOctubre - 80000,
      'ahorroConsumo': (ahorroOctubre - 80000) / 5000,
      'mesesConAhorro': ahorroOctubre > 80000 ? 1 : 0,
      'consumoMesAnterior': 20.0,
      'variacionMesAnterior': -10.0,
      'meses': [
        {
          'periodo': '2026-10',
          'consumo': 18.0,
          'fuente': 'FACTURADO',
          'valorTotal': 90000,
          'diferencia': (ahorroOctubre - 80000) / 5000,
          'porcentaje': (ahorroOctubre - 80000) / 5000 / 20 * 100,
          'ahorro': ahorroOctubre - 80000,
          'estado': ahorroOctubre > 80000 ? 'AHORRO' : 'EXCESO',
        },
      ],
      'historial': [
        {'periodo': '2026-09', 'consumo': 20.0, 'antesDeServiApp': true},
        {'periodo': '2026-10', 'consumo': 18.0, 'antesDeServiApp': false},
      ],
    },
  ],
};

class _ServicioFalso extends AhorroService {
  final Map<String, dynamic> datos;

  _ServicioFalso(this.datos);

  @override
  Future<ResumenAhorro> resumen() async => ResumenAhorro.fromJson(datos);
}

Future<void> _abrir(WidgetTester tester, Map<String, dynamic> datos) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MisAhorrosScreen(servicio: _ServicioFalso(datos)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 2));
}

/// Baja por la pantalla pasando por cada texto (la lista construye las
/// tarjetas a medida que aparecen).
Future<void> _recorrer(WidgetTester tester, List<Finder> textos) async {
  final lista = find.byType(Scrollable).first;
  for (final texto in [
    ...textos,
    find.textContaining('¿Cómo lo calculamos?'),
  ]) {
    await tester.scrollUntilVisible(texto, 200, scrollable: lista);
    await tester.pump(const Duration(seconds: 1));
    expect(texto, findsWidgets);
  }
}

void main() {
  test('interpreta el resumen que envía Spring Boot', () {
    final r = ResumenAhorro.fromJson(_respuesta());

    expect(r.ahorroTotal, 130000);
    expect(r.rachaMeses, 2);
    expect(r.servicios, hasLength(2));
    expect(r.servicios.first.nombre, 'Energía');
    expect(r.servicios.first.unidadVisible, 'kWh');
    expect(r.servicios.last.unidadVisible, 'm³');
    expect(r.servicios.first.ultimoMes!.estado, EstadoAhorro.ahorro);
    expect(r.tieneComparaciones, isTrue);
  });

  test('tolera una respuesta vacía', () {
    final r = ResumenAhorro.fromJson({});
    expect(r.ahorroTotal, 0);
    expect(r.servicios, isEmpty);
    expect(r.tieneComparaciones, isFalse);
  });

  testWidgets('muestra el ahorro sin desbordes', (tester) async {
    await _abrir(tester, _respuesta());

    expect(find.text('Has ahorrado'), findsOneWidget);
    expect(find.text('\$ 130.000'), findsOneWidget);
    expect(find.text('2 meses seguidos ahorrando'), findsOneWidget);
    expect(find.text('¡Vas muy bien!'), findsOneWidget);
    expect(find.text('Mes a mes'), findsOneWidget);

    await _recorrer(tester, [
      find.text('Consumes 33 % menos que antes'),
      find.text('Ver mes a mes').first,
      find.text('Consumes 10 % menos que antes'),
    ]);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('avisa cuando el último mes gastó de más', (tester) async {
    // Octubre: energía ahorra 80.000 pero el agua gasta 100.000 de más
    await _abrir(tester, _respuesta(ahorroOctubre: -20000));

    expect(find.text('Has ahorrado'), findsOneWidget);
    expect(find.text('Este mes se te fue un poco la mano'), findsOneWidget);
    expect(find.text('Ver mis consejos'), findsOneWidget);

    await _recorrer(tester, [find.text('Consumes 100 % más que antes')]);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin meses comparados muestra el punto de partida', (
    tester,
  ) async {
    final datos = _respuesta();
    datos['ahorroTotal'] = 0;
    datos['mesesEvaluados'] = 0;
    datos['meses'] = [];
    datos['servicios'] = [
      {
        ...(datos['servicios'] as List).first as Map<String, dynamic>,
        'meses': [],
        'ahorroTotal': 0,
      },
    ];
    await _abrir(tester, datos);

    expect(find.text('Tu punto de partida está listo'), findsOneWidget);
    expect(find.text('Mes a mes'), findsNothing);
    expect(find.textContaining('Este es tu punto de partida'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin recibos invita a escanear', (tester) async {
    await _abrir(tester, {'servicios': []});

    expect(find.text('Escanear recibo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
