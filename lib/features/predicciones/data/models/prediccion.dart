import '../../../recibos/data/models/recibo.dart';

/// Consumo esperado del mes siguiente según la red neuronal LSTM (FastAPI).
/// Al guardarla, Spring le agrega la categoría según el estrato y, cuando
/// llega el recibo de ese mes, el consumo real.
class Prediccion {
  /// Id en Spring; null si aún no se ha guardado.
  final String? id;
  final Empresa empresa;

  /// Mes estimado en formato YYYY-MM.
  final String periodoEstimado;
  final double consumoEstimado;
  final String unidad;

  /// Consumos reales con los que se calculó, del más antiguo al más reciente.
  final List<ConsumoMensual> historico;
  final int mesesUsados;

  /// null en las predicciones hechas desde la web (otro modelo).
  final String? versionModelo;
  final String? algoritmo;
  final DateTime calculadaEl;

  /// Bajo, Moderado o Elevado frente a un hogar del mismo estrato.
  final String? nivelConsumo;

  /// Consumo de un hogar del mismo estrato y habitantes.
  final double? consumoEsperado;
  final int? estrato;
  final int? habitantes;

  /// Lo que de verdad se consumió ese mes (cuando ya hay recibo).
  final double? consumoReal;

  /// APP o WEB.
  final String origen;

  const Prediccion({
    this.id,
    required this.empresa,
    required this.periodoEstimado,
    required this.consumoEstimado,
    required this.unidad,
    required this.historico,
    required this.mesesUsados,
    required this.versionModelo,
    required this.algoritmo,
    required this.calculadaEl,
    this.nivelConsumo,
    this.consumoEsperado,
    this.estrato,
    this.habitantes,
    this.consumoReal,
    this.origen = 'APP',
  });

  /// Respuesta de FastAPI (POST /api/predicciones/{servicio}).
  factory Prediccion.fromJson(Map<String, dynamic> json) {
    final empresa = _empresa(json['servicio']);

    final siguiente = json['prediccionSiguienteMes'];
    final periodo = siguiente is Map ? siguiente['periodoEstimado']?.toString() : null;
    final consumo = siguiente is Map ? siguiente['consumoEstimado'] : null;
    if (Periodo.parse(periodo) == null || consumo is! num) {
      throw const FormatException('Predicción sin periodo o consumo');
    }
    final modelo = json['metadatosModelo'] is Map
        ? Map<String, dynamic>.from(json['metadatosModelo'] as Map)
        : const <String, dynamic>{};
    final historico = [
      for (final h in (json['historicoAnalizado'] as List? ?? const []))
        if (h is Map && h['periodo'] is String)
          ConsumoMensual.fromJson(Map<String, dynamic>.from(h)),
    ];

    return Prediccion(
      empresa: empresa,
      periodoEstimado: periodo!,
      consumoEstimado: consumo.toDouble(),
      unidad: siguiente['unidad']?.toString() ?? empresa.unidad,
      historico: historico,
      mesesUsados: (json['ventanaUsadaPorModelo'] as num?)?.toInt() ?? historico.length,
      versionModelo: modelo['versionModelo']?.toString() ?? '—',
      algoritmo: modelo['algoritmo']?.toString() ?? 'Red neuronal LSTM',
      calculadaEl: DateTime.now(),
    );
  }

  /// Predicción guardada en Spring (GET/POST /api/mobile/predicciones).
  factory Prediccion.desdeSpring(Map<String, dynamic> json) {
    final empresa = _empresa(json['tipoServicio']);
    final periodo = json['periodoEstimado']?.toString();
    final consumo = json['consumoEstimado'];
    if (Periodo.parse(periodo) == null || consumo is! num) {
      throw const FormatException('Predicción sin periodo o consumo');
    }
    final historico = [
      for (final h in (json['historico'] as List? ?? const []))
        if (h is Map && h['periodo'] is String)
          ConsumoMensual.fromJson(Map<String, dynamic>.from(h)),
    ];
    double? numero(String clave) => (json[clave] as num?)?.toDouble();

    return Prediccion(
      id: json['id']?.toString(),
      empresa: empresa,
      periodoEstimado: periodo!,
      consumoEstimado: consumo.toDouble(),
      unidad: json['unidad']?.toString() ?? empresa.unidad,
      historico: historico,
      mesesUsados: historico.length,
      versionModelo: json['versionModelo']?.toString(),
      algoritmo: json['algoritmo']?.toString(),
      calculadaEl: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      nivelConsumo: json['nivelConsumo']?.toString(),
      consumoEsperado: numero('consumoEsperado'),
      estrato: numero('estrato')?.toInt(),
      habitantes: numero('habitantes')?.toInt(),
      consumoReal: numero('consumoReal'),
      origen: json['origen']?.toString() ?? 'APP',
    );
  }

  static Empresa _empresa(Object? servicio) {
    final empresa = Empresa.values.where((e) => e.tipoServicio == servicio).firstOrNull;
    if (empresa == null) throw FormatException('Servicio desconocido: $servicio');
    return empresa;
  }

  /// Lo que se le envía a Spring para guardarla en el historial.
  Map<String, dynamic> toJson() => {
    'tipoServicio': empresa.tipoServicio,
    'periodoEstimado': periodoEstimado,
    'consumoEstimado': consumoEstimado,
    'versionModelo': versionModelo,
    'algoritmo': algoritmo,
    'historico': [
      for (final h in historico)
        if (h.consumo != null) {'periodo': h.periodo, 'consumo': h.consumo},
    ],
  };

  /// Qué tan cerca estuvo del consumo real (1 = exacto). null sin recibo.
  double? get acierto {
    final real = consumoReal;
    if (real == null || real <= 0) return null;
    return (1 - (consumoEstimado - real).abs() / real).clamp(0.0, 1.0);
  }

  List<double> get _consumos => [
    for (final h in historico)
      if (h.consumo != null) h.consumo!,
  ];

  ConsumoMensual? get ultimoMes => historico.lastOrNull;

  double? get promedio {
    final c = _consumos;
    return c.isEmpty ? null : c.reduce((a, b) => a + b) / c.length;
  }

  ConsumoMensual? get mesMayor => _extremo((a, b) => a > b);
  ConsumoMensual? get mesMenor => _extremo((a, b) => a < b);

  ConsumoMensual? _extremo(bool Function(double, double) gana) {
    ConsumoMensual? mejor;
    for (final h in historico) {
      if (h.consumo == null) continue;
      if (mejor == null || gana(h.consumo!, mejor.consumo!)) mejor = h;
    }
    return mejor;
  }

  /// Cambio de la predicción frente a [base] (0.05 = 5 % más). null sin base.
  double? cambioFrente(double? base) =>
      base == null || base <= 0 ? null : (consumoEstimado - base) / base;
}

/// Historial de predicciones del usuario y su consumo real mes a mes.
class HistorialPredicciones {
  /// De la más reciente a la más antigua.
  final List<Prediccion> predicciones;

  /// Consumo real por servicio (últimos 12 meses, del más antiguo al más reciente).
  final Map<Empresa, List<ConsumoMensual>> consumos;

  const HistorialPredicciones({required this.predicciones, required this.consumos});

  factory HistorialPredicciones.fromJson(Map<String, dynamic> json) {
    final predicciones = <Prediccion>[];
    for (final p in (json['predicciones'] as List? ?? const [])) {
      try {
        predicciones.add(Prediccion.desdeSpring(Map<String, dynamic>.from(p as Map)));
      } on FormatException {
        // Se omite la que llegue incompleta
      }
    }

    final consumos = <Empresa, List<ConsumoMensual>>{};
    for (final s in (json['consumos'] as List? ?? const [])) {
      if (s is! Map) continue;
      final empresa = Empresa.values.where((e) => e.tipoServicio == s['tipoServicio']).firstOrNull;
      if (empresa == null) continue;
      consumos[empresa] = [
        for (final c in (s['consumos'] as List? ?? const []))
          if (c is Map && c['periodo'] is String)
            ConsumoMensual(
              periodo: c['periodo'] as String,
              consumo: (c['consumo'] as num?)?.toDouble(),
            ),
      ];
    }
    return HistorialPredicciones(predicciones: predicciones, consumos: consumos);
  }

  List<Prediccion> de(Empresa? empresa) => empresa == null
      ? predicciones
      : [
          for (final p in predicciones)
            if (p.empresa == empresa) p,
        ];

  /// Acierto promedio de las que ya tienen recibo; null si ninguna.
  static double? aciertoPromedio(List<Prediccion> lista) {
    final aciertos = [
      for (final p in lista)
        if (p.acierto != null) p.acierto!,
    ];
    return aciertos.isEmpty ? null : aciertos.reduce((a, b) => a + b) / aciertos.length;
  }
}

/// Meses de consumo que ServiApp tiene de un servicio, unidos como lo hace
/// Spring antes de entregarlos al modelo: la gráfica de cada recibo más el
/// mes facturado, solo de la cuenta (NIC, póliza o contrato) más reciente.
class HistorialServicio {
  /// El modelo LSTM oficial usa exactamente 5 meses.
  static const mesesRequeridos = 5;

  final Empresa empresa;

  /// Lo exige FastAPI; sale de los recibos guardados del usuario.
  final String? usuarioId;

  /// Periodos YYYY-MM con consumo, del más antiguo al más reciente.
  final List<String> periodos;

  const HistorialServicio({
    required this.empresa,
    required this.usuarioId,
    required this.periodos,
  });

  factory HistorialServicio.de(Empresa empresa, List<Recibo> recibos) {
    final delServicio = [
      for (final r in recibos)
        if (r.empresa == empresa) r,
    ]..sort((a, b) => (b.periodoFacturado ?? '').compareTo(a.periodoFacturado ?? ''));
    if (delServicio.isEmpty) {
      return HistorialServicio(empresa: empresa, usuarioId: null, periodos: const []);
    }

    final cuenta = _cuenta(delServicio.first.identificador);
    final periodos = <String>{};
    for (final r in delServicio) {
      if (_cuenta(r.identificador) != cuenta) continue;
      for (final c in r.historialConsumos) {
        if (c.consumo != null && Periodo.parse(c.periodo) != null) periodos.add(c.periodo);
      }
      if (r.consumoActual != null && Periodo.parse(r.periodoFacturado) != null) {
        periodos.add(r.periodoFacturado!);
      }
    }

    return HistorialServicio(
      empresa: empresa,
      usuarioId: delServicio.first.usuarioId,
      periodos: periodos.toList()..sort(),
    );
  }

  // Spring compara el identificador como número (ignora ceros a la izquierda)
  static String? _cuenta(String? identificador) {
    final limpio = identificador?.trim();
    if (limpio == null || limpio.isEmpty) return null;
    return int.tryParse(limpio)?.toString() ?? limpio;
  }

  int get meses => periodos.length;
  int get faltan => (mesesRequeridos - meses).clamp(0, mesesRequeridos);
  bool get listo => meses >= mesesRequeridos && usuarioId != null;

  /// Mes que se va a predecir: el siguiente al último registrado.
  String? get periodoAPredecir =>
      periodos.isEmpty ? null : Periodo.parse(periodos.last)!.sumar(1).toString();
}
