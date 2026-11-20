import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Estado del cielo a partir del código WMO que devuelve Open-Meteo.
enum Cielo {
  despejado,
  pocasNubes,
  parcialmenteNublado,
  nublado,
  neblina,
  llovizna,
  lluvia,
  chubascos,
  tormenta;

  static Cielo deCodigo(int codigo) => switch (codigo) {
        0 => despejado,
        1 => pocasNubes,
        2 => parcialmenteNublado,
        3 => nublado,
        45 || 48 => neblina,
        >= 51 && <= 57 => llovizna,
        >= 80 && <= 82 => chubascos,
        >= 95 => tormenta,
        // 61-67 y los códigos de nieve, que en Cartagena no aplican
        _ => lluvia,
      };

  String descripcion({required bool esDeDia}) => switch (this) {
        despejado => esDeDia ? 'Soleado' : 'Despejado',
        pocasNubes => 'Mayormente despejado',
        parcialmenteNublado => 'Parcialmente nublado',
        nublado => 'Nublado',
        neblina => 'Neblina',
        llovizna => 'Llovizna',
        lluvia => 'Lluvia',
        chubascos => 'Chubascos',
        tormenta => 'Tormenta eléctrica',
      };

  IconData icono({required bool esDeDia}) => switch (this) {
        despejado || pocasNubes =>
          esDeDia ? Icons.wb_sunny_rounded : Icons.nightlight_round,
        parcialmenteNublado =>
          esDeDia ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded,
        nublado => Icons.cloud_rounded,
        neblina => Icons.foggy,
        llovizna => Icons.grain_rounded,
        lluvia || chubascos => Icons.water_drop_rounded,
        tormenta => Icons.thunderstorm_rounded,
      };

  Color color({required bool esDeDia}) => switch (this) {
        despejado || pocasNubes =>
          esDeDia ? AppColors.sun : const Color(0xFF8E9BFF),
        parcialmenteNublado =>
          esDeDia ? const Color(0xFFFFC94D) : const Color(0xFF8E9BFF),
        nublado || neblina => const Color(0xFF9AAEC2),
        llovizna || lluvia || chubascos => AppColors.primary,
        tormenta => const Color(0xFF7C5CFF),
      };
}

class ClimaHora {
  final DateTime hora;
  final double temperatura;
  final int probLluvia;
  final Cielo cielo;
  final bool esDeDia;

  const ClimaHora({
    required this.hora,
    required this.temperatura,
    required this.probLluvia,
    required this.cielo,
    required this.esDeDia,
  });
}

class ClimaActual {
  final DateTime hora;
  final double temperatura;
  final double sensacion;
  final int humedad;
  final Cielo cielo;
  final bool esDeDia;

  const ClimaActual({
    required this.hora,
    required this.temperatura,
    required this.sensacion,
    required this.humedad,
    required this.cielo,
    required this.esDeDia,
  });

  String get descripcion => cielo.descripcion(esDeDia: esDeDia);
  IconData get icono => cielo.icono(esDeDia: esDeDia);
  Color get color => cielo.color(esDeDia: esDeDia);
}

class ClimaDia {
  final DateTime fecha;
  final double maxima;
  final double minima;
  final double sensacionMaxima;
  final int probLluvia;
  final double lluviaMm;

  const ClimaDia({
    required this.fecha,
    required this.maxima,
    required this.minima,
    required this.sensacionMaxima,
    required this.probLluvia,
    required this.lluviaMm,
  });

  TipoDia get tipo => TipoDia.de(this);
}

class Pronostico {
  final ClimaActual actual;
  final ClimaDia hoy;

  /// Próximas horas a partir de la hora actual.
  final List<ClimaHora> horas;

  const Pronostico({
    required this.actual,
    required this.hoy,
    required this.horas,
  });

  factory Pronostico.fromJson(Map<String, dynamic> json) {
    final c = json['current'] as Map<String, dynamic>;
    final actual = ClimaActual(
      hora: DateTime.parse(c['time'] as String),
      temperatura: _num(c['temperature_2m']),
      sensacion: _num(c['apparent_temperature']),
      humedad: _num(c['relative_humidity_2m']).round(),
      cielo: Cielo.deCodigo(_num(c['weather_code']).round()),
      esDeDia: c['is_day'] == 1,
    );

    final d = json['daily'] as Map<String, dynamic>;
    final hoy = ClimaDia(
      fecha: DateTime.parse((d['time'] as List).first as String),
      maxima: _num((d['temperature_2m_max'] as List).first),
      minima: _num((d['temperature_2m_min'] as List).first),
      sensacionMaxima: _num((d['apparent_temperature_max'] as List).first),
      probLluvia: _num((d['precipitation_probability_max'] as List).first).round(),
      lluviaMm: _num((d['precipitation_sum'] as List).first),
    );

    final h = json['hourly'] as Map<String, dynamic>;
    final tiempos = (h['time'] as List).cast<String>();
    // Desde la hora en curso: la de las 10:00 sirve para las 10:45
    final desde = DateTime(
      actual.hora.year,
      actual.hora.month,
      actual.hora.day,
      actual.hora.hour,
    );
    final horas = <ClimaHora>[
      for (var i = 0; i < tiempos.length; i++)
        if (!DateTime.parse(tiempos[i]).isBefore(desde))
          ClimaHora(
            hora: DateTime.parse(tiempos[i]),
            temperatura: _num((h['temperature_2m'] as List)[i]),
            probLluvia: _num((h['precipitation_probability'] as List)[i]).round(),
            cielo: Cielo.deCodigo(_num((h['weather_code'] as List)[i]).round()),
            esDeDia: (h['is_day'] as List)[i] == 1,
          ),
    ];

    return Pronostico(actual: actual, hoy: hoy, horas: horas.take(24).toList());
  }

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
}

/// Cuánto se espera que cambie el consumo de un servicio frente a un día común.
enum Tendencia {
  muchoMas('Mucho más', Icons.keyboard_double_arrow_up_rounded, Color(0xFFE5484D)),
  mas('Más', Icons.arrow_upward_rounded, Color(0xFFF08C00)),
  normal('Normal', Icons.drag_handle_rounded, Color(0xFF607086)),
  menos('Menos', Icons.arrow_downward_rounded, Color(0xFF27A66B));

  final String texto;
  final IconData icono;
  final Color color;

  const Tendencia(this.texto, this.icono, this.color);
}

/// Tipo de día en Cartagena y su efecto en los consumos del hogar.
///
/// Los rangos usan la sensación térmica máxima, que es lo que hace prender el
/// aire o el ventilador. Se calibraron con 92 días de Cartagena (ago–nov 2026):
/// la mediana fue 38.7 °C, el 25 % más fresco quedó bajo 36.7 °C y el 25 % más
/// caluroso sobre 40.4 °C.
enum TipoDia {
  lluvioso(
    titulo: 'Hoy será un día lluvioso',
    icono: Icons.umbrella_rounded,
    colores: [Color(0xFF38B6FF), Color(0xFF3D6FE0)],
    energia: Tendencia.menos,
    agua: Tendencia.menos,
    gas: Tendencia.normal,
    motivo: 'Con la lluvia refresca: el aire y los ventiladores descansan, '
        'y no hace falta regar ni lavar el patio.',
    consejo: 'Aprovecha el agua lluvia para regar las matas o lavar los pisos.',
  ),
  muyCaluroso(
    titulo: 'Hoy será un día muy caluroso',
    icono: Icons.local_fire_department_rounded,
    colores: [Color(0xFFFFB020), Color(0xFFF2552C)],
    energia: Tendencia.muchoMas,
    agua: Tendencia.mas,
    gas: Tendencia.normal,
    motivo: 'El aire acondicionado, los ventiladores y la nevera trabajarán '
        'más, y es probable que te bañes más veces.',
    consejo: 'Pon el aire en 24 °C con puertas y ventanas cerradas: cada '
        'grado menos sube el consumo.',
  ),
  caluroso(
    titulo: 'Hoy será un día caluroso',
    icono: Icons.wb_sunny_rounded,
    colores: [Color(0xFFF6C344), Color(0xFFFF9124)],
    energia: Tendencia.mas,
    agua: Tendencia.mas,
    gas: Tendencia.normal,
    motivo: 'Hará más calor que en un día común: ventiladores y aire '
        'pasarán más tiempo prendidos.',
    consejo: 'Cierra las cortinas en las horas de sol fuerte para que la casa '
        'no se caliente.',
  ),
  normal(
    titulo: 'Hoy será un día típico costeño',
    icono: Icons.wb_cloudy_rounded,
    colores: [Color(0xFF38B6FF), Color(0xFF22B39C)],
    energia: Tendencia.normal,
    agua: Tendencia.normal,
    gas: Tendencia.normal,
    motivo: 'Un día como cualquiera en Cartagena: tus consumos deberían '
        'mantenerse en lo de siempre.',
    consejo: 'Desconecta los cargadores y aparatos que no estés usando.',
  ),
  fresco(
    titulo: 'Hoy será un día fresco',
    icono: Icons.air_rounded,
    colores: [Color(0xFF5FD3C0), Color(0xFF27A66B)],
    energia: Tendencia.menos,
    agua: Tendencia.normal,
    gas: Tendencia.normal,
    motivo: 'Hará menos calor de lo normal: buen día para dejar el aire '
        'apagado y abrir las ventanas.',
    consejo: 'Abre las ventanas y deja que corra la brisa en vez de prender '
        'el aire.',
  );

  final String titulo;
  final IconData icono;
  final List<Color> colores;
  final Tendencia energia;
  final Tendencia agua;
  final Tendencia gas;
  final String motivo;
  final String consejo;

  const TipoDia({
    required this.titulo,
    required this.icono,
    required this.colores,
    required this.energia,
    required this.agua,
    required this.gas,
    required this.motivo,
    required this.consejo,
  });

  static TipoDia de(ClimaDia dia) {
    // Probabilidad sola no basta: con 87 % pueden caer 0.4 mm
    if (dia.probLluvia >= 60 && dia.lluviaMm >= 5) return lluvioso;
    if (dia.sensacionMaxima >= 41 || dia.maxima >= 34) return muyCaluroso;
    if (dia.sensacionMaxima >= 39.5) return caluroso;
    if (dia.sensacionMaxima < 36) return fresco;
    return normal;
  }
}

/// "3 p. m.", como se dice la hora en Colombia.
String formatearHora(DateTime hora) {
  final h = hora.hour % 12 == 0 ? 12 : hora.hour % 12;
  return '$h ${hora.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// Grados sin decimales: 32.6 → "33°".
String grados(double valor) => '${valor.round()}°';
