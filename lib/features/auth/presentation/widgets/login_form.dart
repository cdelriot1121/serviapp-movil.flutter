
import 'package:flutter/material.dart';
import 'package:serviapp/features/auth/presentation/views/home_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../predio/presentation/registro_predio_screen.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/biometric_service.dart';
import '../views/recuperar_contrasena_screen.dart';
import '../views/registro_screen.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  // Controladores de los campos
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  // Servicio que conecta Flutter con Spring Boot
  final AuthService _authService = AuthService();

  // Servicio de inicio de sesión con huella
  final BiometricService _biometricService = BiometricService();

  // Clave para validar el formulario
  final _formKey = GlobalKey<FormState>();

  // Estados del formulario
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showErrors = false;

  // Estados de la huella
  bool _huellaDisponible = false;
  bool _huellaActivada = false;

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

        _cargarEstadoHuella();
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

  // Revisa si se puede entrar con huella y la pide automáticamente
  Future<void> _cargarEstadoHuella() async {
    final disponible = await _biometricService.isAvailable();
    final activada =
        disponible && await _biometricService.isEnabled();

    if (!mounted) return;

    setState(() {
      _huellaDisponible = disponible;
      _huellaActivada = activada;
    });

    if (activada) {
      _loginConHuella();
    }
  }

  // INICIO DE SESIÓN CON CORREO Y CONTRASEÑA
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

    await _autenticar(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      conHuella: false,
    );
  }

  // INICIO DE SESIÓN CON HUELLA
  Future<void> _loginConHuella() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    try {
      final credenciales = await _biometricService.authenticate();

      // El usuario canceló o la huella no coincidió
      if (credenciales == null || !mounted) return;

      await _autenticar(
        email: credenciales.email,
        password: credenciales.password,
        conHuella: true,
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarError(_limpiarMensaje(e));
    }
  }

  // INICIO DE SESIÓN REAL CON SPRING BOOT
  Future<void> _autenticar({
    required String email,
    required String password,
    required bool conHuella,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Enviar credenciales a Spring Boot
      final respuesta = await _authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Comprobar que Spring Boot autenticó al usuario
      if (respuesta['autenticado'] == true) {
        final nombre =
            (respuesta['nombre'] ?? 'Usuario').toString();

        if (!conHuella) {
          await _gestionarHuellaTrasLogin(email, password);
          if (!mounted) return;
        }

        // Sin predio registrado se pide antes de entrar (igual que la web)
        final tienePredio = respuesta['tienePredio'] != false;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => tienePredio
                ? HomeScreen(nombre: nombre)
                : RegistroPredioScreen(nombre: nombre),
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

      final mensaje = _limpiarMensaje(e);

      // Si la contraseña guardada ya no sirve, se desactiva la huella
      if (conHuella &&
          mensaje == 'Correo o contraseña incorrectos.') {
        await _biometricService.disable();
        if (!mounted) return;

        setState(() {
          _huellaActivada = false;
        });

        _mostrarError(
          'Tu contraseña cambió. Ingresa con tu correo y '
          'contraseña para volver a activar la huella.',
        );
        return;
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

  // Después de un login con contraseña: ofrece activar la huella
  // o actualiza la contraseña guardada si ya estaba activada
  Future<void> _gestionarHuellaTrasLogin(
    String email,
    String password,
  ) async {
    if (!_huellaDisponible) return;

    if (_huellaActivada) {
      await _biometricService.enable(
        email: email,
        password: password,
      );
      return;
    }

    final activar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.fingerprint,
          size: 48,
          color: AppColors.primary,
        ),
        title: const Text('¿Entrar con tu huella?'),
        content: const Text(
          'La próxima vez podrás iniciar sesión solo con tu '
          'huella, sin escribir tu correo y contraseña.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );

    if (activar != true) return;

    // Confirmar con la huella antes de guardar las credenciales
    try {
      final confirmada = await _biometricService.confirmIdentity();
      if (!confirmada) return;

      await _biometricService.enable(
        email: email,
        password: password,
      );
    } catch (_) {
      // Si falla, el usuario igual entra; solo no se activa la huella
    }
  }

  // Crear cuenta: al volver trae el correo para iniciar sesión
  Future<void> _abrirRegistro() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegistroScreen()),
    );
    if (email == null || !mounted) return;

    setState(() {
      _emailController.text = email;
      _passwordController.clear();
      _showErrors = false;
    });
    _passwordFocus.requestFocus();
  }

  void _abrirRecuperarContrasena() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecuperarContrasenaScreen(email: _emailController.text.trim()),
      ),
    );
  }

  // Quita el prefijo "Exception: " de los errores
  String _limpiarMensaje(Object e) {
    String mensaje = e.toString();

    if (mensaje.startsWith('Exception: ')) {
      mensaje = mensaje.substring('Exception: '.length);
    }

    return mensaje;
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
    _passwordFocus.dispose();
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
                  focusNode: _passwordFocus,
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
                    onPressed: _isLoading ? null : _abrirRecuperarContrasena,

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

                // BOTÓN DE INICIO CON HUELLA
                if (_huellaActivada) ...[
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 56,

                    child: OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : _loginConHuella,
                      icon: const Icon(
                        Icons.fingerprint,
                        size: 26,
                      ),
                      label: const Text('Entrar con huella'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // CREAR CUENTA
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      '¿No tienes cuenta?',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _abrirRegistro,
                      child: const Text(
                        'Regístrate',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

