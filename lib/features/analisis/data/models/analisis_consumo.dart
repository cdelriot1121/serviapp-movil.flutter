import 'package:flutter/material.dart';

import '../../../recibos/data/models/recibo.dart';

/// Análisis de consumo calculado por Spring Boot (mismo cálculo de la web).
/// La app solo lo muestra.
class AnalisisConsumo {
  final String id;
  final String tipoServicio;
  final String? empresaCodigo;
  final String periodoFacturado;
  final String mes;
  final int ano;
  final double consumo;
  final String unidad;
  final int estrato;
  final int habitantes;
  final double consumoEsperado;
  final double tolerancia;
  final double promedioHabitante;
  final double promedioSemanal;
  final String categoria;
  final String comparacionCartagena;
  final bool consumoIrregular;
  final String? tipoIrregularidad;
  final List<String> consejos;
  final DateTime? fechaAnalisis;

  const AnalisisConsumo({
    required this.id,
    required this.tipoServicio,
    required this.empresaCodigo,
    required this.periodoFacturado,
    required this.mes,
    required this.ano,
    required this.consumo,
    required this.unidad,
    required this.estrato,
    required this.habitantes,
    required this.consumoEsperado,
    required this.tolerancia,
    required this.promedioHabitante,
    required this.promedioSemanal,
    required this.categoria,
    required this.comparacionCartagena,
    required this.consumoIrregular,
    required this.tipoIrregularidad,
    required this.consejos,
    required this.fechaAnalisis,
  });

  factory AnalisisConsumo.fromJson(Map<String, dynamic> json) {
    double numero(String clave) => (json[clave] as num?)?.toDouble() ?? 0;
    return AnalisisConsumo(
      id: json['id'] as String,
      tipoServicio: json['tipoServicio'] as String? ?? '',
      empresaCodigo: json['empresa'] as String?,
      periodoFacturado: json['periodoFacturado'] as String? ?? '',
      mes: json['mes'] as String? ?? '',
      ano: (json['ano'] as num?)?.toInt() ?? 0,
      consumo: numero('consumo'),
      unidad: json['unidad'] as String? ?? '',
      estrato: (json['estrato'] as num?)?.toInt() ?? 0,
      habitantes: (json['habitantes'] as num?)?.toInt() ?? 0,
      consumoEsperado: numero('consumoEsperado'),
      tolerancia: numero('tolerancia'),
      promedioHabitante: numero('promedioHabitante'),
      promedioSemanal: numero('promedioSemanal'),
      categoria: json['categoria'] as String? ?? '',
      comparacionCartagena: json['comparacionCartagena'] as String? ?? '',
      consumoIrregular: json['consumoIrregular'] as bool? ?? false,
      tipoIrregularidad: json['tipoIrregularidad'] as String?,
      consejos: [
        for (final c in (json['consejos'] as List?) ?? const []) c.toString(),
      ],
      fechaAnalisis: DateTime.tryParse(json['fechaAnalisis']?.toString() ?? '')?.toLocal(),
    );
  }

  Empresa? get empresa => Empresa.desdeCodigo(empresaCodigo);

  /// "m3" -> "m³"
  String get unidadVisible => unidad == 'm3' ? 'm³' : unidad;

  bool get porEncimaDeCartagena => comparacionCartagena == 'alto';

  Color get colorCategoria => colorDeCategoria(categoria);

  IconData get iconoServicio => empresa?.icono ?? Icons.analytics_outlined;

  Color get colorServicio => empresa?.color ?? const Color(0xFF1E6FD9);
}

/// Colores de la web: verde (Bajo), naranja (Moderado), rojo (Elevado).
Color colorDeCategoria(String categoria) {
  switch (categoria) {
    case 'Bajo':
      return const Color(0xFF27A66B);
    case 'Moderado':
      return const Color(0xFFF59E0B);
    case 'Elevado':
      return const Color(0xFFE5484D);
  }
  return const Color(0xFF607086);
}
