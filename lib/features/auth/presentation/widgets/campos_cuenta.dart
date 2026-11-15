import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// Campos que comparten el registro y el perfil, con las mismas reglas que
// valida Spring Boot.

String? validarNombre(String? valor) {
  final nombre = valor?.trim() ?? '';
  if (nombre.isEmpty) return 'Ingresa tu nombre completo';
  if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(nombre)) {
    return 'Usa solo letras y espacios';
  }
  return null;
}

String? validarPassword(String? valor) {
  if (RequisitosPassword.de(valor ?? '').any((r) => !r.cumple)) {
    return 'La contraseña no cumple todos los requisitos';
  }
  return null;
}

/// Barra de fuerza y requisitos de la contraseña, como en la web.
class RequisitosPassword extends StatelessWidget {
  final String password;

  const RequisitosPassword({super.key, required this.password});

  static List<({String texto, bool cumple})> de(String password) => [
    (texto: 'Mínimo 8 caracteres', cumple: password.length >= 8),
    (
      texto: 'Al menos una mayúscula',
      cumple: RegExp(r'[A-Z]').hasMatch(password),
    ),
    (texto: 'Al menos un número', cumple: RegExp(r'[0-9]').hasMatch(password)),
    (
      texto: 'Al menos un carácter especial',
      cumple: RegExp(
        r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]''',
      ).hasMatch(password),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final requisitos = de(password);
    final cumplidos = requisitos.where((r) => r.cumple).length;
    final fuerza = cumplidos / requisitos.length;
    final color = fuerza < 0.5
        ? AppColors.red
        : fuerza < 0.75
        ? const Color(0xFFF59E0B)
        : AppColors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fuerza),
            duration: const Duration(milliseconds: 400),
            builder: (_, valor, _) => LinearProgressIndicator(
              value: valor,
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.border,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final r in requisitos)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  r.cumple
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 17,
                  color: r.cumple ? AppColors.green : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.texto,
                    style: TextStyle(
                      fontSize: 13,
                      color: r.cumple
                          ? AppColors.green
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class BotonPrincipal extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool cargando;
  final VoidCallback onPressed;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.icono,
    required this.cargando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        child: cargando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  Icon(icono, size: 20),
                ],
              ),
      ),
    );
  }
}
