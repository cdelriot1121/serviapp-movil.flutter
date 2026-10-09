
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/login_header.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Encabezado azul de ServiApp
          const LoginHeader(),
        ],
      ),
    );
  }
}
