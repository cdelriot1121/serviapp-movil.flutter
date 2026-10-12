import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/features/recibos/data/models/recibo.dart';
import 'package:serviapp/features/recibos/presentation/utils/formatos.dart';

// Respuesta de FastAPI /recibos/analizar (datos ficticios)
const _respuestaFastApi = {
  'recibo': {
    'tipoServicio': 'ENERGIA',
    'empresa': 'AFINIA',
    'identificador': {'tipo': 'NIC', 'valor': '7654321'},
    'numeroFactura': '22402609000000',
    'titular': 'JUAN PEREZ PRUEBA',
    'direccion': 'CL 10 20-30',
    'barrio': null,
    'estrato': 2,
    'periodoFacturado': '2026-09',
    'periodoInicio': '2026-08-10',
    'periodoFin': '2026-09-08',
    'fechaEmision': '2026-09-10',
    'fechaLimitePago': '2026-09-17',
    'fechaSuspension': '2026-09-18',
    'valorTotal': 123450,
    'unidadConsumo': 'kWh',
    'consumoActual': 210.0,
    'lecturaAnterior': null,
    'lecturaActual': null,
    'diasFacturados': 29,
    'historialConsumos': [
      {'periodo': '2026-08', 'consumo': 200.0, 'esActual': false},
      {'periodo': '2026-09', 'consumo': 210.0, 'esActual': true},
    ],
    'conceptos': [],
  },
  'confianza': {'identificador': 0.98, 'valorTotal': 0.55},
  'camposFaltantes': ['barrio'],
  'advertencias': ['Algunos meses no se pudieron leer.'],
  'tiempoProcesamientoMs': 9000,
  'versionExtractor': '1.0.0',
};

void main() {
  test('interpreta la respuesta de FastAPI', () {
    final resultado = ResultadoAnalisis.fromJson(_respuestaFastApi);
    final r = resultado.recibo;

    expect(r.empresa, Empresa.afinia);
    expect(r.identificador, '7654321');
    expect(r.valorTotal, 123450);
    expect(r.fechaLimitePago, DateTime(2026, 9, 17));
    expect(r.historialConsumos.last.esActual, isTrue);
    expect(resultado.confianza['valorTotal'], 0.55);
    expect(resultado.camposFaltantes, ['barrio']);
  });

  test('genera el JSON que espera Spring Boot', () {
    final r = ResultadoAnalisis.fromJson(_respuestaFastApi).recibo;
    final json = r.toJson();

    expect(json['empresa'], 'AFINIA');
    expect(json['identificador'], {'tipo': 'NIC', 'valor': '7654321'});
    expect(json['fechaEmision'], '2026-09-10');
    expect(json['periodoFacturado'], '2026-09');
    expect((json['historialConsumos'] as List).length, 2);
  });

  test('periodos y formatos', () {
    expect(Periodo.parse('2026-01')!.sumar(-2).toString(), '2025-11');
    expect(Periodo.parse('2026-13'), isNull);
    expect(formatearPesos(427630), '\$ 427.630');
    expect(formatearNumero(15.61), '15,61');
    expect(formatearPeriodoLargo('2026-09'), 'Septiembre 2026');
  });
}
