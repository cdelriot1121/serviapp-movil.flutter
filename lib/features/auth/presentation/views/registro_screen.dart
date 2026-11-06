import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';

/// Crear cuenta, con los mismos pasos de la web: datos → código enviado al
/// correo → cuenta creada. Spring Boot valida todo y guarda el usuario en la
/// misma base de datos. Al terminar devuelve el correo para iniciar sesión.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const _esperaReenvio = 60;

  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _codigo = TextEditingController();

  bool _ocultarPassword = true;
  bool _mostrarErrores = false;
  bool _cargando = false;

  // false: datos de la cuenta; true: código de verificación
  bool _esperandoCodigo = false;

  Timer? _temporizador;
  int _segundosReenvio = 0;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _codigo.dispose();
    super.dispose();
  }

  String get _correo => _email.text.trim().toLowerCase();

  // ------------------------------------------------------------ validaciones

  String? _validarNombre(String? valor) {
    final nombre = valor?.trim() ?? '';
    if (nombre.isEmpty) return 'Ingresa tu nombre completo';
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(nombre)) {
      return 'Usa solo letras y espacios';
    }
    return null;
  }

  String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Revisa tu correo, parece que no está bien escrito';
    }
    return null;
  }

  String? _validarPassword(String? valor) {
    if (_RequisitosPassword.de(valor ?? '').any((r) => !r.cumple)) {
      return 'La contraseña no cumple todos los requisitos';
    }
    return null;
  }

  // ------------------------------------------------------------ pasos

  // Paso 1: verifica que el correo no tenga cuenta y envía el código
  Future<void> _enviarCodigo() async {
    setState(() => _mostrarErrores = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _cargando = true);
    try {
      await _authService.enviarCodigo(_correo);
      if (!mounted) return;
      _codigo.clear();
      setState(() => _esperandoCodigo = true);
      _iniciarTemporizador();
      _mensaje('Te enviamos un código de verificación a $_correo.');
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.emailRegistrado) {
        await _dialogoCuentaExistente(e.mensaje);
      } else {
        _mensaje(e.mensaje, error: true);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviarCodigo() async {
    setState(() => _cargando = true);
    try {
      await _authService.enviarCodigo(_correo);
      if (!mounted) return;
      _iniciarTemporizador();
      _mensaje('Te enviamos un código nuevo.');
    } on AuthException catch (e) {
      if (mounted) _mensaje(e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Paso 2 y 3: valida el código y crea la cuenta
  Future<void> _verificarYRegistrar() async {
    final codigo = _codigo.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      _mensaje('El código debe tener 6 dígitos.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => _cargando = true);
    try {
      await _authService.verificarCodigo(email: _correo, codigo: codigo);
      await _authService.registrar(
        nombre: _nombre.text.trim(),
        email: _correo,
        password: _password.text,
      );
      if (!mounted) return;
      await _dialogoRegistroExitoso();
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.emailRegistrado) {
        await _dialogoCuentaExistente(e.mensaje);
      } else {
        _mensaje(e.mensaje, error: true);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _iniciarTemporizador() {
    _temporizador?.cancel();
    setState(() => _segundosReenvio = _esperaReenvio);
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _segundosReenvio--);
      if (_segundosReenvio <= 0) t.cancel();
    });
  }

  void _cambiarCorreo() {
    _temporizador?.cancel();
    setState(() {
      _esperandoCodigo = false;
      _segundosReenvio = 0;
    });
  }

  // ------------------------------------------------------------ diálogos

  // El correo ya tiene cuenta: se envía a iniciar sesión con el correo escrito
  Future<void> _dialogoCuentaExistente(String mensaje) async {
    await showDialog<void>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.person_search_rounded, size: 44, color: AppColors.primary),
        title: const Text('Ya tienes una cuenta'),
        content: Text(mensaje, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(_correo);
  }

  Future<void> _dialogoRegistroExitoso() async {
    final nombre = _nombre.text.trim().split(' ').first;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, size: 48, color: AppColors.green),
        title: Text('¡Registro exitoso, $nombre!'),
        content: const Text(
          'Bienvenido a ServiApp. Tu cuenta se ha creado correctamente. '
          'Ahora inicia sesión con tu correo y contraseña.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(_correo);
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ------------------------------------------------------------ interfaz

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // En el paso del código, "atrás" vuelve a los datos
      canPop: !_esperandoCodigo,
      onPopInvokedWithResult: (salio, _) {
        if (!salio && !_cargando) _cambiarCorreo();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Crear cuenta'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _esperandoCodigo ? _pasoCodigo() : _pasoDatos(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoDatos() {
    return Form(
      key: _formKey,
      autovalidateMode: _mostrarErrores ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        key: const ValueKey('datos'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Pasos(actual: 0),
          const SizedBox(height: 22),
          const Text(
            'Únete a ServiApp',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa la misma cuenta en la app y en la página web.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: _validarNombre,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: _validarEmail,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'ejemplo@correo.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _password,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validarPassword,
            onFieldSubmitted: (_) => _cargando ? null : _enviarCodigo(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Crea una contraseña segura',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultarPassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(_ocultarPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _RequisitosPassword(password: _password.text),
          const SizedBox(height: 28),
          _BotonPrincipal(
            texto: 'Verificar correo',
            icono: Icons.mark_email_read_outlined,
            cargando: _cargando,
            onPressed: _enviarCodigo,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('¿Ya tienes cuenta?', style: TextStyle(color: AppColors.textSecondary)),
              TextButton(
                onPressed: _cargando ? null : () => Navigator.of(context).pop(),
                child: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pasoCodigo() {
    return Column(
      key: const ValueKey('codigo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Pasos(actual: 1),
        const SizedBox(height: 26),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_outlined, size: 38, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Escribe el código de 6 dígitos que enviamos a\n'),
              TextSpan(
                text: _correo,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const TextSpan(text: '\nEl código vence en 5 minutos. Si no lo ves, revisa la carpeta de spam.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        TextField(
          controller: _codigo,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
          onChanged: (valor) {
            if (valor.length == 6 && !_cargando) _verificarYRegistrar();
          },
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        ),
        const SizedBox(height: 22),
        _BotonPrincipal(
          texto: 'Verificar y crear cuenta',
          icono: Icons.how_to_reg_rounded,
          cargando: _cargando,
          onPressed: _verificarYRegistrar,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _cargando || _segundosReenvio > 0 ? null : _reenviarCodigo,
          child: Text(
            _segundosReenvio > 0
                ? 'Reenviar código en $_segundosReenvio s'
                : '¿No recibiste el código? Reenviar',
          ),
        ),
        TextButton(
          onPressed: _cargando ? null : _cambiarCorreo,
          child: const Text('Cambiar mis datos'),
        ),
      ],
    );
  }
}

/// Indicador de los dos pasos del registro.
class _Pasos extends StatelessWidget {
  final int actual;

  const _Pasos({required this.actual});

  @override
  Widget build(BuildContext context) {
    Widget paso(int i, String texto) {
      final activo = i <= actual;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 5,
              decoration: BoxDecoration(
                color: activo ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        paso(0, '1. Tus datos'),
        const SizedBox(width: 10),
        paso(1, '2. Verifica tu correo'),
      ],
    );
  }
}

/// Barra de fuerza y requisitos de la contraseña, como en la web.
class _RequisitosPassword extends StatelessWidget {
  final String password;

  const _RequisitosPassword({required this.password});

  static List<({String texto, bool cumple})> de(String password) => [
        (texto: 'Mínimo 8 caracteres', cumple: password.length >= 8),
        (texto: 'Al menos una mayúscula', cumple: RegExp(r'[A-Z]').hasMatch(password)),
        (texto: 'Al menos un número', cumple: RegExp(r'[0-9]').hasMatch(password)),
        (
          texto: 'Al menos un carácter especial',
          cumple: RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]''').hasMatch(password),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final requisitos = de(password);
    final cumplidos = requisitos.where((r) => r.cumple).length;
    final fuerza = cumplidos / requisitos.length;
    final color = fuerza < 0.5
        ? const Color(0xFFEF4444)
        : fuerza < 0.75
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

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
              backgroundColor: const Color(0xFFE5E7EB),
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
                  r.cumple ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 17,
                  color: r.cumple ? const Color(0xFF10B981) : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.texto,
                    style: TextStyle(
                      fontSize: 13,
                      color: r.cumple ? const Color(0xFF10B981) : AppColors.textSecondary,
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

class _BotonPrincipal extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool cargando;
  final VoidCallback onPressed;

  const _BotonPrincipal({
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
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
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
