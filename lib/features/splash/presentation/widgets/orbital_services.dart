import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class OrbitalServices extends StatelessWidget {
  final double progress;
  const OrbitalServices({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final orbitProgress = (progress / 0.8).clamp(0.0, 1.0);
    final shockwaveProgress = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
    final orbitRadius = 100.0 * (1.0 - Curves.easeInExpo.transform(orbitProgress));
    final angle = progress * math.pi * 6; 

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. EL NUEVO SHOCKWAVE (Anillo de energía en lugar de círculo blanco)
          if (shockwaveProgress > 0)
            Transform.scale(
              scale: shockwaveProgress * 50, 
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  // El interior es del mismo color oscuro que el fondo del splash
                  color: const Color(0xFF030914), 
                  // El borde es el que brilla y se expande
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.5), 
                      blurRadius: 10, 
                      spreadRadius: 5
                    )
                  ]
                ),
              ),
            ),
            
          // 2. LOS SERVICIOS ORBITANDO
          if (shockwaveProgress == 0) ...[
            _buildOrbitalNode(icon: Icons.water_drop_rounded, color: AppColors.primary, angleOffset: 0, currentAngle: angle, radius: orbitRadius, scale: orbitProgress),
            _buildOrbitalNode(icon: Icons.bolt_rounded, color: AppColors.orange, angleOffset: math.pi * 2 / 3, currentAngle: angle, radius: orbitRadius, scale: orbitProgress),
            _buildOrbitalNode(icon: Icons.local_fire_department_rounded, color: AppColors.green, angleOffset: math.pi * 4 / 3, currentAngle: angle, radius: orbitRadius, scale: orbitProgress),
          ]
        ],
      ),
    );
  }

  Widget _buildOrbitalNode({required IconData icon, required Color color, required double angleOffset, required double currentAngle, required double radius, required double scale}) {
    final x = math.cos(currentAngle + angleOffset) * radius;
    final y = math.sin(currentAngle + angleOffset) * radius;
    final nodeScale = Curves.easeOutBack.transform(scale).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(x, y),
      child: Transform.scale(
        scale: nodeScale,
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: color,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}