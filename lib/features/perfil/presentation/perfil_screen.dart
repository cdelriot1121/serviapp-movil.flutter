import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../analisis/presentation/views/analisis_consumo_screen.dart';
import '../../auth/data/services/biometric_service.dart';
import '../../auth/presentation/widgets/campos_cuenta.dart';
import '../../auth/presentation/widgets/escena_naturaleza.dart';
import '../../predio/data/predio_service.dart';
import '../../predio/presentation/registro_predio_screen.dart';
import '../../recibos/presentation/utils/formatos.dart';
import '../data/perfil_service.dart';

/// "Mi perfil", con lo mismo que la web: datos personales, predio,
/// servicios del hogar y cambio de contraseña, más un resumen de actividad.
class PerfilScreen extends StatefulWidget {
  /// Avisa al inicio cuando el usuario cambia su nombre.
  final ValueChanged<String> onNombreCambiado;

  const PerfilScreen({super.key, required this.onNombreCambiado});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin, RelojEscena {
  final PerfilService _service = PerfilService();

  Perfil? _perfil;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final perfil = await _service.obtener();
      if (mounted) setState(() => _perfil = perfil);
    } on PerfilException catch (e) {
      if (!mounted) return;
      // Con el perfil ya en pantalla se avisa y se dejan los últimos datos
      if (_perfil != null) {
        _avisar(e.mensaje, error: true);
      } else {
        setState(() => _error = e.mensaje);
      }
    }
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? AppColors.red : null,
      ),
    );
  }

  // ------------------------------------------------------------ acciones

  Future<void> _editarNombre(Perfil perfil) async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EditarNombreDialog(actual: perfil.nombre, service: _service),
    );
    if (nombre == null || !mounted) return;
    widget.onNombreCambiado(nombre);
    await _cargar();
    if (mounted) _avisar('Nombre actualizado correctamente');
  }

  Future<void> _editarPredio(Predio predio) async {
    final guardado = await Navigator.of(context).push<Predio>(
      MaterialPageRoute(
        builder: (_) => RegistroPredioScreen.editar(predio: predio),
      ),
    );
    if (guardado == null || !mounted) return;
    await _cargar();
    if (mounted) _avisar('Predio actualizado exitosamente');
  }

  Future<void> _editarHabitantes(ServicioHogar servicio) async {
    final habitantes = await mostrarDialogoHabitantes(
      context,
      empresa: servicio.datosEmpresa,
      inicial: servicio.habitantes,
      confirmar: 'Guardar',
      mensaje:
          'Con este número calculamos el consumo esperado de tu hogar '
          'en los próximos análisis.',
    );
    if (habitantes == null || habitantes == servicio.habitantes) return;
    if (!mounted) return;

    try {
      await _service.actualizarHabitantes(servicio.tipoServicio, habitantes);
      if (!mounted) return;
      final perfil = _perfil!;
      setState(() {
        _perfil = Perfil(
          nombre: perfil.nombre,
          email: perfil.email,
          miembroDesde: perfil.miembroDesde,
          predio: perfil.predio,
          servicios: [
            for (final s in perfil.servicios)
              s.tipoServicio == servicio.tipoServicio
                  ? s.conHabitantes(habitantes)
                  : s,
          ],
          actividad: perfil.actividad,
        );
      });
      _avisar('Habitantes actualizados');
    } on PerfilException catch (e) {
      if (mounted) _avisar(e.mensaje, error: true);
    }
  }

  Future<void> _cambiarContrasena(Perfil perfil) async {
    final cambiada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.cream,
      builder: (_) =>
          _CambiarContrasenaSheet(email: perfil.email, service: _service),
    );
    if (cambiada == true && mounted) _avisar('¡Contraseña cambiada con éxito!');
  }

  // ------------------------------------------------------------ vista

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    if (perfil == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : _ErrorCarga(mensaje: _error!, onReintentar: _cargar),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _encabezado(perfil),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _actividad(perfil.actividad),
                    const SizedBox(height: 28),
                    _datosPersonales(perfil),
                    const SizedBox(height: 26),
                    _miPredio(perfil.predio),
                    const SizedBox(height: 26),
                    _misServicios(perfil.servicios),
                    const SizedBox(height: 26),
                    _seguridad(perfil),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _encabezado(Perfil perfil) {
    final topPadding = MediaQuery.of(context).padding.top;
    final desde = perfil.miembroDesde;

    return EncabezadoNaturaleza(
      tiempo: tiempo,
      cantidadHojas: 12,
      destellos: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 12, 20, 62),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Volver',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Mi perfil', style: estiloTitulo(20, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  _Avatar(nombre: perfil.nombre),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perfil.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: estiloTitulo(21, color: Colors.white).copyWith(
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          perfil.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        if (desde != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.eco_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Miembro desde ${mesesLargos[desde.month - 1].toLowerCase()} de ${desde.year}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actividad(ActividadPerfil actividad) {
    return Row(
      children: [
        Expanded(
          child: _Dato(
            icono: Icons.receipt_long_rounded,
            color: AppColors.primary,
            valor: actividad.recibos,
            texto: 'Recibos escaneados',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Dato(
            icono: Icons.verified_rounded,
            color: AppColors.green,
            valor: actividad.pagados,
            texto: 'Recibos pagados',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Dato(
            icono: Icons.insights_rounded,
            color: const Color(0xFFE08A00),
            valor: actividad.analisis,
            texto: 'Análisis de consumo',
          ),
        ),
      ],
    );
  }

  Widget _datosPersonales(Perfil perfil) {
    return _Seccion(
      titulo: 'Datos personales',
      icono: Icons.badge_rounded,
      child: Column(
        children: [
          _Fila(
            icono: Icons.person_outline_rounded,
            etiqueta: 'Nombre completo',
            valor: perfil.nombre,
            accion: IconButton(
              tooltip: 'Editar nombre',
              onPressed: () => _editarNombre(perfil),
              icon: const Icon(
                Icons.edit_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _Fila(
            icono: Icons.email_outlined,
            etiqueta: 'Correo electrónico',
            valor: perfil.email,
            accion: const Tooltip(
              message: 'Tu correo identifica tu cuenta y no se puede cambiar',
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miPredio(Predio? predio) {
    if (predio == null) {
      return const _Seccion(
        titulo: 'Mi predio',
        icono: Icons.home_rounded,
        child: _Vacio(
          icono: Icons.home_work_outlined,
          texto: 'Aún no tienes un predio registrado.',
        ),
      );
    }

    final esCasa = predio.tipoPredio == 'CASA';
    return _Seccion(
      titulo: 'Mi predio',
      icono: Icons.home_rounded,
      accion: TextButton.icon(
        onPressed: () => _editarPredio(predio),
        icon: const Icon(Icons.edit_rounded, size: 17),
        label: const Text('Editar'),
      ),
      child: Column(
        children: [
          _Fila(
            icono: Icons.signpost_outlined,
            etiqueta: 'Dirección',
            valor: predio.direccion,
          ),
          const Divider(height: 1, color: AppColors.border),
          _Fila(
            icono: Icons.location_city_rounded,
            etiqueta: 'Barrio',
            valor: predio.barrio,
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _Etiqueta(
                    icono: Icons.stairs_rounded,
                    texto: 'Estrato ${predio.estrato}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Etiqueta(
                    icono: esCasa
                        ? Icons.house_rounded
                        : Icons.apartment_rounded,
                    texto: predio.tipoTexto,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _misServicios(List<ServicioHogar> servicios) {
    return _Seccion(
      titulo: 'Mis servicios',
      icono: Icons.water_drop_rounded,
      child: servicios.isEmpty
          ? const _Vacio(
              icono: Icons.inventory_2_outlined,
              texto:
                  'Cuando escanees tu primer recibo, su servicio aparecerá aquí '
                  'con los datos del recibo.',
            )
          : Column(
              children: [
                for (final s in servicios) ...[
                  _FilaServicio(
                    servicio: s,
                    onEditar: () => _editarHabitantes(s),
                  ),
                  if (s != servicios.last)
                    const Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
    );
  }

  Widget _seguridad(Perfil perfil) {
    return _Seccion(
      titulo: 'Seguridad',
      icono: Icons.shield_rounded,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _cambiarContrasena(perfil),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              _IconoCirculo(
                icono: Icons.lock_reset_rounded,
                color: AppColors.primary,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cambiar contraseña',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'La misma para la app y la página web.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ piezas

/// Círculo con las iniciales del usuario.
class _Avatar extends StatelessWidget {
  final String nombre;

  const _Avatar({required this.nombre});

  String get _iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color.lerp(Colors.white, AppColors.logo, 0.22)!,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        _iniciales.isEmpty ? '?' : _iniciales,
        style: estiloTitulo(27, color: AppColors.primary),
      ),
    );
  }
}

/// Título de sección y su tarjeta blanca.
class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget? accion;
  final Widget child;

  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.child,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Icon(icono, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: estiloTitulo(17))),
              ?accion,
            ],
          ),
        ),
        const SizedBox(height: 6),
        _Tarjeta(child: child),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Tarjeta({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Número de la actividad del usuario.
class _Dato extends StatelessWidget {
  final IconData icono;
  final Color color;
  final int valor;
  final String texto;

  const _Dato({
    required this.icono,
    required this.color,
    required this.valor,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconoCirculo(icono: icono, color: color, tam: 36),
          const SizedBox(height: 10),
          Text('$valor', style: estiloTitulo(22)),
          const SizedBox(height: 2),
          Text(
            texto,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconoCirculo extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double tam;

  const _IconoCirculo({
    required this.icono,
    required this.color,
    this.tam = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.22),
          ],
        ),
      ),
      child: Icon(icono, color: color, size: tam * 0.5),
    );
  }
}

/// Dato con su icono, etiqueta y una acción opcional a la derecha.
class _Fila extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Widget? accion;

  const _Fila({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, accion == null ? 16 : 4, 12),
      child: Row(
        children: [
          Icon(icono, color: AppColors.textSecondary, size: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor.isEmpty ? '—' : valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;

  const _Etiqueta({
    required this.icono,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaServicio extends StatelessWidget {
  final ServicioHogar servicio;
  final VoidCallback onEditar;

  const _FilaServicio({required this.servicio, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final empresa = servicio.datosEmpresa;
    final color = empresa?.color ?? AppColors.primary;
    final recibos = servicio.recibos == 1
        ? '1 recibo'
        : '${servicio.recibos} recibos';
    final sinHabitantes = servicio.habitantes < 1;
    final personas = servicio.habitantes == 1
        ? '1 persona'
        : '${servicio.habitantes} personas';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      child: Row(
        children: [
          _IconoCirculo(
            icono: empresa?.icono ?? Icons.miscellaneous_services_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empresa == null
                      ? servicio.tipoServicio
                      : '${empresa.servicio} · ${empresa.nombre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${empresa?.identificador ?? 'Póliza'} ${servicio.identificador}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$recibos · último: ${formatearPeriodoLargo(servicio.ultimoPeriodo)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: color.withValues(alpha: 0.10),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onEditar,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_rounded, size: 17, color: color),
                    const SizedBox(width: 5),
                    Text(
                      sinHabitantes ? 'Indicar' : personas,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.edit_rounded, size: 13, color: color),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Vacio({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            icono,
            size: 30,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ edición

/// Cambia el nombre (el correo no se puede cambiar, igual que en la web).
/// Devuelve el nombre guardado.
class _EditarNombreDialog extends StatefulWidget {
  final String actual;
  final PerfilService service;

  const _EditarNombreDialog({required this.actual, required this.service});

  @override
  State<_EditarNombreDialog> createState() => _EditarNombreDialogState();
}

class _EditarNombreDialogState extends State<_EditarNombreDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.actual);
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final nombre = _nombre.text.trim();
    if (nombre == widget.actual) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final guardado = await widget.service.actualizarNombre(nombre);
      if (mounted) Navigator.of(context).pop(guardado);
    } on PerfilException catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.person_rounded,
        size: 40,
        color: AppColors.primary,
      ),
      title: const Text('Editar nombre'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nombre,
          autofocus: true,
          enabled: !_guardando,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          validator: validarNombre,
          onFieldSubmitted: (_) => _guardar(),
          decoration: InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Igual que "Cambiar contraseña" de la web. Si la huella está activa, guarda
/// la nueva contraseña para que siga funcionando. Devuelve true al cambiarla.
class _CambiarContrasenaSheet extends StatefulWidget {
  final String email;
  final PerfilService service;

  const _CambiarContrasenaSheet({required this.email, required this.service});

  @override
  State<_CambiarContrasenaSheet> createState() =>
      _CambiarContrasenaSheetState();
}

class _CambiarContrasenaSheetState extends State<_CambiarContrasenaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  bool _ocultar = true;
  bool _mostrarErrores = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nueva.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _mostrarErrores = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.service.cambiarContrasena(
        actual: _actual.text,
        nueva: _nueva.text,
      );
      await BiometricService().actualizarPassword(
        email: widget.email,
        password: _nueva.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on PerfilException catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono) =>
      InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        suffixIcon: IconButton(
          tooltip: _ocultar ? 'Mostrar contraseñas' : 'Ocultar contraseñas',
          icon: Icon(
            _ocultar
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _ocultar = !_ocultar),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          autovalidateMode: _mostrarErrores
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cambiar contraseña', style: estiloTitulo(21)),
              const SizedBox(height: 6),
              const Text(
                'Usarás la nueva contraseña para entrar a la app y a la página web.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _actual,
                obscureText: _ocultar,
                enabled: !_guardando,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v?.isEmpty ?? true)
                    ? 'Ingresa tu contraseña actual'
                    : null,
                decoration: _decoracion(
                  'Contraseña actual',
                  Icons.lock_outline,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nueva,
                obscureText: _ocultar,
                enabled: !_guardando,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: validarPassword,
                decoration: _decoracion(
                  'Nueva contraseña',
                  Icons.lock_reset_rounded,
                ),
              ),
              const SizedBox(height: 14),
              RequisitosPassword(password: _nueva.text),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmar,
                obscureText: _ocultar,
                enabled: !_guardando,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    v != _nueva.text ? 'Las contraseñas no coinciden' : null,
                onFieldSubmitted: (_) => _guardando ? null : _guardar(),
                decoration: _decoracion(
                  'Confirmar nueva contraseña',
                  Icons.lock_outline,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.red,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              BotonPrincipal(
                texto: 'Actualizar contraseña',
                icono: Icons.check_rounded,
                cargando: _guardando,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
