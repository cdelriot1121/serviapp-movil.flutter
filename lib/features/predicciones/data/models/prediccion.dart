import '../../../recibos/data/models/recibo.dart';

/// Respuesta de FastAPI (POST /api/predicciones/{servicio}): consumo esperado
/// del mes siguiente según la red neuronal LSTM y los meses que usó.
class Prediccion {
  final Empresa empresa;

  /// Mes estimado en formato YYYY-MM.
  final String periodoEstimado;
  final double consumoEstimado;
  final String unidad;

  /// Consumos reales con los que se calculó, del más antiguo al más reciente.
  final List<ConsumoMensual> historico;
  final int mesesUsados;
  final String versionModelo;
  final String algoritmo;
  final DateTime calculadaEl;

  const Prediccion({
    required this.empresa,
    required this.periodoEstimado,
    required this.consumoEstimado,
    required this.unidad,
    required this.historico,
    required this.mesesUsados,
    required this.versionModelo,
    required this.algoritmo,
    required this.calculadaEl,
  });

  factory Prediccion.fromJson(Map<String, dynamic> json) {
    final servicio = json['servicio']?.toString();
    final empresa = Empresa.values.where((e) => e.tipoServicio == servicio).firstOrNull;
    if (empresa == null) throw FormatException('Servicio desconocido: $servicio');

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
