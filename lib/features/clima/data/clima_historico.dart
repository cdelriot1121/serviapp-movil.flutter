import '../../../core/network/api_client.dart';
import '../../recibos/data/models/recibo.dart';
import 'pronostico.dart';

/// Un día que ya pasó en Cartagena.
class DiaPasado {
  final DateTime fecha;
  final double sensacionMaxima;
  final double lluviaMm;
  final TipoDia tipo;

  const DiaPasado({
    required this.fecha,
    required this.sensacionMaxima,
    required this.lluviaMm,
    required this.tipo,
  });
}

/// El clima de un rango de fechas (el periodo de consumo de un recibo).
class ClimaPeriodo {
  final DateTime inicio;
  final DateTime fin;
  final List<DiaPasado> dias;

  const ClimaPeriodo({
    required this.inicio,
    required this.fin,
    required this.dias,
  });

  double get sensacionPromedio => dias.isEmpty
      ? 0
      : dias.fold<double>(0, (s, d) => s + d.sensacionMaxima) / dias.length;

  int contar(bool Function(TipoDia) cumple) =>
      dias.where((d) => cumple(d.tipo)).length;

  int get calurosos =>
      contar((t) => t == TipoDia.caluroso || t == TipoDia.muyCaluroso);
  int get lluviosos => contar((t) => t == TipoDia.lluvioso);
  int get frescos => contar((t) => t == TipoDia.fresco);
  double get lluviaTotal => dias.fold<double>(0, (s, d) => s + d.lluviaMm);
}

/// Clima de días pasados desde la API histórica de Open-Meteo, que va hasta
/// ayer sin el retraso de varios días de los archivos climáticos.
class ClimaHistorico {
  ClimaHistorico._();

  // El pasado no cambia: lo ya traído sirve mientras la app esté abierta
  static final _dias = <String, DiaPasado>{};

  /// Días entre [inicio] y [fin] (ambos incluidos), sin pasar de ayer.
  static Future<List<DiaPasado>> dias(DateTime inicio, DateTime fin) async {
    final ayer = _soloFecha(DateTime.now()).subtract(const Duration(days: 1));
    final desde = _soloFecha(inicio);
    final hasta = _soloFecha(fin).isAfter(ayer) ? ayer : _soloFecha(fin);
    if (hasta.isBefore(desde)) return const [];

    final fechas = [
      for (var d = desde; !d.isAfter(hasta); d = d.add(const Duration(days: 1))) d,
    ];
    if (fechas.any((f) => !_dias.containsKey(_clave(f)))) {
      await _traer(desde, hasta);
    }
    return [for (final f in fechas) ?_dias[_clave(f)]];
  }

  static Future<ClimaPeriodo> periodo(DateTime inicio, DateTime fin) async =>
      ClimaPeriodo(inicio: inicio, fin: fin, dias: await dias(inicio, fin));

  static Future<void> _traer(DateTime desde, DateTime hasta) async {
    final res = await ApiClient.clima.get<Map<String, dynamic>>(
      'https://historical-forecast-api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': 10.391,
        'longitude': -75.4794,
        'start_date': _clave(desde),
        'end_date': _clave(hasta),
        'daily': 'temperature_2m_max,temperature_2m_min,'
            'apparent_temperature_max,precipitation_sum',
        'timezone': 'America/Bogota',
      },
    );
    final d = res.data!['daily'] as Map<String, dynamic>;
    final tiempos = (d['time'] as List).cast<String>();
    double valor(String campo, int i) =>
        ((d[campo] as List)[i] as num?)?.toDouble() ?? double.nan;

    for (var i = 0; i < tiempos.length; i++) {
      final sensacion = valor('apparent_temperature_max', i);
      if (sensacion.isNaN) continue;
      final lluvia = valor('precipitation_sum', i);
      final dia = ClimaDia(
        fecha: DateTime.parse(tiempos[i]),
        maxima: valor('temperature_2m_max', i),
        minima: valor('temperature_2m_min', i),
        sensacionMaxima: sensacion,
        // Ya pasó: si cayó agua, llovió seguro
        probLluvia: lluvia > 0 ? 100 : 0,
        lluviaMm: lluvia.isNaN ? 0 : lluvia,
      );
      _dias[tiempos[i]] = DiaPasado(
        fecha: dia.fecha,
        sensacionMaxima: sensacion,
        lluviaMm: dia.lluviaMm,
        tipo: dia.tipo,
      );
    }
  }

  static DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

  static String _clave(DateTime f) => Recibo.iso(f)!;
}
