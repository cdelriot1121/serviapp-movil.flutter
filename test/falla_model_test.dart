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

  test('lee las fotos de la falla con su llave para la caché', () {
    final falla = Falla.fromJson({
      'id': 'f3',
      'servicio': 'agua',
      'barrio': 'MANGA',
      'fotos': [
        {'id': 'x1', 'url': 'https://s3/x1.jpg?firma=1', 'miniatura': 'https://s3/x1-mini.jpg?firma=1'},
      ],
    });

    expect(falla.fotos, hasLength(1));
    final foto = falla.fotos.single;
    expect(foto.miniatura, 'https://s3/x1-mini.jpg?firma=1');
    // La llave no depende del enlace firmado, que cambia cada hora
    expect(foto.claveCache, 'falla-foto-x1');
    expect(foto.claveCacheMiniatura, 'falla-foto-mini-x1');

    expect(falla.copiar(fotos: const []).fotos, isEmpty);
    expect(falla.copiar(confirmaciones: 2).fotos, hasLength(1));
  });

  test('el formulario solo ofrece fotos si Spring puede guardarlas', () {
    final con = OpcionesFalla.fromJson({
      'barrios': ['MANGA'],
      'miBarrio': 'MANGA',
      'fotos': {'habilitadas': true, 'maximo': 3},
    });
    expect(con.fotosHabilitadas, isTrue);
    expect(con.maxFotos, 3);

    // Spring anterior o sin S3: sin fotos
    final sin = OpcionesFalla.fromJson({'barrios': ['MANGA'], 'miBarrio': 'MANGA'});
    expect(sin.fotosHabilitadas, isFalse);
    expect(sin.maxFotos, 0);
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
