import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/escena_naturaleza.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, RelojEscena {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado tranquilo: pocas hojas y el logo al centro.
            EncabezadoNaturaleza(
              tiempo: tiempo,
              cantidadHojas: 8,
              destellos: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, topPadding + 56, 24, 84),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, valor, child) => Opacity(
                      opacity: valor,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - valor)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ServiApp',
                          style: estiloTitulo(40, color: Colors.white).copyWith(
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bienvenido de nuevo',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Formulario de inicio de sesión
            const LoginForm(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
