import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';

/// "¿Olvidaste tu contraseña?": Spring Boot envía el mismo enlace que la web.
/// El enlace abre la página de ServiApp para crear la nueva contraseña.
class RecuperarContrasenaScreen extends StatefulWidget {
  final String email;

  const RecuperarContrasenaScreen({super.key, this.email = ''});

  @override
  State<RecuperarContrasenaScreen> createState() => _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);

  bool _cargando = false;

  // Mensaje de Spring cuando la solicitud se procesó
  String? _enviado;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _cargando = true);
    try {
      final mensaje = await _authService.recuperarContrasena(_email.text.trim().toLowerCase());
      if (mounted) setState(() => _enviado = mensaje);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.mensaje),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _enviado == null ? _formulario() : _confirmacion(_enviado!),
          ),
        ),
      ),
    );
  }

  Widget _icono(IconData icono, Color color) {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icono, size: 40, color: color),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('formulario'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _icono(Icons.lock_reset_rounded, AppColors.primary),
          const SizedBox(height: 20),
          const Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva. '
            'El enlace dura 15 minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _cargando ? null : _enviar(),
            validator: (valor) {
              final email = valor?.trim() ?? '';
              if (email.isEmpty) return 'Ingresa tu correo electrónico';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Revisa tu correo, parece que no está bien escrito';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'ejemplo@correo.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _cargando ? null : _enviar,
              child: _cargando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Enviar enlace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmacion(String mensaje) {
    return Column(
      key: const ValueKey('enviado'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _icono(Icons.mark_email_read_rounded, AppColors.green),
        const SizedBox(height: 20),
        const Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Text(
          '$mensaje\n\nAbre el enlace, crea tu nueva contraseña y vuelve aquí para iniciar sesión. '
          'Si no lo ves, revisa la carpeta de spam.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver a iniciar sesión'),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _enviado = null),
          child: const Text('No me llegó, enviar de nuevo'),
        ),
      ],
    );
  }
}
