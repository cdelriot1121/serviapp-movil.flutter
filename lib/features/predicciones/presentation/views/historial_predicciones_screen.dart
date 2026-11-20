import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../admin/presentation/widgets/graficas.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recibos/presentation/widgets/consumo_chart.dart';
import '../../../recibos/presentation/widgets/filtro_servicios.dart';
import '../../data/models/prediccion.dart';
import '../../data/services/prediccion_service.dart';
import 'predecir_consumo_screen.dart';
import 'prediccion_screen.dart';

/// Predicciones guardadas del usuario junto a su consumo real mes a mes,
/// para ver qué tanto acertó la red neuronal.
class HistorialPrediccionesScreen extends StatefulWidget {
  /// Permite usar datos de prueba en los tests.
  final PrediccionService? servicio;

  const HistorialPrediccionesScreen({super.key, this.servicio});

  @override
  State<HistorialPrediccionesScreen> createState() => _HistorialPrediccionesScreenState();
}

class _HistorialPrediccionesScreenState extends State<HistorialPrediccionesScreen> {
  late final PrediccionService _service = widget.servicio ?? PrediccionService();

  // null = todos; si no, ENERGIA, AGUA o GAS
  String? _filtro;
  HistorialPredicciones? _historial;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final historial = await _service.historial();
      if (mounted) setState(() => _historial = historial);
    } on PrediccionException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _predecir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PredecirConsumoScreen()),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis predicciones'),
        actions: const [BotonInicio()],
      ),
      body: Column(
        children: [
          FiltroServicios(
            seleccionado: _filtro,
            onCambio: (tipo) => setState(() => _filtro = tipo),
          ),
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    final historial = _historial;
    if (historial == null) {
      if (_error == null) return const Center(child: CircularProgressIndicator());
      return _Vacio(
        icono: Icons.cloud_off_rounded,
        texto: _error!,
        accion: 'Reintentar',
        onAccion: _cargar,
      );
    }
    if (historial.predicciones.isEmpty) {
      return _Vacio(
        icono: Icons.auto_graph_rounded,
        texto:
            'Aún no has calculado predicciones.\n'
            'Calcula la primera y aquí podrás compararla con tu consumo real.',
        accion: 'Predecir consumo',
        onAccion: _predecir,
      );
    }

    final empresa = Empresa.values.where((e) => e.tipoServicio == _filtro).firstOrNull;
    final lista = historial.de(empresa);
    final servicios = [
      for (final e in Empresa.values)
        if ((empresa == null || e == empresa) &&
            (historial.de(e).isNotEmpty || (historial.consumos[e]?.isNotEmpty ?? false)))
          e,
    ];

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Resumen(predicciones: lista),
          for (final e in servicios) ...[
            const SizedBox(height: 14),
            _RealVsPrediccion(
              empresa: e,
              consumos: historial.consumos[e] ?? const [],
              predicciones: historial.de(e),
            ),
          ],
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Tus predicciones', style: estiloTitulo(18)),
          ),
          if (lista.isEmpty)
            const SinDatos(texto: 'No hay predicciones de este servicio.')
          else
            for (final p in lista) ...[
              _TarjetaPrediccion(
                prediccion: p,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PrediccionScreen.guardada(p)),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// Cuántas predicciones hay y qué tanto han acertado.
class _Resumen extends StatelessWidget {
  final List<Prediccion> predicciones;

  const _Resumen({required this.predicciones});

  @override
  Widget build(BuildContext context) {
    final acierto = HistorialPredicciones.aciertoPromedio(predicciones);
    final pendientes = predicciones.where((p) => p.consumoReal == null).length;
    final total = predicciones.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.naturaleza,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Consumos predichos',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          NumeroAnimado(valor: total.toDouble(), estilo: estiloTitulo(38, color: Colors.white)),
          Text(
            acierto == null
                ? 'Cuando llegue el recibo de esos meses verás qué tanto acertamos.'
                : 'La red neuronal ha acertado en promedio un ${(acierto * 100).round()} %.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, height: 1.4),
          ),
          if (pendientes > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
              ),
              child: Text(
                pendientes == 1 ? '1 esperando su recibo' : '$pendientes esperando su recibo',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Consumo real de los últimos meses con la marca de lo que se predijo.
class _RealVsPrediccion extends StatelessWidget {
  final Empresa empresa;
  final List<ConsumoMensual> consumos;
  final List<Prediccion> predicciones;

  const _RealVsPrediccion({
    required this.empresa,
    required this.consumos,
    required this.predicciones,
  });

  static const _meses = 7;

  @override
  Widget build(BuildContext context) {
    final reales = {for (final c in consumos) c.periodo: c.consumo};
    // La lista viene de la más reciente a la más antigua: gana la última
    final estimados = <String, double>{};
    for (final p in predicciones) {
      estimados.putIfAbsent(p.periodoEstimado, () => p.consumoEstimado.roundToDouble());
    }
    final periodos = {...reales.keys, ...estimados.keys}.toList()..sort();
    final ultimos = periodos.sublist(periodos.length > _meses ? periodos.length - _meses : 0);

    return TarjetaPanel(
      titulo: '${empresa.servicio} · real y predicho',
      subtitulo: 'Consumo de tus recibos (${empresa.unidad}) y lo que se predijo',
      icono: empresa.icono,
      color: empresa.color,
      child: Column(
        children: [
          ConsumoChart(
            historial: [
              for (final periodo in ultimos) ConsumoMensual(periodo: periodo, consumo: reales[periodo]),
            ],
            estimados: estimados,
            color: empresa.color,
            unidad: empresa.unidad,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              _Leyenda(
                muestra: _muestra(color: empresa.color.withValues(alpha: 0.28)),
                texto: 'Consumo real',
              ),
              _Leyenda(
                muestra: Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                texto: 'Predicción',
              ),
              _Leyenda(
                muestra: _muestra(color: empresa.color.withValues(alpha: 0.08), borde: empresa.color),
                texto: 'Mes por llegar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _muestra({required Color color, Color? borde}) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      border: borde == null ? null : Border.all(color: borde, width: 1.4),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _Leyenda extends StatelessWidget {
  final Widget muestra;
  final String texto;

  const _Leyenda({required this.muestra, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        muestra,
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _TarjetaPrediccion extends StatelessWidget {
  final Prediccion prediccion;
  final VoidCallback onTap;

  const _TarjetaPrediccion({required this.prediccion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = prediccion;
    final empresa = p.empresa;
    final acierto = p.acierto;
    final nivel = p.nivelConsumo;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: empresa.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(empresa.icono, color: empresa.color, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatearPeriodoLargo(p.periodoEstimado),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${empresa.servicio} · calculada el ${formatearFecha(p.calculadaEl)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatearNumero(p.consumoEstimado.roundToDouble())} ${p.unidad}',
                      style: estiloTitulo(16, color: empresa.color),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (nivel != null) _Etiqueta(texto: 'Consumo $nivel', color: ColoresPanel.de(nivel, 0)),
                    if (p.consumoReal != null)
                      _Etiqueta(
                        icono: Icons.check_circle_rounded,
                        texto:
                            'Real ${formatearNumero(p.consumoReal!.roundToDouble())} ${p.unidad}'
                            '${acierto == null ? '' : ' · acierto ${(acierto * 100).round()} %'}',
                        color: AppColors.green,
                      )
                    else
                      const _Etiqueta(
                        icono: Icons.hourglass_top_rounded,
                        texto: 'Esperando tu recibo',
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final IconData? icono;
  final String texto;
  final Color color;

  const _Etiqueta({this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono ?? Icons.circle, size: icono == null ? 8 : 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String accion;
  final VoidCallback onAccion;

  const _Vacio({
    required this.icono,
    required this.texto,
    required this.accion,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onAccion, child: Text(accion)),
          ],
        ),
      ),
    );
  }
}
