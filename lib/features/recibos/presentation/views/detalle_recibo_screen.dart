import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../recordatorios/recordatorios_service.dart';
import '../../data/models/recibo.dart';
import '../../data/services/recibo_service.dart';
import '../utils/estado_pago.dart';
import '../utils/formatos.dart';
import '../widgets/boton_pago.dart';
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
  bool _guardandoPago = false;

  late Recibo _r = widget.recibo;

  Future<void> _cambiarPago({required bool pagado, DateTime? fecha}) async {
    setState(() => _guardandoPago = true);
    final actualizado = await cambiarPagoRecibo(context, _r, pagado: pagado, fechaPago: fecha);
    if (!mounted) return;
    setState(() {
      _guardandoPago = false;
      if (actualizado != null) _r = actualizado;
    });
  }

  // Para registrar un pago hecho otro día
  Future<void> _elegirFechaPago() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _r.fechaPago ?? hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
      helpText: '¿Qué día pagaste?',
    );
    if (fecha != null) await _cambiarPago(pagado: true, fecha: fecha);
  }

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
      await RecordatoriosService.reciboEliminado(_r.id!);
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
            const BotonInicio(),
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
          if (_r.id != null) _buildPago(),
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

  Widget _buildPago() {
    final estado = EstadoPago.de(_r);
    final pagado = _r.pagado;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pagado ? AppColors.green.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pagado ? AppColors.green.withValues(alpha: 0.35) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(estado.icono, color: estado.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado del pago',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      estado.texto,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: estado.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_guardandoPago)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              ),
            )
          else if (pagado)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFechaPago,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: const Text('Cambiar fecha'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _cambiarPago(pagado: false),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Desmarcar'),
                  ),
                ),
              ],
            )
          else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _cambiarPago(pagado: true),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Ya lo pagué'),
            ),
            TextButton(
              onPressed: _elegirFechaPago,
              child: const Text('Lo pagué otro día'),
            ),
            if (_r.fechaLimitePago != null)
              const Text(
                'Te recordaremos un día antes, el día de pago y un día después '
                'mientras no lo marques como pagado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
              ),
          ],
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
