import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../../analisis/presentation/views/historial_analisis_screen.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/escanear_recibo.dart';
import '../../../recibos/presentation/utils/estado_pago.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recibos/presentation/views/detalle_recibo_screen.dart';
import '../../../recibos/presentation/views/mis_recibos_screen.dart';
import '../../../recibos/presentation/widgets/boton_pago.dart';
import '../../../recordatorios/recordatorios_service.dart';
import '../../../splash/presentation/painters/trazos.dart';
import '../widgets/escena_naturaleza.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String nombre;

  const HomeScreen({super.key, required this.nombre});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, RelojEscena {
  bool _visible = false;

  // Último recibo sin pagar de cada servicio (null mientras carga)
  List<Recibo>? _pendientes;

  @override
  void initState() {
    super.initState();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Colinas suaves al fondo de la pantalla.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _ColinasPainter(tiempo)),
              ),
            ),
          ),
          _buildContenido(),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                offset: _visible ? Offset.zero : const Offset(0, 0.10),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 650),
                  opacity: _visible ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('¿Qué hacemos hoy?', style: estiloTitulo(21)),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.eco_rounded,
                            color: AppColors.green,
                            size: 22,
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Estoy aquí para ayudarte. '
                        'Elige qué te gustaría hacer.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 26),

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
    );
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          size: 40,
          color: AppColors.green,
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

  ({String texto, IconData icono}) get _saludo {
    final hora = DateTime.now().hour;
    if (hora < 12) return (texto: 'Buenos días', icono: Icons.wb_sunny_rounded);
    if (hora < 19) {
      return (texto: 'Buenas tardes', icono: Icons.wb_twilight_rounded);
    }
    return (texto: 'Buenas noches', icono: Icons.nightlight_round);
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final saludo = _saludo;

    return EncabezadoNaturaleza(
      tiempo: tiempo,
      child: Padding(
        padding: EdgeInsets.fromLTRB(26, topPadding + 22, 26, 74),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          offset: _visible ? Offset.zero : const Offset(0, 0.08),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 700),
            opacity: _visible ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ServiApp',
                      style: estiloTitulo(23, color: Colors.white).copyWith(
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _LogoutButton(onTap: _cerrarSesion),
                  ],
                ),

                const SizedBox(height: 34),

                Row(
                  children: [
                    Icon(saludo.icono, color: AppColors.sun, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${saludo.texto}, ${widget.nombre}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  'Tu hogar, en equilibrio',
                  style: estiloTitulo(26, color: Colors.white),
                ),

                const SizedBox(height: 8),

                Text(
                  'Cuida tus servicios y ahorra con calma.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tus pagos', style: estiloTitulo(19)),
              const SizedBox(width: 8),
              const Icon(
                Icons.spa_rounded,
                color: AppColors.leafLight,
                size: 20,
              ),
            ],
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
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildToolsMenu() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 18,
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
          tono: AppColors.logo,
          colorIcono: AppColors.primary,
          indice: 0,
          tiempo: tiempo,
          visible: _visible,
          onTap: () => iniciarEscaneoRecibo(context),
        ),
        _ToolIcon(
          icon: Icons.folder_copy_outlined,
          title: 'Mis recibos',
          tono: AppColors.leafLight,
          colorIcono: AppColors.green,
          indice: 1,
          tiempo: tiempo,
          visible: _visible,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MisRecibosScreen())),
        ),
        _ToolIcon(
          icon: Icons.insights_rounded,
          title: 'Historial de consumos',
          tono: AppColors.sun,
          colorIcono: const Color(0xFFE08A00),
          indice: 2,
          tiempo: tiempo,
          visible: _visible,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistorialAnalisisScreen()),
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
    final urgente = estado.vencido || estado.dias == 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: urgente
                    ? estado.color.withValues(alpha: 0.45)
                    : AppColors.borderSoft,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        empresa.color.withValues(alpha: 0.10),
                        empresa.color.withValues(alpha: 0.22),
                      ],
                    ),
                    shape: BoxShape.circle,
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
      ),
    );
  }
}

// Botón translúcido de cerrar sesión sobre el encabezado.
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cerrar sesión',
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
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

// Herramienta con su propio tono de naturaleza: aparece escalonada y flota.
class _ToolIcon extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color tono;
  final Color colorIcono;
  final int indice;
  final ValueNotifier<double> tiempo;
  final bool visible;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.title,
    required this.tono,
    required this.colorIcono,
    required this.indice,
    required this.tiempo,
    required this.visible,
    required this.onTap,
  });

  @override
  State<_ToolIcon> createState() => _ToolIconState();
}

class _ToolIconState extends State<_ToolIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tono = widget.tono;
    final aparicion = Interval(
      widget.indice * 0.14,
      1,
      curve: Curves.easeOutBack,
    );

    final tarjeta = Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, tono, 0.16)!,
            Color.lerp(Colors.white, tono, 0.40)!,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tono.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Brillo suave, como luz de sol sobre la tarjeta.
          Positioned(
            top: 9,
            left: 11,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Icon(widget.icon, color: widget.colorIcono, size: 35),
        ],
      ),
    );

    return AnimatedScale(
      duration: const Duration(milliseconds: 900),
      curve: aparicion,
      scale: widget.visible ? 1 : 0.6,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 900),
        curve: Interval(widget.indice * 0.14, 1),
        opacity: widget.visible ? 1 : 0,
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
                scale: _pressed ? 0.92 : 1.0,
                // Flota despacio, cada una a su ritmo.
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.tiempo,
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(
                      0,
                      math.sin(t * 1.4 + widget.indice * 1.3) * 2.5,
                    ),
                    child: child,
                  ),
                  child: tarjeta,
                ),
              ),
            ),

            const SizedBox(height: 12),

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
      ),
    );
  }
}

// Colinas verdes muy suaves al pie de la pantalla, con brotes que se mecen.
class _ColinasPainter extends CustomPainter {
  _ColinasPainter(this.tiempo) : super(repaint: tiempo);

  final ValueNotifier<double> tiempo;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tiempo.value;
    final w = size.width;
    final h = size.height;

    final atras = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.28, h * 0.20, w * 0.62, h * 0.52)
      ..quadraticBezierTo(w * 0.85, h * 0.72, w, h * 0.42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      atras,
      Paint()..color = AppColors.leafLight.withValues(alpha: 0.16),
    );

    final frente = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.35, h * 0.52, w * 0.7, h * 0.74)
      ..quadraticBezierTo(w * 0.88, h * 0.84, w, h * 0.70)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      frente,
      Paint()..color = AppColors.green.withValues(alpha: 0.10),
    );

    // Brotes sobre la colina trasera, meciéndose con la brisa.
    const brotes = [(0.14, 0.43), (0.24, 0.36), (0.80, 0.60)];
    for (var k = 0; k < brotes.length; k++) {
      final (bx, by) = brotes[k];
      final base = Offset(w * bx, h * by);
      final brisa = math.sin(t * 1.1 + k * 1.4) * 0.12;
      dibujarHoja(canvas, base + const Offset(6, -6), 16, -0.7 + brisa, 0.35);
      dibujarHoja(
        canvas,
        base + const Offset(-6, -4),
        13,
        math.pi + 0.6 + brisa,
        0.30,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColinasPainter oldDelegate) =>
      oldDelegate.tiempo != tiempo;
}
