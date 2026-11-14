import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../recibos/data/models/recibo.dart';

/// Gestor de ahorros calculado por Spring Boot: cuánto ha ahorrado (o gastado
/// de más) el usuario cada mes frente a su consumo de antes de ServiApp.
/// Los pesos son aproximados. Positivo = ahorro, negativo = gasto de más.
class ResumenAhorro {
  final int ahorroTotal;
  final String? ultimoPeriodo;
  final int? ahorroUltimoMes;
  final int rachaMeses;
  final String? mejorPeriodo;
  final int? mejorAhorro;
  final int mesesEvaluados;
  final int mesesConAhorro;
  final List<AhorroMes> meses;
  final List<AhorroServicio> servicios;

  const ResumenAhorro({
    required this.ahorroTotal,
    required this.ultimoPeriodo,
    required this.ahorroUltimoMes,
    required this.rachaMeses,
    required this.mejorPeriodo,
    required this.mejorAhorro,
    required this.mesesEvaluados,
    required this.mesesConAhorro,
    required this.meses,
    required this.servicios,
  });

  factory ResumenAhorro.fromJson(Map<String, dynamic> json) => ResumenAhorro(
    ahorroTotal: _entero(json['ahorroTotal']) ?? 0,
    ultimoPeriodo: json['ultimoPeriodo'] as String?,
    ahorroUltimoMes: _entero(json['ahorroUltimoMes']),
    rachaMeses: _entero(json['rachaMeses']) ?? 0,
    mejorPeriodo: json['mejorPeriodo'] as String?,
    mejorAhorro: _entero(json['mejorAhorro']),
    mesesEvaluados: _entero(json['mesesEvaluados']) ?? 0,
    mesesConAhorro: _entero(json['mesesConAhorro']) ?? 0,
    meses: [
      for (final m in (json['meses'] as List? ?? const []))
        AhorroMes.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    servicios: [
      for (final s in (json['servicios'] as List? ?? const []))
        AhorroServicio.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );

  /// Ya hay al menos un mes comparado con el de antes de ServiApp.
  bool get tieneComparaciones => mesesEvaluados > 0;
}

/// Total de un mes sumando todos los servicios.
class AhorroMes {
  final String periodo;
  final int ahorro;
  final int servicios;

  const AhorroMes({
    required this.periodo,
    required this.ahorro,
    required this.servicios,
  });

  factory AhorroMes.fromJson(Map<String, dynamic> json) => AhorroMes(
    periodo: json['periodo'] as String? ?? '',
    ahorro: _entero(json['ahorro']) ?? 0,
    servicios: _entero(json['servicios']) ?? 0,
  );
}

/// Ahorro de un servicio (agua, energía o gas).
class AhorroServicio {
  final String tipoServicio;
  final String empresaCodigo;
  final String identificador;
  final String unidad;
  final String inicio;
  final double lineaBase;
  final int mesesLineaBase;
  final double? precioUnidad;
  final int ahorroTotal;
  final double ahorroConsumo;
  final int mesesConAhorro;
  final double? consumoMesAnterior;
  final double? variacionMesAnterior;
  final List<MesServicio> meses;
  final List<PuntoConsumo> historial;

  const AhorroServicio({
    required this.tipoServicio,
    required this.empresaCodigo,
    required this.identificador,
    required this.unidad,
    required this.inicio,
    required this.lineaBase,
    required this.mesesLineaBase,
    required this.precioUnidad,
    required this.ahorroTotal,
    required this.ahorroConsumo,
    required this.mesesConAhorro,
    required this.consumoMesAnterior,
    required this.variacionMesAnterior,
    required this.meses,
    required this.historial,
  });

  factory AhorroServicio.fromJson(Map<String, dynamic> json) => AhorroServicio(
    tipoServicio: json['tipoServicio'] as String? ?? '',
    empresaCodigo: json['empresa'] as String? ?? '',
    identificador: json['identificador'] as String? ?? '',
    unidad: json['unidad'] as String? ?? '',
    inicio: json['inicio'] as String? ?? '',
    lineaBase: _decimal(json['lineaBase']) ?? 0,
    mesesLineaBase: _entero(json['mesesLineaBase']) ?? 0,
    precioUnidad: _decimal(json['precioUnidad']),
    ahorroTotal: _entero(json['ahorroTotal']) ?? 0,
    ahorroConsumo: _decimal(json['ahorroConsumo']) ?? 0,
    mesesConAhorro: _entero(json['mesesConAhorro']) ?? 0,
    consumoMesAnterior: _decimal(json['consumoMesAnterior']),
    variacionMesAnterior: _decimal(json['variacionMesAnterior']),
    meses: [
      for (final m in (json['meses'] as List? ?? const []))
        MesServicio.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    historial: [
      for (final p in (json['historial'] as List? ?? const []))
        PuntoConsumo.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
  );

  Empresa? get empresa => Empresa.desdeCodigo(empresaCodigo);

  String get nombre => empresa?.servicio ?? tipoServicio;

  IconData get icono => empresa?.icono ?? Icons.savings_rounded;

  Color get color => empresa?.color ?? AppColors.primary;

  /// "m3" -> "m³"
  String get unidadVisible => unidad == 'm3' ? 'm³' : unidad;

  MesServicio? get ultimoMes => meses.isEmpty ? null : meses.last;

  /// Consumo del último recibo (aunque aún no tenga meses comparados).
  double? get consumoActual =>
      historial.isEmpty ? null : historial.last.consumo;
}

/// Un mes de un servicio comparado con la línea base.
class MesServicio {
  final String periodo;
  final double consumo;

  /// FACTURADO (mes del recibo) o GRAFICA (leído de la gráfica de otro recibo).
  final String fuente;
  final int? valorTotal;
  final double diferencia;
  final double porcentaje;
  final int ahorro;
  final EstadoAhorro estado;

  const MesServicio({
    required this.periodo,
    required this.consumo,
    required this.fuente,
    required this.valorTotal,
    required this.diferencia,
    required this.porcentaje,
    required this.ahorro,
    required this.estado,
  });

  factory MesServicio.fromJson(Map<String, dynamic> json) => MesServicio(
    periodo: json['periodo'] as String? ?? '',
    consumo: _decimal(json['consumo']) ?? 0,
    fuente: json['fuente'] as String? ?? '',
    valorTotal: _entero(json['valorTotal']),
    diferencia: _decimal(json['diferencia']) ?? 0,
    porcentaje: _decimal(json['porcentaje']) ?? 0,
    ahorro: _entero(json['ahorro']) ?? 0,
    estado: EstadoAhorro.desdeCodigo(json['estado'] as String?),
  );
}

class PuntoConsumo {
  final String periodo;
  final double consumo;
  final bool antesDeServiApp;

  const PuntoConsumo({
    required this.periodo,
    required this.consumo,
    required this.antesDeServiApp,
  });

  factory PuntoConsumo.fromJson(Map<String, dynamic> json) => PuntoConsumo(
    periodo: json['periodo'] as String? ?? '',
    consumo: _decimal(json['consumo']) ?? 0,
    antesDeServiApp: json['antesDeServiApp'] as bool? ?? false,
  );
}

/// Semáforo del mes: verde si ahorró, sol si quedó igual, rojo si gastó de más.
enum EstadoAhorro {
  ahorro('AHORRO', 'Ahorraste', Icons.trending_down_rounded, AppColors.green),
  estable(
    'ESTABLE',
    'Igual que antes',
    Icons.trending_flat_rounded,
    Color(0xFFE08A00),
  ),
  exceso('EXCESO', 'Gastaste de más', Icons.trending_up_rounded, AppColors.red);

  const EstadoAhorro(this.codigo, this.etiqueta, this.icono, this.color);

  final String codigo;
  final String etiqueta;
  final IconData icono;
  final Color color;

  static EstadoAhorro desdeCodigo(String? codigo) =>
      EstadoAhorro.values.firstWhere(
        (e) => e.codigo == codigo,
        orElse: () => EstadoAhorro.estable,
      );

  /// Estado de un total en pesos (para los meses que suman varios servicios).
  static EstadoAhorro dePesos(int pesos) => pesos > 0
      ? EstadoAhorro.ahorro
      : pesos < 0
      ? EstadoAhorro.exceso
      : EstadoAhorro.estable;
}

int? _entero(dynamic valor) => (valor as num?)?.round();

double? _decimal(dynamic valor) => (valor as num?)?.toDouble();
