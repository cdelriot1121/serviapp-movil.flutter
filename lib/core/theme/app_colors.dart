import 'package:flutter/material.dart';

class AppColors {
  // Color principal: verde hoja con un toque de agua (botones, enlaces, foco)
  static const Color primary = Color(0xFF1F9D6B);

  // Fondos
  static const Color cream = Color(0xFFFCF8EE);
  static const Color surface = Color(0xFFFFFFFF);

  // Textos
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF607086);

  // Bordes
  static const Color border = Color(0xFFE6EEE1);

  // Colores de identidad
  static const Color logo = Color(0xFF38B6FF);
  static const Color sky = Color(0xFF2AA7E8);
  static const Color green = Color(0xFF27A66B);
  static const Color orange = Color(0xFFFFAA25);
  static const Color leafLight = Color(0xFF9AD47F);
  static const Color sun = Color(0xFFF6C344);

  // Errores, vencimientos y acciones destructivas
  static const Color red = Color(0xFFE5484D);

  /// Degradado cielo → agua → hoja de los encabezados y el botón del login.
  static const LinearGradient naturaleza = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky, Color(0xFF22B39C), Color(0xFF2E9E5B)],
    stops: [0, 0.55, 1],
  );
}
