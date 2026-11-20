import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/predicciones/data/models/prediccion.dart';
import 'package:serviapp/features/predicciones/data/services/prediccion_service.dart';
import 'package:serviapp/features/predicciones/presentation/views/historial_predicciones_screen.dart';
import 'package:serviapp/features/predicciones/presentation/views/prediccion_screen.dart';
import 'package:serviapp/features/recibos/data/models/recibo.dart';

// Respuesta de FastAPI POST /api/predicciones/energia (datos ficticios)
const _json = <String, dynamic>{
  'usuarioId': 'u1',
  'servicio': 'ENERGIA',
  'ventanaMesesSolicitada': 5,
  'ventanaUsadaPorModelo': 5,
  'prediccionSiguienteMes': {'periodoEstimado': '2026-11', 'consumoEstimado': 198.0, 'unidad': 'kWh'},
  'historicoAnalizado': [
    {'periodo': '2026-06', 'consumo': 191.0},
    {'periodo': '2026-07', 'consumo': 181.0},
    {'periodo': '2026-08', 'consumo': 229.0},
    {'periodo': '2026-09', 'consumo': 188.0},
    {'periodo': '2026-10', 'consumo': 180.0},
  ],
  'porcentajeFiabilidad': 90.89,
  'metadatosModelo': {'versionModelo': 'ServiApp_LSTM_oficial', 'algoritmo': 'LSTM Red Neuronal Recurrente'},
};

// Predicción guardada en Spring (GET/POST /api/mobile/predicciones)
const _guardada = <String, dynamic>{
  'id': 'p1',
  'tipoServicio': 'ENERGIA',
  'origen': 'APP',
  'periodoEstimado': '2026-11',
  'consumoEstimado': 198.0,
  'unidad': 'kWh',
  'nivelConsumo': 'Moderado',
  'consumoEsperado': 230.0,
  'estrato': 3,
  'habitantes': 2,
  'versionModelo': 'ServiApp_LSTM_oficial',
  'algoritmo': 'LSTM Red Neuronal Recurrente',
  'historico': [
    {'periodo': '2026-09', 'consumo': 188.0},
    {'periodo': '2026-10', 'consumo': 180.0},
  ],
  'fecha': '2026-10-28T09:15:00',
  'consumoReal': 220.0,
};

// Respuesta de Spring GET /api/mobile/predicciones
final _historial = <String, dynamic>{
  'total': 3,
  'predicciones': [
    {..._guardada, 'id': 'p2', 'periodoEstimado': '2026-12', 'consumoReal': null, 'fecha': '2026-11-20T10:00:00'},
    _guardada,
    // De la web: sin historial ni versión del modelo
    {
      'id': 'p0',
      'tipoServicio': 'AGUA',
      'origen': 'WEB',
      'periodoEstimado': '2026-10',
      'consumoEstimado': 20.0,
      'unidad': 'm³',
      'nivelConsumo': 'Bajo',
      'historico': [],
      'fecha': '2026-09-15T10:00:00',
      'consumoReal': 25.0,
    },
  ],
  'consumos': [
    {
      'tipoServicio': 'ENERGIA',
      'unidad': 'kWh',
      'consumos': [
        {'periodo': '2026-09', 'consumo': 188.0, 'fuente': 'GRAFICA'},
        {'periodo': '2026-10', 'consumo': 180.0, 'fuente': 'GRAFICA'},
        {'periodo': '2026-11', 'consumo': 220.0, 'fuente': 'FACTURADO'},
      ],
    },
    {
      'tipoServicio': 'AGUA',
      'unidad': 'm³',
      'consumos': [
        {'periodo': '2026-10', 'consumo': 25.0, 'fuente': 'FACTURADO'},
      ],
    },
  ],
};

Recibo _recibo(String periodo, double consumo, List<(String, double?)> grafica,
        {String identificador = '4116752', Empresa empresa = Empresa.afinia}) =>
    Recibo(
      usuarioId: 'u1',
      empresa: empresa,
      identificador: identificador,
      periodoFacturado: periodo,
      consumoActual: consumo,
      historialConsumos: [
        for (final (p, c) in grafica) ConsumoMensual(periodo: p, consumo: c),
      ],
    );

class _ServicioFalso extends PrediccionService {
  final Map<String, dynamic>? datos;
  final bool guardaBien;

  _ServicioFalso(this.datos, {this.guardaBien = true});

  @override
  Future<Prediccion> predecir({required Empresa empresa, required String usuarioId}) async {
    final datos = this.datos;
    if (datos == null) {
      throw const PrediccionException('Historial mensual insuficiente: disponibles 3 de 5 meses');
    }
    return Prediccion.fromJson(datos);
  }

  @override
  Future<Prediccion> guardar(Prediccion prediccion) async {
    if (!guardaBien) throw const PrediccionException('Sin conexión');
    return Prediccion.desdeSpring({
      ..._guardada,
      'consumoReal': null,
      'historico': prediccion.toJson()['historico'],
      'porcentajeFiabilidad': prediccion.porcentajeFiabilidad,
    });
  }

  @override
  Future<HistorialPredicciones> historial() async => HistorialPredicciones.fromJson(_historial);
}

Future<void> _abrir(WidgetTester tester, Map<String, dynamic>? datos, {bool guardaBien = true}) =>
    _mostrar(
      tester,
      PrediccionScreen(
        empresa: Empresa.afinia,
        usuarioId: 'u1',
        servicio: _ServicioFalso(datos, guardaBien: guardaBien),
      ),
    );

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  // Celular angosto: 360 x 780
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: pantalla));
}

/// Baja por la lista pasando por cada texto y revisa que no haya desbordes.
Future<void> _recorrer(WidgetTester tester, List<Finder> textos) async {
  final lista = find.byType(Scrollable).last;
  for (final texto in textos) {
    await tester.scrollUntilVisible(texto, 200, scrollable: lista);
    await tester.pump(const Duration(seconds: 1));
    expect(texto, findsWidgets);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  group('HistorialServicio', () {
    test('une la gráfica y el mes facturado sin repetir meses', () {
      final historial = HistorialServicio.de(Empresa.afinia, [
        _recibo('2026-10', 178, [('2026-07', 181), ('2026-08', 229), ('2026-09', null), ('2026-10', 178)]),
        _recibo('2026-09', 188, [('2026-06', 191)]),
      ]);

      expect(historial.periodos, ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10']);
      expect(historial.listo, isTrue);
      expect(historial.usuarioId, 'u1');
      expect(historial.periodoAPredecir, '2026-11');
    });

    test('ignora otras cuentas y otros servicios, y dice cuántos meses faltan', () {
      final historial = HistorialServicio.de(Empresa.afinia, [
        _recibo('2026-10', 178, [('2026-09', 188)]),
        _recibo('2026-08', 229, [('2026-07', 181)], identificador: '999'),
        _recibo('2026-10', 20, [('2026-05', 18)], empresa: Empresa.aguasDeCartagena),
      ]);

      expect(historial.periodos, ['2026-09', '2026-10']);
      expect(historial.listo, isFalse);
      expect(historial.faltan, 3);
    });

    test('sin recibos no hay mes a predecir ni usuario', () {
      final historial = HistorialServicio.de(Empresa.surtigas, const []);
      expect(historial.meses, 0);
      expect(historial.periodoAPredecir, isNull);
      expect(historial.listo, isFalse);
    });

    test('diciembre pasa a enero del año siguiente', () {
      final historial = HistorialServicio.de(Empresa.afinia, [_recibo('2026-12', 200, const [])]);
      expect(historial.periodoAPredecir, '2027-01');
    });
  });

  group('Prediccion', () {
    test('lee la respuesta de FastAPI y calcula el resumen', () {
      final p = Prediccion.fromJson(_json);

      expect(p.empresa, Empresa.afinia);
      expect(p.periodoEstimado, '2026-11');
      expect(p.consumoEstimado, 198.0);
      expect(p.historico, hasLength(5));
      expect(p.mesesUsados, 5);
      expect(p.versionModelo, 'ServiApp_LSTM_oficial');
      expect(p.porcentajeFiabilidad, 90.89);
      expect(p.ultimoMes!.periodo, '2026-10');
      expect(p.promedio, closeTo(193.8, 0.001));
      expect(p.mesMayor!.periodo, '2026-08');
      expect(p.mesMenor!.periodo, '2026-10');
      expect(p.cambioFrente(180), closeTo(0.1, 0.0001));
      expect(p.cambioFrente(null), isNull);
      expect(p.acierto, isNull);
    });

    test('sin confiabilidad o con un valor inválido queda en null', () {
      expect(Prediccion.fromJson({..._json}..remove('porcentajeFiabilidad')).porcentajeFiabilidad, isNull);
      expect(Prediccion.fromJson({..._json, 'porcentajeFiabilidad': 140}).porcentajeFiabilidad, isNull);
      expect(Prediccion.desdeSpring(_guardada).porcentajeFiabilidad, isNull);
    });

    test('rechaza una respuesta sin consumo estimado', () {
      expect(
        () => Prediccion.fromJson({..._json, 'prediccionSiguienteMes': {'periodoEstimado': '2026-11'}}),
        throwsFormatException,
      );
    });

    test('envía a Spring lo que respondió FastAPI', () {
      final cuerpo = Prediccion.fromJson(_json).toJson();

      expect(cuerpo['tipoServicio'], 'ENERGIA');
      expect(cuerpo['periodoEstimado'], '2026-11');
      expect(cuerpo['consumoEstimado'], 198.0);
      expect(cuerpo['versionModelo'], 'ServiApp_LSTM_oficial');
      expect(cuerpo['porcentajeFiabilidad'], 90.89);
      expect(cuerpo['historico'], hasLength(5));
      expect((cuerpo['historico'] as List).first, {'periodo': '2026-06', 'consumo': 191.0});
    });

    test('lee lo que guarda Spring y calcula el acierto', () {
      final p = Prediccion.desdeSpring(_guardada);

      expect(p.id, 'p1');
      expect(p.nivelConsumo, 'Moderado');
      expect(p.consumoEsperado, 230.0);
      expect(p.estrato, 3);
      expect(p.habitantes, 2);
      expect(p.mesesUsados, 2);
      expect(p.calculadaEl, DateTime(2026, 10, 28, 9, 15));
      expect(Prediccion.desdeSpring({..._guardada, 'porcentajeFiabilidad': 95.38}).porcentajeFiabilidad, 95.38);
      // 198 predichos frente a 220 reales: 90 % de acierto
      expect(p.acierto, closeTo(0.9, 0.0001));
    });

    test('agrupa el consumo real por servicio y filtra las predicciones', () {
      final h = HistorialPredicciones.fromJson(_historial);

      expect(h.predicciones, hasLength(3));
      expect(h.de(Empresa.afinia), hasLength(2));
      expect(h.de(Empresa.aguasDeCartagena).single.origen, 'WEB');
      expect(h.consumos[Empresa.afinia], hasLength(3));
      expect(h.consumos[Empresa.surtigas], isNull);
      // Energía 90 % y agua 80 %; la de diciembre aún no tiene recibo
      expect(HistorialPredicciones.aciertoPromedio(h.predicciones), closeTo(0.85, 0.0001));
      expect(HistorialPredicciones.aciertoPromedio(const []), isNull);
    });
  });

  group('PrediccionScreen', () {
    testWidgets('muestra el cálculo y luego el resultado sin desbordes', (tester) async {
      await _abrir(tester, _json);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Calculando tu predicción…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Tu predicción'), findsOneWidget);
      expect(find.text('Energía · Noviembre 2026'), findsOneWidget);
      expect(find.text('+10 % frente a Octubre 2026'), findsOneWidget);
      // Categoría que agrega Spring al guardarla
      expect(find.text('Consumo Moderado'), findsOneWidget);
      expect(find.text('Confiabilidad 90,9 %'), findsOneWidget);

      await _recorrer(tester, [
        find.text('Tendencia y predicción (kWh)'),
        find.text('Predicción vs. estrato 3'),
        find.text('Hogar promedio · 2 personas'),
        find.text('Resumen'),
        find.text('Consejos para Noviembre 2026'),
        find.text('ServiApp_LSTM_oficial'),
        find.text('Confiabilidad del modelo'),
        find.text('Ver mis predicciones'),
        find.text('Volver al inicio'),
      ]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('si no se puede guardar igual muestra la predicción', (tester) async {
      await _abrir(tester, _json, guardaBien: false);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Tu predicción'), findsOneWidget);
      expect(find.text('No pudimos guardar esta predicción en tu historial.'), findsOneWidget);
      expect(find.text('Consumo Moderado'), findsNothing);
      expect(find.text('Confiabilidad 90,9 %'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('muestra el error de Spring y permite reintentar', (tester) async {
      await _abrir(tester, null);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Historial mensual insuficiente: disponibles 3 de 5 meses'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('una predicción con recibo muestra cómo le fue', (tester) async {
      await _mostrar(tester, PrediccionScreen.guardada(Prediccion.desdeSpring(_guardada)));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Tu predicción'), findsOneWidget);
      expect(find.text('Así te fue en Noviembre 2026'), findsOneWidget);
      expect(find.textContaining('acertó en un 90 %'), findsOneWidget);

      await _recorrer(tester, [find.text('Volver al historial')]);
      expect(find.text('Calcular otra predicción'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('una predicción de la web sin historial no rompe la vista', (tester) async {
      final web = HistorialPredicciones.fromJson(_historial).de(Empresa.aguasDeCartagena).single;
      await _mostrar(tester, PrediccionScreen.guardada(web));
      await tester.pump(const Duration(seconds: 1));

      await _recorrer(tester, [find.text('Modelo de la web'), find.text('ServiApp web')]);
      expect(find.text('Resumen'), findsNothing);
      expect(find.textContaining('Confiabilidad'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('HistorialPrediccionesScreen', () {
    testWidgets('muestra el historial con el consumo real sin desbordes', (tester) async {
      await _mostrar(tester, HistorialPrediccionesScreen(servicio: _ServicioFalso(_json)));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Mis predicciones'), findsOneWidget);
      expect(find.text('La red neuronal ha acertado en promedio un 85 %.'), findsOneWidget);
      expect(find.text('1 esperando su recibo'), findsOneWidget);

      await _recorrer(tester, [
        find.text('Energía · real y predicho'),
        find.text('Agua · real y predicho'),
        find.text('Tus predicciones'),
        find.text('Real 220 kWh · acierto 90 %'),
        find.text('Esperando tu recibo'),
        find.text('Real 25 m³ · acierto 80 %'),
      ]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el filtro deja solo las del servicio elegido', (tester) async {
      await _mostrar(tester, HistorialPrediccionesScreen(servicio: _ServicioFalso(_json)));
      await tester.pump(const Duration(seconds: 2));

      final agua = find.widgetWithText(ChoiceChip, 'Agua');
      await tester.ensureVisible(agua);
      await tester.pump();
      await tester.tap(agua);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Energía · real y predicho'), findsNothing);
      expect(find.text('Agua · real y predicho'), findsOneWidget);
      // Solo la predicción de agua: 80 % de acierto y ninguna pendiente
      expect(find.text('La red neuronal ha acertado en promedio un 80 %.'), findsOneWidget);
      expect(find.text('1 esperando su recibo'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
