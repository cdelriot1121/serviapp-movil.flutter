import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botón compacto para volver al menú de inicio desde cualquier pantalla.
/// Se ubica en las `actions` del AppBar.
class BotonInicio extends StatelessWidget {
  const BotonInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Tooltip(
          message: 'Volver al inicio',
          child: Material(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // El inicio es la primera ruta tras el login.
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.home_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Inicio',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
