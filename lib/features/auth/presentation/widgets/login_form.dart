
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  // Controladores de los campos
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Servicio que conecta Flutter con Spring Boot
  final AuthService _authService = AuthService();

  // Clave para validar el formulario
  final _formKey = GlobalKey<FormState>();

  // Estados del formulario
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showErrors = false;

  // Controla la animación de entrada
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  // Validación del correo electrónico
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Necesitamos tu correo para iniciar sesión';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Revisa tu correo, parece que no está bien escrito';
    }

    return null;
  }

  // Validación de la contraseña
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña para continuar';
    }

    return null;
  }

  // INICIO DE SESIÓN REAL CON SPRING BOOT
  Future<void> _login() async {
    if (_isLoading) return;

    setState(() {
      _showErrors = true;
    });

    // Validar campos
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Ocultar teclado
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // Enviar credenciales a Spring Boot
      final respuesta = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Comprobar que Spring Boot autenticó al usuario
      if (respuesta['autenticado'] == true) {
        final nombre =
            (respuesta['nombre'] ?? 'Usuario').toString();

        // Abrir pantalla nativa de bienvenida
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LoginSuccessScreen(
              nombre: nombre,
            ),
          ),
        );
      } else {
        _mostrarError(
          respuesta['mensaje']?.toString() ??
              'No se pudo iniciar sesión.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Mostrar el mensaje enviado por AuthService
      String mensaje = e.toString();

      if (mensaje.startsWith('Exception: ')) {
        mensaje = mensaje.substring('Exception: '.length);
      }

      _mostrarError(mensaje);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mostrar errores de inicio de sesión
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(mensaje),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      offset: _isVisible
          ? Offset.zero
          : const Offset(0, 0.12),

      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 650),
        opacity: _isVisible ? 1 : 0,

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),

          child: Form(
            key: _formKey,
            autovalidateMode: _showErrors
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TÍTULO PRINCIPAL
                const Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ingresa tus datos para continuar',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 30),

                // CORREO ELECTRÓNICO
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  autofillHints: const [
                    AutofillHints.email,
                  ],

                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // CONTRASEÑA
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                  autofillHints: const [
                    AutofillHints.password,
                  ],

                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _login();
                    }
                  },

                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Ingresa tu contraseña',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),

                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',

                      icon: AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 200,
                        ),

                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          key: ValueKey(_obscurePassword),
                        ),
                      ),

                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // RECUPERAR CONTRASEÑA
                Align(
                  alignment: Alignment.centerRight,

                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Próximamente podrás recuperar tu contraseña.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },

                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // BOTÓN ANIMADO DE INICIO DE SESIÓN
                SizedBox(
                  width: double.infinity,
                  height: 56,

                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,

                    child: AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 300,
                      ),

                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },

                      child: _isLoading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 24,
                              height: 24,

                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )

                          : const Row(
                              key: ValueKey('login'),
                              mainAxisAlignment:
                                  MainAxisAlignment.center,

                              children: [
                                Text('Iniciar sesión'),
                                SizedBox(width: 10),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// PANTALLA TEMPORAL DE BIENVENIDA
// Posteriormente será el inicio de ServiApp Mobile

class LoginSuccessScreen extends StatelessWidget {
  final String nombre;

  const LoginSuccessScreen({
    super.key,
    required this.nombre,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 100,
                  color: Colors.green,
                ),

                const SizedBox(height: 24),

                const Text(
                  '¡Login exitoso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Bienvenido, $nombre',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Has iniciado sesión correctamente en ServiApp Mobile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
