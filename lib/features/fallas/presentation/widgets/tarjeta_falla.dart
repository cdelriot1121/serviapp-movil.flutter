import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/falla.dart';

/// Tarjeta de una falla: servicio, barrio, hora, comentario y estado.
/// [pie] va debajo (botones como "A mí también" o el progreso del reporte).
class TarjetaFalla extends StatelessWidget {
  final Falla falla;
  final Widget? pie;
  final VoidCallback? onTap;

  /// En "Mi barrio" el barrio ya está en el encabezado.
  final bool mostrarBarrio;

  const TarjetaFalla({
    super.key,
    required this.falla,
    this.pie,
    this.onTap,
    this.mostrarBarrio = true,
  });

  @override
  Widget build(BuildContext context) {
    final servicio = falla.servicio;
    final color = servicio?.color ?? AppColors.primary;
    final comentario = falla.comentarios?.trim() ?? '';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(servicio?.icono ?? Icons.report_problem_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Falla de ${falla.nombreServicio.toLowerCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (mostrarBarrio) nombreBarrio(falla.barrio),
                            'desde las ${horaCorta(falla.hora)}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  EtiquetaEstadoFalla(estado: falla.estado),
                ],
              ),
              if (comentario.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    comentario,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Reportada ${haceCuanto(falla.fechaReporte)}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  if (falla.confirmaciones > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.groups_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        falla.confirmaciones == 1
                            ? '1 vecino también'
                            : '${falla.confirmaciones} vecinos también',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
              if (pie != null) ...[
                const SizedBox(height: 12),
                pie!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilla de color con el estado de la falla.
class EtiquetaEstadoFalla extends StatelessWidget {
  final EstadoFalla estado;

  const EtiquetaEstadoFalla({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 14, color: estado.color),
          const SizedBox(width: 4),
          Text(
            estado.texto,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: estado.color),
          ),
        ],
      ),
    );
  }
}

/// Reportada -> En revisión -> Solucionada.
class ProgresoFalla extends StatelessWidget {
  final EstadoFalla estado;

  const ProgresoFalla({super.key, required this.estado});

  static const _pasos = ['Reportada', 'En revisión', 'Solucionada'];

  @override
  Widget build(BuildContext context) {
    final actual = estado.index;
    return Row(
      children: [
        for (var i = 0; i < _pasos.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: i <= actual ? estado.color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= actual ? estado.color : AppColors.surface,
                  border: Border.all(color: i <= actual ? estado.color : AppColors.border, width: 2),
                ),
                child: i <= actual ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(height: 4),
              Text(
                _pasos[i],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                  color: i <= actual ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Estado vacío o de error de las listas de fallas.
class MensajeFallas extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;
  final Color? color;

  const MensajeFallas({
    super.key,
    required this.icono,
    required this.texto,
    this.accion,
    this.onAccion,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 60, color: color ?? AppColors.border),
          const SizedBox(height: 14),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
          ),
          if (accion != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAccion, child: Text(accion!)),
          ],
        ],
      ),
    );
  }
}
