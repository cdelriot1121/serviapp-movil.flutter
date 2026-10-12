import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/escanear_recibo.dart';
import '../../../recibos/presentation/utils/estado_pago.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recibos/presentation/views/detalle_recibo_screen.dart';
import '../../../recibos/presentation/views/mis_recibos_screen.dart';
import '../../../recibos/presentation/widgets/boton_pago.dart';
import '../../../recordatorios/recordatorios_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String nombre;

  const HomeScreen({
    super.key,
    required this.nombre,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _visible = false;

  // Último recibo sin pagar de cada servicio (null mientras carga)
  List<Recibo>? _pendientes;

  @override
  void initState() {
    super.initState();

    // Animación suave y continua del fondo.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Programa los recordatorios de pago y carga "Tus pagos".
    _iniciarRecordatorios();
    RecordatoriosService.cambios.addListener(_recargarPagos);

    // Aparición inicial del contenido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  Future<void> _iniciarRecordatorios() async {
    final recibos = await RecordatoriosService.alIniciarSesion(widget.nombre);
    if (mounted && recibos != null) {
      setState(() => _pendientes = pagosPendientes(recibos));
    }
  }

  Future<void> _recargarPagos() async {
    try {
      final recibos = await RecordatoriosService.recibosActualizados();
      if (mounted) setState(() => _pendientes = pagosPendientes(recibos));
    } catch (_) {
      // Se deja la última lista conocida
    }
  }

  @override
  void dispose() {
    RecordatoriosService.cambios.removeListener(_recargarPagos);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 34),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  offset: _visible
                      ? Offset.zero
                      : const Offset(0, 0.10),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 650),
                    opacity: _visible ? 1 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Qué hacemos hoy?',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Estoy aquí para ayudarte. '
                          'Elige qué te gustaría hacer.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Menú de herramientas.
                        _buildToolsMenu(),

                        _buildPagos(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          size: 40,
          color: AppColors.primary,
        ),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que iniciar sesión de nuevo para usar ServiApp.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    await RecordatoriosService.alCerrarSesion();
    await AuthService().logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        26,
        topPadding + 28,
        26,
        38,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D83F0),
            Color(0xFF1550A3),
            Color(0xFF103F83),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Fondo decorativo animado.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _HeaderBackgroundPainter(
                      progress: _animationController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Contenido principal del header.
          AnimatedSlide(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            offset:
                _visible ? Offset.zero : const Offset(0, 0.08),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              opacity: _visible ? 1 : 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.water_drop_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
                      const SizedBox(width: 9),
                      const Text(
                        'ServiApp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      _LogoutButton(onTap: _cerrarSesion),
                    ],
                  ),

                  const SizedBox(height: 37),

                  Text(
                    '¡Hola, ${widget.nombre}!',
                    style: const TextStyle(
                      color: Color(0xFFE4F1FF),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Tu espacio inteligente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Tus servicios públicos, siempre a tu alcance.',
                    style: TextStyle(
                      color: Color(0xFFE0EDFF),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Recibos sin pagar con su fecha límite. Se oculta si no hay ninguno.
  Widget _buildPagos() {
    final pendientes = _pendientes;
    if (pendientes == null || pendientes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tus pagos',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Márcalos como pagados para dejar de recibir recordatorios.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final recibo in pendientes) ...[
            _FilaPago(
              recibo: recibo,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetalleReciboScreen(recibo: recibo),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildToolsMenu() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 22,
      mainAxisSpacing: 28,
      mainAxisExtent: 140,
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _ToolIcon(
          icon: Icons.document_scanner_outlined,
          title: 'Escanear recibo',
          onTap: () => iniciarEscaneoRecibo(context),
        ),
        _ToolIcon(
          icon: Icons.folder_copy_outlined,
          title: 'Mis recibos',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MisRecibosScreen()),
          ),
        ),
      ],
    );
  }
}

// Fila de un recibo pendiente en "Tus pagos".
class _FilaPago extends StatelessWidget {
  final Recibo recibo;
  final VoidCallback onTap;

  const _FilaPago({required this.recibo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final empresa = recibo.empresa;
    final estado = EstadoPago.de(recibo);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: estado.vencido || estado.dias == 0
                  ? estado.color.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: empresa.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(empresa.icono, color: empresa.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${empresa.servicio} · ${formatearPesos(recibo.valorTotal)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    EtiquetaEstadoPago(estado: estado),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BotonPago(recibo: recibo),
            ],
          ),
        ),
      ),
    );
  }
}

// Botón translúcido de cerrar sesión sobre el encabezado azul.
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cerrar sesión',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 17),
                SizedBox(width: 6),
                Text(
                  'Salir',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

// Ícono de herramienta estilo aplicación móvil.
class _ToolIcon extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_ToolIcon> createState() => _ToolIconState();
}

class _ToolIconState extends State<_ToolIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 105,
      child: Column(
        children: [
          GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              scale: _pressed ? 0.93 : 1.0,
              child: Container(
                width: 77,
                height: 77,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE5F2FF),
                      Color(0xFFCCE3FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.10,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
          ),

          const SizedBox(height: 11),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Ondas y partículas animadas del encabezado.
class _HeaderBackgroundPainter extends CustomPainter {
  final double progress;

  _HeaderBackgroundPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * 2 * math.pi;

    // Círculos concéntricos decorativos.
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(
      size.width * 0.91,
      size.height * 0.25,
    );

    for (int i = 0; i < 4; i++) {
      final radius =
          43.0 + i * 23.0 + math.sin(phase) * 2.0;

      canvas.drawCircle(center, radius, circlePaint);
    }

    // Ondas suaves en el fondo.
    for (int i = 0; i < 2; i++) {
      final wavePaint = Paint()
        ..color = Colors.white.withValues(
          alpha: i == 0 ? 0.13 : 0.07,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      final path = Path();

      for (double x = 0; x <= size.width; x += 4) {
        final y = size.height * (0.76 + i * 0.10) +
            math.sin(
              (x / size.width * 2 * math.pi) +
                  phase +
                  i,
            ) *
                10;

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, wavePaint);
    }

    // Pequeñas partículas luminosas.
    final particles = [
      Offset(size.width * 0.82, size.height * 0.15),
      Offset(size.width * 0.68, size.height * 0.62),
      Offset(size.width * 0.95, size.height * 0.78),
    ];

    for (int i = 0; i < particles.length; i++) {
      final alpha =
          0.18 + (math.sin(phase + i) + 1) * 0.12;

      final particlePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(
        particles[i],
        i == 0 ? 3.0 : 2.0,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _HeaderBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}
