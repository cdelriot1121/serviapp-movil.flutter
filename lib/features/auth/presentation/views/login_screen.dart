
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/login_header.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado azul
            const LoginHeader(),

            const SizedBox(height: 35),

            // Formulario de inicio de sesión
            const LoginForm(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
