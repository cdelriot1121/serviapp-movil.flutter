
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/views/login_screen.dart';

class ServiApp extends StatelessWidget {
  const ServiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
