
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),

      
child: ClipRRect(
  borderRadius: const BorderRadius.only(
    bottomLeft: Radius.circular(35),
    bottomRight: Radius.circular(35),
  ),
  child: Stack(
    children: [
      // Círculo decorativo superior derecho
      Positioned(
        top: -65,
        right: -55,
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),

      // Círculo decorativo inferior izquierdo
      Positioned(
        bottom: -75,
        left: -60,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),

      // Contenido principal del encabezado
      SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.water_drop,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.bolt,
                      color: AppColors.orange,
                      size: 32,
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.local_fire_department,
                      color: AppColors.green,
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ServiApp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),

    );
  }
}
