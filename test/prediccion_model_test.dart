import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/predicciones/data/models/prediccion.dart';
import 'package:serviapp/features/predicciones/data/services/prediccion_service.dart';
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
  'metadatosModelo': {'versionModelo': 'ServiApp_LSTM_oficial', 'algoritmo': 'LSTM Red Neuronal Recurrente'},
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

  _ServicioFalso(this.datos);

  @override
  Future<Prediccion> predecir({required Empresa empresa, required String usuarioId}) async {
    final datos = this.datos;
    if (datos == null) {
      throw const PrediccionException('Historial mensual insuficiente: disponibles 3 de 5 meses');
    }
    return Prediccion.fromJson(datos);
  }
}

Future<void> _abrir(WidgetTester tester, Map<String, dynamic>? datos) async {
  // Celular angosto: 360 x 780
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PrediccionScreen(empresa: Empresa.afinia, usuarioId: 'u1', servicio: _ServicioFalso(datos)),
    ),
  );
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
      expect(p.ultimoMes!.periodo, '2026-10');
      expect(p.promedio, closeTo(193.8, 0.001));
      expect(p.mesMayor!.periodo, '2026-08');
      expect(p.mesMenor!.periodo, '2026-10');
      expect(p.cambioFrente(180), closeTo(0.1, 0.0001));
      expect(p.cambioFrente(null), isNull);
    });

    test('rechaza una respuesta sin consumo estimado', () {
      expect(
        () => Prediccion.fromJson({..._json, 'prediccionSiguienteMes': {'periodoEstimado': '2026-11'}}),
        throwsFormatException,
      );
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

      final lista = find.byType(Scrollable).first;
      for (final texto in [
        find.text('Tendencia y predicción (kWh)'),
        find.text('Resumen'),
        find.text('Consejos para Noviembre 2026'),
        find.text('ServiApp_LSTM_oficial'),
        find.text('Volver al inicio'),
      ]) {
        await tester.scrollUntilVisible(texto, 200, scrollable: lista);
        await tester.pump(const Duration(seconds: 1));
        expect(texto, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('muestra el error de Spring y permite reintentar', (tester) async {
      await _abrir(tester, null);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Historial mensual insuficiente: disponibles 3 de 5 meses'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
