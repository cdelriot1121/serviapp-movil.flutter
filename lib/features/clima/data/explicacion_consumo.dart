import 'dart:math' as math;

import '../../recibos/data/models/recibo.dart';
import '../../recibos/data/services/recibo_service.dart';
import '../../recibos/presentation/utils/formatos.dart';
import 'clima_historico.dart';

/// Qué pesó más en el cambio de consumo frente al periodo anterior.
enum Causa { estable, clima, dias, hogar }

/// Rango de fechas que cubre un recibo.
typedef RangoConsumo = ({DateTime inicio, DateTime fin, int? dias});

/// "¿Por qué subió mi recibo?": compara el consumo con el periodo anterior y
/// separa lo que se debe a los días cobrados, al clima y a lo demás (hábitos,
/// aparatos nuevos, visitas, fugas).
class ExplicacionConsumo {
  final Recibo recibo;
  final double consumoActual;
  final double consumoAnterior;
  final String periodoAnterior;
  final int? diasActual;
  final int? diasAnterior;

  /// Diferencia en pesos, solo si el recibo anterior está guardado.
  final int? diferenciaPesos;

  final ClimaPeriodo climaActual;
  final ClimaPeriodo climaAnterior;

  /// Cuánto sube el consumo (fracción) por cada grado más de sensación térmica.
  final double sensibilidad;

  /// Meses de este hogar con los que se calculó [sensibilidad] (0 = estimado
  /// general para Cartagena).
  final int mesesPropios;

  const ExplicacionConsumo._({
    required this.recibo,
    required this.consumoActual,
    required this.consumoAnterior,
    required this.periodoAnterior,
    required this.diasActual,
    required this.diasAnterior,
    required this.diferenciaPesos,
    required this.climaActual,
    required this.climaAnterior,
    required this.sensibilidad,
    required this.mesesPropios,
  });

  Empresa get empresa => recibo.empresa;

  /// Cambio total del consumo (0.18 = 18 % más).
  double get cambio => consumoActual / consumoAnterior - 1;

  double get diferenciaSensacion =>
      climaActual.sensacionPromedio - climaAnterior.sensacionPromedio;

  /// Parte del cambio que viene solo de cobrar más o menos días.
  double get efectoDias => diasActual != null && diasAnterior != null && diasAnterior! > 0
      ? diasActual! / diasAnterior! - 1
      : 0;

  /// Parte del cambio que se explica por el calor o el fresco.
  double get efectoClima => (sensibilidad * diferenciaSensacion).clamp(-0.4, 0.4);

  /// Lo que queda: hábitos, aparatos, visitas o una posible fuga.
  double get efectoHogar => cambio - efectoDias - efectoClima;

  bool get subio => cambio > 0;

  Causa get causa {
    if (cambio.abs() < 0.05) return Causa.estable;
    // La causa que más empuja hacia el mismo lado del cambio
    final aporte = {
      Causa.dias: efectoDias * cambio.sign,
      Causa.clima: efectoClima * cambio.sign,
      Causa.hogar: efectoHogar * cambio.sign,
    };
    return aporte.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  String get titulo => switch ((causa, subio)) {
        (Causa.estable, _) => 'Tu consumo se mantuvo',
        (Causa.clima, true) => 'Subió por el calor',
        (Causa.clima, false) => 'Bajó gracias al clima',
        (Causa.dias, true) => 'Subió porque te cobraron más días',
        (Causa.dias, false) => 'Bajó porque te cobraron menos días',
        (Causa.hogar, true) => 'No fue el clima: algo cambió en casa',
        (Causa.hogar, false) => '¡Lo bajaste tú!',
      };

  String get resumen {
    final unidad = empresa.unidad;
    final servicio = empresa.servicio.toLowerCase();
    final base = 'Gastaste ${formatearNumero(_redondear(consumoActual))} $unidad '
        'de $servicio, y en ${formatearPeriodoLargo(periodoAnterior).toLowerCase()}, '
        '${formatearNumero(_redondear(consumoAnterior))} $unidad.';

    final sensacion = '${climaActual.sensacionPromedio.toStringAsFixed(1)} °C';
    final antes = '${climaAnterior.sensacionPromedio.toStringAsFixed(1)} °C';

    return switch ((causa, subio)) {
      (Causa.estable, _) =>
        '$base Una diferencia tan pequeña es normal de un mes a otro.',
      (Causa.clima, true) =>
        '$base El periodo fue más caluroso: la sensación térmica promedio fue '
            'de $sensacion, y la del anterior de $antes.',
      (Causa.clima, false) =>
        '$base El periodo fue más fresco: la sensación térmica promedio bajó '
            'de $antes a $sensacion.',
      (Causa.dias, _) =>
        '$base Este recibo cobra $diasActual días y el anterior $diasAnterior: '
            'por día gastaste casi lo mismo.',
      (Causa.hogar, true) =>
        '$base El clima no alcanza a explicar ese aumento. Puede ser un aparato '
            'nuevo, más gente en casa o una fuga.',
      (Causa.hogar, false) =>
        '$base El clima no explica esa baja: fueron tus hábitos. ¡Sigue así!',
    };
  }

  /// Qué revisar según el servicio y la causa.
  String get consejo => switch ((empresa, causa, subio)) {
        (_, Causa.estable, _) =>
          'Revisa cada mes este resumen para notar a tiempo si algo cambia.',
        (Empresa.afinia, Causa.clima, true) =>
          'Pon el aire en 24 °C con puertas y ventanas cerradas: cada grado '
              'más frío hace trabajar más al aparato.',
        (Empresa.aguasDeCartagena, Causa.clima, true) =>
          'Con el calor nos bañamos más veces: cierra la llave mientras te '
              'enjabonas y acorta un poco cada ducha.',
        (_, Causa.dias, _) =>
          'La empresa no siempre lee el contador el mismo día: compara el '
              'consumo por día y no el total.',
        (Empresa.aguasDeCartagena, Causa.hogar, true) =>
          'Cierra todas las llaves y mira el contador por 30 minutos: si se '
              'mueve, hay una fuga.',
        (Empresa.afinia, Causa.hogar, true) =>
          'Revisa la nevera (que cierre bien el empaque) y los aparatos que '
              'quedan conectados toda la noche.',
        (Empresa.surtigas, Causa.hogar, true) =>
          'Usa tapa en las ollas y llama a Surtigas si sientes olor a gas: '
              'puede haber una fuga.',
        (_, _, false) => 'Lo que estás haciendo funciona: mantén esos hábitos.',
        _ => 'Mira el análisis de consumo para compararte con hogares como el tuyo.',
      };

  static double _redondear(double v) => (v * 100).round() / 100;

  // -------------------------------------------------------------- cálculo

  /// Estimado de cuánto sube el consumo por grado cuando el hogar no tiene
  /// historial suficiente: la energía depende del aire y los ventiladores, el
  /// agua un poco de las duchas y el gas (sobre todo cocina) casi nada.
  static double _sensibilidadGeneral(Empresa e) => switch (e) {
        Empresa.afinia => 0.05,
        Empresa.aguasDeCartagena => 0.02,
        Empresa.surtigas => 0,
      };

  static final _cache = <String, ExplicacionConsumo?>{};

  /// Explicación del recibo, o null si no hay un periodo anterior con qué
  /// compararlo o no se pudo traer el clima.
  static Future<ExplicacionConsumo?> de(Recibo recibo) async {
    final clave = '${recibo.id}-${recibo.consumoActual}';
    if (_cache.containsKey(clave)) return _cache[clave];

    try {
      return _cache[clave] = await _calcular(recibo);
    } catch (_) {
      // Sin internet o sin datos: no se guarda para intentar de nuevo luego
      return null;
    }
  }

  static Future<ExplicacionConsumo?> _calcular(Recibo recibo) async {
    final actual = recibo.consumoActual;
    final rangoActual = rango(recibo);
    if (actual == null || actual <= 0 || rangoActual == null) return null;

    final anterior = await _anterior(recibo, rangoActual);
    if (anterior == null) return null;

    final climas = await Future.wait([
      ClimaHistorico.periodo(rangoActual.inicio, rangoActual.fin),
      ClimaHistorico.periodo(anterior.rango.inicio, anterior.rango.fin),
    ]);
    if (climas.any((c) => c.dias.isEmpty)) return null;

    final propia = await _sensibilidadPropia(recibo);

    return ExplicacionConsumo._(
      recibo: recibo,
      consumoActual: actual,
      consumoAnterior: anterior.consumo,
      periodoAnterior: anterior.periodo,
      diasActual: rangoActual.dias,
      diasAnterior: anterior.rango.dias,
      diferenciaPesos: anterior.valor != null && recibo.valorTotal != null
          ? recibo.valorTotal! - anterior.valor!
          : null,
      climaActual: climas[0],
      climaAnterior: climas[1],
      sensibilidad: propia?.valor ?? _sensibilidadGeneral(recibo.empresa),
      mesesPropios: propia?.meses ?? 0,
    );
  }

  /// Fechas de consumo del recibo. Si faltan, se deducen de los días
  /// facturados, la emisión o el mes facturado.
  static RangoConsumo? rango(Recibo r) {
    var inicio = r.periodoInicio;
    var fin = r.periodoFin;
    final dias = r.diasFacturados ??
        (inicio != null && fin != null ? fin.difference(inicio).inDays + 1 : null);

    if (fin == null && inicio != null && dias != null) {
      fin = inicio.add(Duration(days: dias - 1));
    }
    // El recibo sale unos días después de leer el contador
    fin ??= r.fechaEmision?.subtract(const Duration(days: 3));
    if (fin == null) {
      final p = Periodo.parse(r.periodoFacturado);
      if (p == null) return null;
      inicio ??= DateTime(p.anio, p.mes);
      fin = DateTime(p.anio, p.mes + 1, 0);
    }
    inicio ??= fin.subtract(Duration(days: (dias ?? 30) - 1));
    return (inicio: inicio, fin: fin, dias: dias);
  }

  /// El recibo anterior guardado o, si no está, el mes anterior del
  /// historial que trae impreso el propio recibo.
  static Future<
      ({double consumo, String periodo, RangoConsumo rango, int? valor})?> _anterior(
    Recibo recibo,
    RangoConsumo rangoActual,
  ) async {
    final periodo = Periodo.parse(recibo.periodoFacturado);

    if (periodo != null) {
      final buscado = periodo.sumar(-1).toString();
      try {
        final guardados = await ReciboService().listar(
          tipoServicio: recibo.empresa.tipoServicio,
        );
        for (final r in guardados) {
          final mismoPredio = recibo.identificador == null ||
              r.identificador == null ||
              r.identificador == recibo.identificador;
          final rangoAnterior = rango(r);
          if (r.empresa == recibo.empresa &&
              mismoPredio &&
              r.periodoFacturado == buscado &&
              (r.consumoActual ?? 0) > 0 &&
              rangoAnterior != null) {
            return (
              consumo: r.consumoActual!,
              periodo: buscado,
              rango: rangoAnterior,
              valor: r.valorTotal,
            );
          }
        }
      } on ReciboException {
        // Se sigue con el historial impreso
      }
    }

    // Historial del recibo: el mes con consumo justo antes del actual
    final historial = _historialOrdenado(recibo);
    final iActual = historial.lastIndexWhere((c) => c.$1.esActual);
    final hasta = iActual >= 0 ? iActual : historial.length;
    for (var i = hasta - 1; i >= 0; i--) {
      final (c, p) = historial[i];
      if ((c.consumo ?? 0) <= 0) continue;
      // Mismo largo que el periodo actual, justo antes de él
      final largo = rangoActual.fin.difference(rangoActual.inicio).inDays;
      final fin = rangoActual.inicio.subtract(const Duration(days: 1));
      return (
        consumo: c.consumo!,
        periodo: p.toString(),
        rango: (inicio: fin.subtract(Duration(days: largo)), fin: fin, dias: null),
        valor: null,
      );
    }
    return null;
  }

  static List<(ConsumoMensual, Periodo)> _historialOrdenado(Recibo r) => [
        for (final c in r.historialConsumos)
          if (Periodo.parse(c.periodo) case final p?) (c, p),
      ]..sort((a, b) => a.$2.compareTo(b.$2));

  /// Sensibilidad al calor de este hogar con su propio historial: compara el
  /// consumo de cada mes con la sensación térmica de ese mes. Solo se usa si
  /// la relación es clara; si no, queda el estimado general.
  static Future<({double valor, int meses})?> _sensibilidadPropia(Recibo r) async {
    if (r.empresa == Empresa.surtigas) return null;

    final meses = [
      for (final (c, p) in _historialOrdenado(r))
        if ((c.consumo ?? 0) > 0) (consumo: c.consumo!, periodo: p),
    ];
    if (meses.length < 5) return null;

    final primero = meses.first.periodo;
    final ultimo = meses.last.periodo;
    final dias = await ClimaHistorico.dias(
      DateTime(primero.anio, primero.mes),
      DateTime(ultimo.anio, ultimo.mes + 1, 0),
    );

    final x = <double>[], y = <double>[];
    for (final m in meses) {
      final delMes = [
        for (final d in dias)
          if (d.fecha.year == m.periodo.anio && d.fecha.month == m.periodo.mes)
            d.sensacionMaxima,
      ];
      if (delMes.length < 20) continue;
      x.add(delMes.reduce((a, b) => a + b) / delMes.length);
      y.add(m.consumo);
    }
    if (x.length < 5) return null;

    final n = x.length;
    final mx = x.reduce((a, b) => a + b) / n;
    final my = y.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (x[i] - mx) * (y[i] - my);
      sxx += (x[i] - mx) * (x[i] - mx);
      syy += (y[i] - my) * (y[i] - my);
    }
    // Hace falta que el clima haya variado y que el consumo lo siga
    if (sxx / n < 0.25 || syy == 0) return null;
    final correlacion = sxy / math.sqrt(sxx * syy);
    final valor = (sxy / sxx) / my;
    if (correlacion < 0.5 || valor <= 0 || valor > 0.15) return null;
    return (valor: valor, meses: n);
  }
}
