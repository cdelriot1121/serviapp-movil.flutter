import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../notificaciones/notificaciones_service.dart';
import '../../data/models/falla.dart';
import '../../data/services/fallas_service.dart';
import '../widgets/tarjeta_falla.dart';
import 'reportar_falla_screen.dart';

/// Fallas y cortes: lo que pasa en el barrio del usuario (filtro por zona,
/// igual que en la web) y el historial de las fallas que ha reportado.
class FallasScreen extends StatefulWidget {
  /// 0 = Mi barrio, 1 = Mis reportes.
  final int pestanaInicial;

  const FallasScreen({super.key, this.pestanaInicial = 0});

  @override
  State<FallasScreen> createState() => _FallasScreenState();
}

enum _Filtro { todas, activas, solucionadas }

class _FallasScreenState extends State<FallasScreen> with SingleTickerProviderStateMixin {
  final _service = FallasService();
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.pestanaInicial.clamp(0, 1),
  );

  ResumenBarrio? _barrio;
  String? _errorBarrio;

  List<Falla>? _mias;
  String? _errorMias;
  _Filtro _filtro = _Filtro.todas;

  // Fallas con una petición en curso (para desactivar sus botones)
  final Set<String> _ocupadas = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    // Avisos nuevos (otra falla en el barrio, cambio de estado...): se recarga
    NotificacionesService.cambios.addListener(_cargar);
  }

  @override
  void dispose() {
    NotificacionesService.cambios.removeListener(_cargar);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() => Future.wait([_cargarBarrio(), _cargarMias()]);

  Future<void> _cargarBarrio() async {
    try {
      final datos = await _service.delBarrio();
      if (mounted) {
        setState(() {
          _barrio = datos;
          _errorBarrio = null;
        });
      }
    } on FallaException catch (e) {
      if (mounted) setState(() => _errorBarrio = e.mensaje);
    }
  }

  Future<void> _cargarMias() async {
    try {
      final datos = await _service.misFallas();
      if (mounted) {
        setState(() {
          _mias = datos;
          _errorMias = null;
        });
      }
    } on FallaException catch (e) {
      if (mounted) setState(() => _errorMias = e.mensaje);
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ------------------------------------------------------------- acciones

  Future<void> _reportar() async {
    final resultado = await Navigator.of(context).push<({Falla falla, int vecinos})>(
      MaterialPageRoute(builder: (_) => ReportarFallaScreen(barrio: _barrio)),
    );
    if (resultado == null || !mounted) return;

    _tabs.animateTo(1);
    _avisar(resultado.vecinos > 0
        ? 'Falla reportada. Avisamos a ${resultado.vecinos} '
            '${resultado.vecinos == 1 ? 'vecino' : 'vecinos'} de ${nombreBarrio(resultado.falla.barrio)}.'
        : 'Falla reportada. Puedes seguir su estado en Mis reportes.');
    _cargar();
  }

  Future<void> _confirmar(Falla falla) async {
    setState(() => _ocupadas.add(falla.id));
    try {
      final r = await _service.confirmar(falla.id);
      if (!mounted) return;
      setState(() {
        final barrio = _barrio;
        if (barrio != null) {
          _barrio = ResumenBarrio(
            barrio: barrio.barrio,
            cortes: barrio.cortes,
            fallas: [
              for (final f in barrio.fallas)
                f.id == falla.id ? f.copiar(yoConfirme: r.confirmada, confirmaciones: r.confirmaciones) : f,
            ],
          );
        }
      });
      if (r.confirmada) _avisar('Gracias. Te avisaremos cuando se solucione.');
    } on FallaException catch (e) {
      _avisar(e.mensaje);
      _cargarBarrio();
    } finally {
      if (mounted) setState(() => _ocupadas.remove(falla.id));
    }
  }

  Future<void> _solucionada(Falla falla) async {
    final ok = await _confirmarDialogo(
      icono: Icons.check_circle_rounded,
      color: AppColors.green,
      titulo: '¿Ya volvió el servicio?',
      texto: 'Marcaremos tu falla de ${falla.nombreServicio.toLowerCase()} como solucionada '
          'y avisaremos a los vecinos que también la tenían.',
      accion: 'Sí, ya se solucionó',
    );
    if (!ok) return;

    setState(() => _ocupadas.add(falla.id));
    try {
      await _service.marcarSolucionada(falla.id);
      _avisar('¡Qué bien! Marcamos tu falla como solucionada.');
      await _cargar();
    } on FallaException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupadas.remove(falla.id));
    }
  }

  Future<void> _eliminar(Falla falla) async {
    final ok = await _confirmarDialogo(
      icono: Icons.delete_outline_rounded,
      color: AppColors.red,
      titulo: '¿Eliminar este reporte?',
      texto: 'Úsalo si lo reportaste por error. Esta acción no se puede deshacer.',
      accion: 'Eliminar',
    );
    if (!ok) return;

    setState(() => _ocupadas.add(falla.id));
    try {
      await _service.eliminar(falla.id);
      _avisar('Reporte eliminado.');
      await _cargar();
    } on FallaException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupadas.remove(falla.id));
    }
  }

  Future<bool> _confirmarDialogo({
    required IconData icono,
    required Color color,
    required String titulo,
    required String texto,
    required String accion,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: Icon(icono, size: 40, color: color),
        title: Text(titulo),
        content: Text(texto, textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: color),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return r == true;
  }

  // ------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fallas y cortes'),
        actions: const [BotonInicio()],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.location_on_outlined, size: 20), text: 'Mi barrio', iconMargin: EdgeInsets.only(bottom: 2)),
            Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Mis reportes', iconMargin: EdgeInsets.only(bottom: 2)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _reportar,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Reportar falla'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildBarrio(), _buildMias()],
      ),
    );
  }

  Widget _buildBarrio() {
    final datos = _barrio;
    if (datos == null) {
      return _errorBarrio == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: MensajeFallas(
                icono: Icons.cloud_off_rounded,
                texto: _errorBarrio!,
                accion: 'Reintentar',
                onAccion: _cargarBarrio,
              ),
            );
    }
    if (datos.barrio == null) {
      return const Center(
        child: MensajeFallas(
          icono: Icons.home_work_outlined,
          texto: 'Registra tu predio en Mi perfil para ver las fallas y cortes de tu barrio.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarBarrio,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _EncabezadoBarrio(resumen: datos),
          if (datos.cortes.isNotEmpty) ...[
            const SizedBox(height: 22),
            _titulo('Cortes programados', Icons.event_busy_rounded, AppColors.red),
            const SizedBox(height: 10),
            for (final c in datos.cortes) ...[
              _TarjetaCorte(corte: c),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 22),
          _titulo('Fallas reportadas', Icons.report_problem_rounded, AppColors.orange),
          const SizedBox(height: 4),
          const Text(
            'Si a ti también te pasa, confírmalo: así la empresa ve cuántas casas están afectadas.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (datos.fallas.isEmpty)
            const MensajeFallas(
              icono: Icons.verified_rounded,
              color: AppColors.leafLight,
              texto: 'No hay fallas activas en tu barrio.\n¡Todo en orden por ahora!',
            )
          else
            for (final f in datos.fallas) ...[
              TarjetaFalla(
                falla: f,
                mostrarBarrio: false,
                pie: f.esMia ? _pieMia() : _botonTambien(f),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _pieMia() => const Row(
        children: [
          Icon(Icons.person_pin_circle_rounded, size: 18, color: AppColors.primary),
          SizedBox(width: 6),
          Text(
            'Tú reportaste esta falla',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      );

  Widget _botonTambien(Falla f) {
    final ocupada = _ocupadas.contains(f.id);
    final onPressed = ocupada ? null : () => _confirmar(f);
    const icono = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    return SizedBox(
      width: double.infinity,
      child: f.yoConfirme
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: ocupada ? icono : const Icon(Icons.check_rounded),
              label: const Text('Confirmaste que también te pasa'),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: ocupada ? icono : const Icon(Icons.front_hand_rounded),
              label: const Text('A mí también me pasa'),
            ),
    );
  }

  Widget _buildMias() {
    final mias = _mias;
    if (mias == null) {
      return _errorMias == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: MensajeFallas(
                icono: Icons.cloud_off_rounded,
                texto: _errorMias!,
                accion: 'Reintentar',
                onAccion: _cargarMias,
              ),
            );
    }

    final visibles = switch (_filtro) {
      _Filtro.todas => mias,
      _Filtro.activas => mias.where((f) => f.activa).toList(),
      _Filtro.solucionadas => mias.where((f) => !f.activa).toList(),
    };
    final activas = mias.where((f) => f.activa).length;

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip(_Filtro.todas, 'Todas (${mias.length})'),
              _chip(_Filtro.activas, 'Activas ($activas)'),
              _chip(_Filtro.solucionadas, 'Solucionadas (${mias.length - activas})'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarMias,
            child: visibles.isEmpty
                ? ListView(
                    children: [
                      MensajeFallas(
                        icono: Icons.inbox_outlined,
                        texto: mias.isEmpty
                            ? 'Aún no has reportado fallas.\nCuando falle un servicio en tu zona, repórtalo y avisaremos a tus vecinos.'
                            : 'No tienes fallas en este filtro.',
                        accion: mias.isEmpty ? 'Reportar falla' : null,
                        onAccion: mias.isEmpty ? _reportar : null,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _tarjetaMia(visibles[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaMia(Falla f) {
    final ocupada = _ocupadas.contains(f.id);
    return TarjetaFalla(
      falla: f,
      pie: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProgresoFalla(estado: f.estado),
          if (!f.activa && f.fechaSolucion != null) ...[
            const SizedBox(height: 10),
            Text(
              'Solucionada ${haceCuanto(f.fechaSolucion)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.green, fontWeight: FontWeight.w600),
            ),
          ],
          if (f.activa) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (f.estado == EstadoFalla.pendiente) ...[
                  IconButton(
                    tooltip: 'Eliminar reporte',
                    onPressed: ocupada ? null : () => _eliminar(f),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    onPressed: ocupada ? null : () => _solucionada(f),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Ya se solucionó'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(_Filtro filtro, String texto) {
    final seleccionado = _filtro == filtro;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: seleccionado,
        label: Text(texto),
        showCheckmark: false,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filtro = filtro),
      ),
    );
  }

  Widget _titulo(String texto, IconData icono, Color color) => Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 8),
          Text(texto, style: estiloTitulo(17)),
        ],
      );
}

// Barrio del predio con el resumen de lo que pasa en él.
class _EncabezadoBarrio extends StatelessWidget {
  final ResumenBarrio resumen;

  const _EncabezadoBarrio({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final fallas = resumen.fallas.length;
    final cortes = resumen.cortes.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.naturaleza,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu barrio',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                ),
                Text(
                  nombreBarrio(resumen.barrio),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estiloTitulo(21, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fallas == 1 ? '1 falla activa' : '$fallas fallas activas'} · '
                  '${cortes == 1 ? '1 corte programado' : '$cortes cortes programados'}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCorte extends StatelessWidget {
  final CorteProgramado corte;

  const _TarjetaCorte({required this.corte});

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

  String get _cuando {
    final f = corte.fecha;
    final hoy = DateTime.now();
    final dia = f == null
        ? ''
        : (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day)
            ? 'Hoy'
            : '${_dias[f.weekday - 1][0].toUpperCase()}${_dias[f.weekday - 1].substring(1)} '
                '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
    final horario = corte.horaInicio == null ? '' : ' · ${corte.horaInicio} – ${corte.horaFinal ?? ''}';
    return '$dia$horario';
  }

  @override
  Widget build(BuildContext context) {
    final servicio = corte.servicio;
    final color = servicio?.color ?? AppColors.red;
    final motivo = corte.motivo?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(servicio?.icono ?? Icons.event_busy_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corte de ${(servicio?.nombre ?? 'servicio').toLowerCase()}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _cuando,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red),
                ),
                if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    motivo,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
