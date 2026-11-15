import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/features/fallas/data/models/falla.dart';
import 'package:serviapp/features/notificaciones/data/aviso.dart';

void main() {
  test('interpreta la falla que envía Spring Boot', () {
    final falla = Falla.fromJson({
      'id': 'f1',
      'servicio': 'energia',
      'barrio': 'ALCIBIA',
      'comentarios': 'Se fue la luz',
      'estado': 'RECIBIDO',
      'hora': '2026-11-13T20:40:00Z',
      'fechaReporte': '2026-11-13T20:45:00Z',
      'fechaSolucion': null,
      'confirmaciones': 3,
      'esMia': false,
      'yoConfirme': true,
    });

    expect(falla.servicio, ServicioFalla.energia);
    expect(falla.estado, EstadoFalla.recibido);
    expect(falla.activa, isTrue);
    expect(falla.confirmaciones, 3);
    expect(falla.yoConfirme, isTrue);
    expect(falla.hora!.toUtc(), DateTime.utc(2026, 11, 13, 20, 40));
    expect(falla.fechaSolucion, isNull);
  });

  test('tolera fallas antiguas sin los campos nuevos', () {
    final falla = Falla.fromJson({'id': 'f2', 'servicio': 'agua', 'barrio': 'MANGA'});
    expect(falla.estado, EstadoFalla.pendiente);
    expect(falla.confirmaciones, 0);
    expect(falla.esMia, isFalse);
  });

  test('reconoce el servicio de los cortes en mayúsculas', () {
    expect(ServicioFalla.de('ENERGIA'), ServicioFalla.energia);
    expect(ServicioFalla.de('energía'), ServicioFalla.energia);
    expect(ServicioFalla.de('GAS'), ServicioFalla.gas);
    expect(ServicioFalla.de('internet'), isNull);
  });

  test('muestra el barrio con mayúscula inicial', () {
    expect(nombreBarrio('SAN DIEGO'), 'San Diego');
    expect(nombreBarrio(null), '');
  });

  test('los avisos de mis reportes abren Mis reportes', () {
    final aviso = Aviso.fromJson({
      'id': 'a1',
      'tipo': 'ESTADO_FALLA',
      'titulo': 'Recibimos tu reporte de agua',
      'mensaje': '...',
      'servicio': 'agua',
      'fecha': '2026-11-13T20:45:00Z',
      'leida': false,
    });
    expect(aviso.tipo.esDeMisReportes, isTrue);
    expect(TipoAviso.de('FALLA_BARRIO').esDeMisReportes, isFalse);
    expect(aviso.leido().leida, isTrue);
  });
}
