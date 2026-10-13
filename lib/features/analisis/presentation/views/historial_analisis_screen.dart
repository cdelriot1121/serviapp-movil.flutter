import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/escanear_recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../data/models/analisis_consumo.dart';
import '../../data/services/analisis_service.dart';
import 'analisis_consumo_screen.dart';

/// Historial de análisis de consumo guardado en Spring Boot (MongoDB),
/// con sus consejos personalizados.
class HistorialAnalisisScreen extends StatefulWidget {
  const HistorialAnalisisScreen({super.key});

  @override
  State<HistorialAnalisisScreen> createState() => _HistorialAnalisisScreenState();
}

class _HistorialAnalisisScreenState extends State<HistorialAnalisisScreen> {
  final AnalisisService _service = AnalisisService();

  // null = todos; si no, ENERGIA, AGUA o GAS
  String? _filtro;
  List<AnalisisConsumo>? _analisis;
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
      final analisis = await _service.historial();
      if (mounted) setState(() => _analisis = analisis);
    } on AnalisisException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _analisis = [];
        });
      }
    }
  }

  Future<void> _abrir(AnalisisConsumo analisis) async {
    final eliminado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AnalisisConsumoScreen(analisis: analisis)),
    );
    if (eliminado == true) _cargar();
  }

  Future<void> _escanear() async {
    await iniciarEscaneoRecibo(context);
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Historial de consumos'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: const [BotonInicio()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _escanear,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Escanear'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _chip(null, 'Todos', Icons.all_inbox_rounded, AppColors.primary),
                for (final e in Empresa.values)
                  _chip(e.tipoServicio, e.servicio, e.icono, e.color),
              ],
            ),
          ),
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  Widget _chip(String? tipo, String texto, IconData icono, Color color) {
    final seleccionado = _filtro == tipo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: seleccionado,
        avatar: Icon(icono, size: 18, color: seleccionado ? Colors.white : color),
        label: Text(texto),
        showCheckmark: false,
        selectedColor: color,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filtro = tipo),
      ),
    );
  }

  Widget _buildContenido() {
    final todos = _analisis;
    if (todos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _estadoVacio(Icons.cloud_off_rounded, _error!, accion: 'Reintentar', onAccion: _cargar);
    }

    final analisis = _filtro == null
        ? todos
        : todos.where((a) => a.empresa?.tipoServicio == _filtro).toList();

    if (analisis.isEmpty) {
      return _estadoVacio(
        Icons.insights_rounded,
        _filtro == null
            ? 'Aún no tienes análisis de consumo.\n'
                'Escanea un recibo y analizaremos tu consumo del mes.'
            : 'No tienes análisis de este servicio todavía.',
        accion: 'Escanear recibo',
        onAccion: _escanear,
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: analisis.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TarjetaAnalisis(
          analisis: analisis[i],
          onTap: () => _abrir(analisis[i]),
        ),
      ),
    );
  }

  Widget _estadoVacio(IconData icono, String texto, {required String accion, required VoidCallback onAccion}) {
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

class _TarjetaAnalisis extends StatelessWidget {
  final AnalisisConsumo analisis;
  final VoidCallback onTap;

  const _TarjetaAnalisis({required this.analisis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = analisis.colorServicio;
    final categoria = analisis.colorCategoria;
    final consejos = analisis.consejos.length;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(analisis.iconoServicio, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${analisis.mes} ${analisis.ano}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${analisis.tipoServicio} · ${analisis.habitantes} '
                          '${analisis.habitantes == 1 ? 'habitante' : 'habitantes'} · '
                          'Estrato ${analisis.estrato}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${formatearNumero(analisis.consumo)} ${analisis.unidadVisible}',
                    style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoria.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Consumo ${analisis.categoria}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: categoria),
                    ),
                  ),
                  if (analisis.consumoIrregular) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.orange),
                  ],
                  const Spacer(),
                  const Icon(Icons.lightbulb_outline_rounded, size: 17, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    consejos == 1 ? '1 consejo' : '$consejos consejos',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
