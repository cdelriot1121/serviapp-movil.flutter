import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/features/perfil/data/perfil_service.dart';
import 'package:serviapp/features/recibos/data/models/recibo.dart';

// Respuesta de Spring GET /api/mobile/perfil (datos ficticios): solo trae los
// servicios que el usuario ha escaneado
const _respuesta = {
  'nombre': 'Ana Pérez',
  'email': 'ana@test.com',
  'miembroDesde': '2026-03-15',
  'predio': {
    'direccion': 'Calle 30 # 17-45',
    'barrio': 'MANGA',
    'estrato': 3,
    'tipoPredio': 'APARTAMENTO',
  },
  'servicios': [
    {
      'tipoServicio': 'ENERGIA',
      'empresa': 'AFINIA',
      'identificadorTipo': 'NIC',
      'identificador': '7654321',
      'habitantes': 4,
      'recibos': 2,
      'ultimoPeriodo': '2026-10',
    },
  ],
  'actividad': {'recibos': 2, 'pagados': 1, 'analisis': 3},
};

void main() {
  test('interpreta el perfil que envía Spring Boot', () {
    final perfil = Perfil.fromJson(_respuesta);

    expect(perfil.nombre, 'Ana Pérez');
    expect(perfil.miembroDesde, DateTime(2026, 3, 15));
    expect(perfil.predio!.estrato, 3);
    expect(perfil.predio!.tipoTexto, 'Apartamento');
    expect(perfil.actividad.recibos, 2);
    expect(perfil.actividad.pagados, 1);
    expect(perfil.actividad.analisis, 3);
  });

  test('cada servicio trae los datos de su último recibo escaneado', () {
    final servicios = Perfil.fromJson(_respuesta).servicios;

    expect(servicios, hasLength(1));
    final energia = servicios.single;
    expect(energia.datosEmpresa, Empresa.afinia);
    expect(energia.identificador, '7654321');
    expect(energia.recibos, 2);
    expect(energia.ultimoPeriodo, '2026-10');
    expect(energia.conHabitantes(6).habitantes, 6);
  });

  test('un usuario sin predio ni recibos no rompe el perfil', () {
    final perfil = Perfil.fromJson({
      'nombre': 'Ana',
      'email': 'ana@test.com',
      'miembroDesde': null,
      'predio': null,
      'servicios': [],
      'actividad': {'recibos': 0, 'pagados': 0, 'analisis': 0},
    });

    expect(perfil.predio, isNull);
    expect(perfil.miembroDesde, isNull);
    expect(perfil.servicios, isEmpty);
  });
}
