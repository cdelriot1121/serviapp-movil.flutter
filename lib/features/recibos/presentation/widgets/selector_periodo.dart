import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';
import '../utils/formatos.dart';

/// Diálogo para elegir un mes (año + mes).
Future<Periodo?> seleccionarPeriodo(BuildContext context, Periodo? inicial) {
  final ahora = DateTime.now();
  return showDialog<Periodo>(
    context: context,
    builder: (_) => _SelectorPeriodo(inicial: inicial ?? Periodo(ahora.year, ahora.month)),
  );
}

class _SelectorPeriodo extends StatefulWidget {
  final Periodo inicial;

  const _SelectorPeriodo({required this.inicial});

  @override
  State<_SelectorPeriodo> createState() => _SelectorPeriodoState();
}

class _SelectorPeriodoState extends State<_SelectorPeriodo> {
  late int _anio = widget.inicial.anio;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mes facturado'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _anio--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '$_anio',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: _anio < DateTime.now().year + 1 ? () => setState(() => _anio++) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var mes = 1; mes <= 12; mes++)
                  _BotonMes(
                    texto: mesesLargos[mes - 1].substring(0, 3),
                    seleccionado: widget.inicial == Periodo(_anio, mes),
                    onTap: () => Navigator.of(context).pop(Periodo(_anio, mes)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _BotonMes extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BotonMes({required this.texto, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Text(
            texto,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: seleccionado ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
