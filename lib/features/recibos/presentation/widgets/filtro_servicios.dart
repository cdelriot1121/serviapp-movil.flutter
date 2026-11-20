import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';

/// Chips para filtrar por servicio: Todos, Energía, Agua y Gas.
/// [seleccionado] es ENERGIA, AGUA, GAS o null (todos).
class FiltroServicios extends StatelessWidget {
  final String? seleccionado;
  final ValueChanged<String?> onCambio;

  const FiltroServicios({super.key, required this.seleccionado, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip(null, 'Todos', Icons.all_inbox_rounded, AppColors.primary),
          for (final e in Empresa.values) _chip(e.tipoServicio, e.servicio, e.icono, e.color),
        ],
      ),
    );
  }

  Widget _chip(String? tipo, String texto, IconData icono, Color color) {
    final activo = seleccionado == tipo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: activo,
        avatar: Icon(icono, size: 18, color: activo ? Colors.white : color),
        label: Text(texto),
        showCheckmark: false,
        selectedColor: color,
        labelStyle: TextStyle(
          color: activo ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => onCambio(tipo),
      ),
    );
  }
}
