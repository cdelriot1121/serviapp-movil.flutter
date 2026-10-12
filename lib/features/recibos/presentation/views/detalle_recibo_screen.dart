import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';
import '../../data/services/recibo_service.dart';
import '../utils/formatos.dart';
import '../widgets/consumo_chart.dart';
import 'mis_recibos_screen.dart';

/// Detalle de un recibo guardado en el archivero.
class DetalleReciboScreen extends StatefulWidget {
  final Recibo recibo;

  /// true cuando se acaba de guardar desde la pantalla de revisión
  final bool recienGuardado;

  const DetalleReciboScreen({
    super.key,
    required this.recibo,
    this.recienGuardado = false,
  });

  @override
  State<DetalleReciboScreen> createState() => _DetalleReciboScreenState();
}

class _DetalleReciboScreenState extends State<DetalleReciboScreen> {
  final ReciboService _service = ReciboService();
  bool _eliminando = false;

  Recibo get _r => widget.recibo;

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Eliminar recibo'),
        content: Text(
          '¿Eliminar el recibo de ${_r.empresa.nombre} de '
          '${formatearPeriodoLargo(_r.periodoFacturado)} de tu historial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || _r.id == null) return;

    setState(() => _eliminando = true);
    try {
      await _service.eliminar(_r.id!);
      if (mounted) Navigator.of(context).pop(true);
    } on ReciboException catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _irAMisRecibos() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MisRecibosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresa = _r.empresa;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(formatearPeriodoLargo(_r.periodoFacturado)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_r.id != null)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _eliminando ? null : _eliminar,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          if (widget.recienGuardado)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Recibo guardado en tu historial!',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          _buildCabecera(empresa),
          const SizedBox(height: 14),
          if (_r.historialConsumos.any((c) => c.consumo != null))
            _tarjeta('Historial de consumo (${empresa.unidad})', [
              ConsumoChart(
                historial: _r.historialConsumos,
                color: empresa.color,
                unidad: empresa.unidad,
              ),
            ]),
          _tarjeta('Fechas', [
            _fila('Emisión', formatearFecha(_r.fechaEmision)),
            _fila('Pago oportuno', formatearFecha(_r.fechaLimitePago)),
            _fila('Corte (suspensión)', formatearFecha(_r.fechaSuspension)),
            if (_r.periodoInicio != null || _r.periodoFin != null)
              _fila('Periodo de consumo',
                  '${formatearFecha(_r.periodoInicio)} – ${formatearFecha(_r.periodoFin)}'),
          ]),
          _tarjeta('Consumo', [
            _fila('Consumo del mes', '${formatearNumero(_r.consumoActual)} ${empresa.unidad}'),
            if (_r.lecturaAnterior != null) _fila('Lectura anterior', formatearNumero(_r.lecturaAnterior)),
            if (_r.lecturaActual != null) _fila('Lectura actual', formatearNumero(_r.lecturaActual)),
            if (_r.diasFacturados != null) _fila('Días facturados', '${_r.diasFacturados}'),
          ]),
          if (_r.conceptos.isNotEmpty)
            _tarjeta('Desglose del total', [
              for (final c in _r.conceptos) _fila(c.concepto, formatearPesos(c.valor)),
            ]),
          _tarjeta('Titular y ubicación', [
            _fila('Titular', _r.titular ?? '—'),
            _fila('Dirección', _r.direccion ?? '—'),
            _fila('Barrio', _r.barrio ?? '—'),
            _fila('Estrato', _r.estrato?.toString() ?? '—'),
            if (_r.numeroFactura != null) _fila('N.º de factura', _r.numeroFactura!),
          ]),
          if (widget.recienGuardado) ...[
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: _irAMisRecibos,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Ver mis recibos'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCabecera(Empresa empresa) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [empresa.color, Color.lerp(empresa.color, Colors.black, 0.25)!],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(empresa.icono, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                '${empresa.nombre} · ${empresa.servicio}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Total a pagar', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            formatearPesos(_r.valorTotal),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '${empresa.identificador} ${_r.identificador ?? '—'}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> hijos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          ...hijos,
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(etiqueta, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
