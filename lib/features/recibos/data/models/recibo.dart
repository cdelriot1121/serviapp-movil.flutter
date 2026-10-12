import 'package:flutter/material.dart';

/// Empresas soportadas por el escáner de recibos.
enum Empresa {
  afinia(
    codigo: 'AFINIA',
    nombre: 'Afinia',
    tipoServicio: 'ENERGIA',
    servicio: 'Energía',
    identificador: 'NIC',
    unidad: 'kWh',
    icono: Icons.bolt_rounded,
    color: Color(0xFFF59E0B),
  ),
  aguasDeCartagena(
    codigo: 'AGUAS_DE_CARTAGENA',
    nombre: 'Aguas de Cartagena',
    tipoServicio: 'AGUA',
    servicio: 'Agua',
    identificador: 'Póliza',
    unidad: 'm³',
    icono: Icons.water_drop_rounded,
    color: Color(0xFF1E6FD9),
  ),
  surtigas(
    codigo: 'SURTIGAS',
    nombre: 'Surtigas',
    tipoServicio: 'GAS',
    servicio: 'Gas',
    identificador: 'Contrato',
    unidad: 'm³',
    icono: Icons.local_fire_department_rounded,
    color: Color(0xFFE5484D),
  );

  const Empresa({
    required this.codigo,
    required this.nombre,
    required this.tipoServicio,
    required this.servicio,
    required this.identificador,
    required this.unidad,
    required this.icono,
    required this.color,
  });

  final String codigo;
  final String nombre;
  final String tipoServicio;
  final String servicio;
  final String identificador;
  final String unidad;
  final IconData icono;
  final Color color;

  static Empresa? desdeCodigo(String? codigo) {
    for (final empresa in Empresa.values) {
      if (empresa.codigo == codigo) return empresa;
    }
    return null;
  }
}

/// Mes en formato YYYY-MM.
class Periodo implements Comparable<Periodo> {
  final int anio;
  final int mes;

  const Periodo(this.anio, this.mes);

  static Periodo? parse(String? texto) {
    if (texto == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(texto);
    if (m == null) return null;
    final mes = int.parse(m.group(2)!);
    if (mes < 1 || mes > 12) return null;
    return Periodo(int.parse(m.group(1)!), mes);
  }

  Periodo sumar(int meses) {
    final total = anio * 12 + (mes - 1) + meses;
    return Periodo(total ~/ 12, total % 12 + 1);
  }

  @override
  String toString() =>
      '${anio.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.anio == anio && other.mes == mes;

  @override
  int get hashCode => anio * 12 + mes;

  @override
  int compareTo(Periodo other) => (anio * 12 + mes) - (other.anio * 12 + other.mes);
}

class ConsumoMensual {
  final String periodo;
  final double? consumo;
  final bool esActual;

  const ConsumoMensual({
    required this.periodo,
    this.consumo,
    this.esActual = false,
  });

  factory ConsumoMensual.fromJson(Map<String, dynamic> json) => ConsumoMensual(
        periodo: json['periodo'] as String,
        consumo: (json['consumo'] as num?)?.toDouble(),
        esActual: json['esActual'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'periodo': periodo,
        'consumo': consumo,
        'esActual': esActual,
      };
}

class ConceptoValor {
  final String concepto;
  final int valor;

  const ConceptoValor({required this.concepto, required this.valor});

  factory ConceptoValor.fromJson(Map<String, dynamic> json) => ConceptoValor(
        concepto: json['concepto'] as String,
        valor: (json['valor'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'concepto': concepto, 'valor': valor};
}

/// Datos de un recibo. Mismo formato en FastAPI (análisis) y Spring (guardado).
class Recibo {
  final String? id;
  final Empresa empresa;
  final String? identificador;
  final String? numeroFactura;
  final String? titular;
  final String? direccion;
  final String? barrio;
  final int? estrato;
  final String? periodoFacturado;
  final DateTime? periodoInicio;
  final DateTime? periodoFin;
  final DateTime? fechaEmision;
  final DateTime? fechaLimitePago;
  final DateTime? fechaSuspension;
  final int? valorTotal;
  final double? consumoActual;
  final double? lecturaAnterior;
  final double? lecturaActual;
  final int? diasFacturados;
  final List<ConsumoMensual> historialConsumos;
  final List<ConceptoValor> conceptos;
  final DateTime? fechaEscaneo;

  /// Lo marca el usuario en la app o con el botón de la notificación.
  final bool pagado;
  final DateTime? fechaPago;

  const Recibo({
    this.id,
    required this.empresa,
    this.identificador,
    this.numeroFactura,
    this.titular,
    this.direccion,
    this.barrio,
    this.estrato,
    this.periodoFacturado,
    this.periodoInicio,
    this.periodoFin,
    this.fechaEmision,
    this.fechaLimitePago,
    this.fechaSuspension,
    this.valorTotal,
    this.consumoActual,
    this.lecturaAnterior,
    this.lecturaActual,
    this.diasFacturados,
    this.historialConsumos = const [],
    this.conceptos = const [],
    this.fechaEscaneo,
    this.pagado = false,
    this.fechaPago,
  });

  factory Recibo.fromJson(Map<String, dynamic> json) {
    final empresa = Empresa.desdeCodigo(json['empresa'] as String?);
    if (empresa == null) {
      throw FormatException('Empresa desconocida: ${json['empresa']}');
    }
    final identificador = json['identificador'] as Map<String, dynamic>?;
    return Recibo(
      id: json['id'] as String?,
      empresa: empresa,
      identificador: identificador?['valor'] as String?,
      numeroFactura: json['numeroFactura'] as String?,
      titular: json['titular'] as String?,
      direccion: json['direccion'] as String?,
      barrio: json['barrio'] as String?,
      estrato: (json['estrato'] as num?)?.toInt(),
      periodoFacturado: json['periodoFacturado'] as String?,
      periodoInicio: _fecha(json['periodoInicio']),
      periodoFin: _fecha(json['periodoFin']),
      fechaEmision: _fecha(json['fechaEmision']),
      fechaLimitePago: _fecha(json['fechaLimitePago']),
      fechaSuspension: _fecha(json['fechaSuspension']),
      valorTotal: (json['valorTotal'] as num?)?.toInt(),
      consumoActual: (json['consumoActual'] as num?)?.toDouble(),
      lecturaAnterior: (json['lecturaAnterior'] as num?)?.toDouble(),
      lecturaActual: (json['lecturaActual'] as num?)?.toDouble(),
      diasFacturados: (json['diasFacturados'] as num?)?.toInt(),
      historialConsumos: [
        for (final c in (json['historialConsumos'] as List? ?? const []))
          ConsumoMensual.fromJson(c as Map<String, dynamic>),
      ],
      conceptos: [
        for (final c in (json['conceptos'] as List? ?? const []))
          ConceptoValor.fromJson(c as Map<String, dynamic>),
      ],
      fechaEscaneo: json['fechaEscaneo'] != null
          ? DateTime.tryParse(json['fechaEscaneo'] as String)?.toLocal()
          : null,
      pagado: json['pagado'] as bool? ?? false,
      fechaPago: _fecha(json['fechaPago']),
    );
  }

  /// Copia del recibo con otro estado de pago.
  Recibo conPago({required bool pagado, DateTime? fechaPago}) => Recibo(
        id: id,
        empresa: empresa,
        identificador: identificador,
        numeroFactura: numeroFactura,
        titular: titular,
        direccion: direccion,
        barrio: barrio,
        estrato: estrato,
        periodoFacturado: periodoFacturado,
        periodoInicio: periodoInicio,
        periodoFin: periodoFin,
        fechaEmision: fechaEmision,
        fechaLimitePago: fechaLimitePago,
        fechaSuspension: fechaSuspension,
        valorTotal: valorTotal,
        consumoActual: consumoActual,
        lecturaAnterior: lecturaAnterior,
        lecturaActual: lecturaActual,
        diasFacturados: diasFacturados,
        historialConsumos: historialConsumos,
        conceptos: conceptos,
        fechaEscaneo: fechaEscaneo,
        pagado: pagado,
        fechaPago: pagado ? fechaPago : null,
      );

  Map<String, dynamic> toJson() => {
        'tipoServicio': empresa.tipoServicio,
        'empresa': empresa.codigo,
        'identificador': {
          'tipo': empresa == Empresa.afinia
              ? 'NIC'
              : empresa == Empresa.aguasDeCartagena
                  ? 'POLIZA'
                  : 'CONTRATO',
          'valor': identificador,
        },
        'numeroFactura': numeroFactura,
        'titular': titular,
        'direccion': direccion,
        'barrio': barrio,
        'estrato': estrato,
        'periodoFacturado': periodoFacturado,
        'periodoInicio': iso(periodoInicio),
        'periodoFin': iso(periodoFin),
        'fechaEmision': iso(fechaEmision),
        'fechaLimitePago': iso(fechaLimitePago),
        'fechaSuspension': iso(fechaSuspension),
        'valorTotal': valorTotal,
        'unidadConsumo': empresa == Empresa.afinia ? 'kWh' : 'm3',
        'consumoActual': consumoActual,
        'lecturaAnterior': lecturaAnterior,
        'lecturaActual': lecturaActual,
        'diasFacturados': diasFacturados,
        'historialConsumos': [for (final c in historialConsumos) c.toJson()],
        'conceptos': [for (final c in conceptos) c.toJson()],
      };

  static DateTime? _fecha(dynamic valor) =>
      valor is String ? DateTime.tryParse(valor) : null;

  static String? iso(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year.toString().padLeft(4, '0')}-'
          '${fecha.month.toString().padLeft(2, '0')}-'
          '${fecha.day.toString().padLeft(2, '0')}';
}

/// Respuesta de FastAPI al analizar una foto.
class ResultadoAnalisis {
  final Recibo recibo;
  final Map<String, double> confianza;
  final List<String> camposFaltantes;
  final List<String> advertencias;
  final String versionExtractor;

  const ResultadoAnalisis({
    required this.recibo,
    required this.confianza,
    required this.camposFaltantes,
    required this.advertencias,
    required this.versionExtractor,
  });

  factory ResultadoAnalisis.fromJson(Map<String, dynamic> json) =>
      ResultadoAnalisis(
        recibo: Recibo.fromJson(json['recibo'] as Map<String, dynamic>),
        confianza: {
          for (final e in (json['confianza'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        camposFaltantes: List<String>.from(json['camposFaltantes'] ?? const []),
        advertencias: List<String>.from(json['advertencias'] ?? const []),
        versionExtractor: json['versionExtractor'] as String? ?? '',
      );
}
