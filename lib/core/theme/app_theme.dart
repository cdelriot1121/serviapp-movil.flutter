import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Títulos con la tipografía del logo.
TextStyle estiloTitulo(double tam, {Color color = AppColors.textPrimary}) =>
    TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w800,
      fontSize: tam,
      color: color,
      letterSpacing: -0.2,
    );

class AppTheme {
  static ThemeData get lightTheme {
    final redondeado = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,

      // Colores generales: fondo crema y verde hoja como color principal
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        error: AppColors.red,
        surface: AppColors.surface,
      ),

      // Tipografía general
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
      ),

      // Barra superior sobre el mismo fondo crema, con título Montserrat
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: estiloTitulo(19),
      ),

      // Estilo de botones principales
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(double.infinity, 56),
          shape: redondeado,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: redondeado),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          shape: redondeado,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),

      // Avisos flotantes en verde bosque
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F3A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // Estilo de campos de texto: borde suave y foco verde
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: borde,
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
