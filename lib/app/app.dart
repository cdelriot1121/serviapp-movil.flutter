import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
// 1. Importamos el orquestador del Splash en lugar del Login
import '../features/splash/presentation/views/splash_screen.dart';

class ServiApp extends StatelessWidget {
  const ServiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 2. Definimos el Splash como la primera pantalla al abrir la app
      home: const SplashScreen(),
    );
  }
}