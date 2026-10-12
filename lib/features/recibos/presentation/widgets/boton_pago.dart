import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../recordatorios/recordatorios_service.dart';
import '../../data/models/recibo.dart';
import '../../data/services/recibo_service.dart';
import '../utils/estado_pago.dart';

/// Marca o desmarca un recibo como pagado y actualiza los recordatorios.
/// Devuelve el recibo actualizado, o null si falló (ya mostró el error).
Future<Recibo?> cambiarPagoRecibo(
  BuildContext context,
  Recibo recibo, {
  required bool pagado,
  DateTime? fechaPago,
}) async {
  final id = recibo.id;
  if (id == null) return null;
  final mensajero = ScaffoldMessenger.of(context);
  try {
    final actualizado = await ReciboService().marcarPago(
      id,
      pagado: pagado,
      fechaPago: fechaPago,
    );
    await RecordatoriosService.actualizarRecibo(actualizado);
    return actualizado;
  } on ReciboException catch (e) {
    mensajero.showSnackBar(
      SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
    );
    return null;
  }
}

/// Píldora "Marcar pagado" / "Pagado" para la lista de recibos y el inicio.
class BotonPago extends StatefulWidget {
  final Recibo recibo;
  final ValueChanged<Recibo>? onCambio;

  const BotonPago({super.key, required this.recibo, this.onCambio});

  @override
  State<BotonPago> createState() => _BotonPagoState();
}

class _BotonPagoState extends State<BotonPago> {
  bool _cargando = false;

  Future<void> _alternar() async {
    final recibo = widget.recibo;
    final mensajero = ScaffoldMessenger.of(context);

    if (recibo.pagado) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('¿Desmarcar el pago?'),
          content: Text(
            'El recibo de ${recibo.empresa.servicio.toLowerCase()} volverá a '
            'aparecer como pendiente y recibirás sus recordatorios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Desmarcar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    setState(() => _cargando = true);
    final actualizado = await cambiarPagoRecibo(context, recibo, pagado: !recibo.pagado);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (actualizado == null) return;

    widget.onCambio?.call(actualizado);
    if (actualizado.pagado) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            'Recibo de ${recibo.empresa.servicio.toLowerCase()} marcado como pagado. '
            'Ya no recibirás recordatorios.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagado = widget.recibo.pagado;
    final color = pagado ? AppColors.green : AppColors.primary;

    return Material(
      color: pagado ? AppColors.green.withValues(alpha: 0.12) : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: pagado ? 0 : 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _cargando ? null : _alternar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cargando)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(
                  pagado ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: color,
                ),
              const SizedBox(width: 6),
              Text(
                pagado ? 'Pagado' : 'Marcar pagado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto con ícono del estado de pago ("Vence mañana", "Pagado el ...").
class EtiquetaEstadoPago extends StatelessWidget {
  final EstadoPago estado;

  const EtiquetaEstadoPago({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(estado.icono, size: 15, color: estado.color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            estado.texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: estado.color),
          ),
        ),
      ],
    );
  }
}
