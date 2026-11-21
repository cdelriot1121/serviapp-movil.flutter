import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../fallas/data/models/falla.dart';
import '../../../fallas/presentation/widgets/tarjeta_falla.dart';
import '../../data/models/corte_admin.dart';
import '../../data/services/admin_service.dart';
import 'programar_corte_screen.dart';

/// Cortes programados (como "Cortes" en la web). Programar uno avisa por push
/// a los usuarios de sus barrios; cancelarlo les avisa que ya no se hará.
class AdminCortesScreen extends StatefulWidget {
  /// Permite usar datos de prueba en los tests.
  final AdminService? servicio;

  const AdminCortesScreen({super.key, this.servicio});

  @override
  State<AdminCortesScreen> createState() => _AdminCortesScreenState();
}

class _AdminCortesScreenState extends State<AdminCortesScreen> {
  late final AdminService _service = widget.servicio ?? AdminService();

  List<CorteAdmin>? _cortes;
  String? _error;
  bool _verHistorial = false;
  final Set<String> _cancelando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final cortes = await _service.cortes();
      if (mounted) setState(() => _cortes = cortes);
    } on AdminException catch (e) {
      if (mounted) {
        setState(() {
          _cortes ??= const [];
          _error = e.mensaje;
        });
      }
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _programar() async {
    final resultado = await Navigator.of(context).push<CorteProgramadoResultado>(
      MaterialPageRoute(builder: (_) => ProgramarCorteScreen(servicio: widget.servicio)),
    );
    if (resultado == null || !mounted) return;
    final n = resultado.usuariosNotificados;
    _avisar(n == 0
        ? 'Corte programado. Aún no hay usuarios en esos barrios para avisar.'
        : 'Corte programado. Avisamos a $n ${n == 1 ? 'usuario' : 'usuarios'}.');
    setState(() => _verHistorial = false);
    await _cargar();
  }

  Future<void> _cancelar(CorteAdmin corte) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.event_available_rounded, size: 40, color: AppColors.red),
        title: const Text('¿Cancelar este corte?'),
        content: Text(
          corte.usuariosAfectados == 0
              ? 'El corte de ${corte.nombreServicio.toLowerCase()} dejará de aparecer en la app.'
              : 'Avisaremos a los ${corte.usuariosAfectados} usuarios de los barrios afectados '
                  'que el corte de ${corte.nombreServicio.toLowerCase()} ya no se hará.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Cancelar corte'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cancelando.add(corte.id));
    try {
      final n = await _service.cancelarCorte(corte.id);
      if (!mounted) return;
      setState(() => _cortes = [for (final c in _cortes!) if (c.id != corte.id) c]);
      _avisar(n == 0 ? 'Corte cancelado.' : 'Corte cancelado. Avisamos a $n ${n == 1 ? 'usuario' : 'usuarios'}.');
    } on AdminException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cancelando.remove(corte.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cortes = _cortes;
    final vigentes = [for (final c in cortes ?? const <CorteAdmin>[]) if (c.vigente) c];
    final historial = [for (final c in cortes ?? const <CorteAdmin>[]) if (!c.vigente) c];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Cortes programados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _programar,
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Programar corte'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.event_busy_rounded),
                  label: Text('Vigentes · ${vigentes.length}'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.history_rounded),
                  label: Text('Historial · ${historial.length}'),
                ),
              ],
              selected: {_verHistorial},
              onSelectionChanged: (s) => setState(() => _verHistorial = s.first),
            ),
          ),
          Expanded(child: _buildLista(_verHistorial ? historial : vigentes)),
        ],
      ),
    );
  }

  Widget _buildLista(List<CorteAdmin> lista) {
    if (_cortes == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _cortes!.isEmpty) {
      return Center(
        child: MensajeFallas(icono: Icons.cloud_off_rounded, texto: _error!, accion: 'Reintentar', onAccion: _cargar),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: lista.isEmpty
          ? ListView(
              children: [
                MensajeFallas(
                  icono: _verHistorial ? Icons.history_toggle_off_rounded : Icons.event_available_rounded,
                  color: _verHistorial ? null : AppColors.green,
                  texto: _verHistorial
                      ? 'Aún no hay cortes terminados.'
                      : 'No hay cortes programados.\nCuando programes uno, los usuarios de esos barrios '
                          'recibirán una notificación.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => TarjetaCorteAdmin(
                corte: lista[i],
                cancelando: _cancelando.contains(lista[i].id),
                onCancelar: lista[i].vigente ? () => _cancelar(lista[i]) : null,
              ),
            ),
    );
  }
}

/// Tarjeta de un corte: servicio, día, horario, motivo, barrios y alcance.
class TarjetaCorteAdmin extends StatelessWidget {
  final CorteAdmin corte;
  final bool cancelando;
  final VoidCallback? onCancelar;

  const TarjetaCorteAdmin({super.key, required this.corte, this.cancelando = false, this.onCancelar});

  /// Barrios que se muestran antes de "+N más".
  static const maxBarrios = 6;

  @override
  Widget build(BuildContext context) {
    final color = corte.servicio?.color ?? AppColors.red;
    final motivo = corte.motivo?.trim() ?? '';
    final dia = diaRelativo(corte.fecha);
    final esHoy = dia == 'Hoy';
    final visibles = corte.barrios.take(maxBarrios).toList();
    final resto = corte.barrios.length - visibles.length;

    return Opacity(
      opacity: corte.vigente ? 1 : 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: corte.vigente ? color.withValues(alpha: 0.35) : AppColors.border),
          boxShadow: [
            if (corte.vigente)
              BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Franja del color del servicio
            Container(height: 5, color: corte.vigente ? color : AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(corte.servicio?.icono ?? Icons.event_busy_rounded, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Corte de ${corte.nombreServicio.toLowerCase()}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$dia · ${corte.horario}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: corte.vigente ? AppColors.red : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Estado(
                        texto: !corte.vigente ? 'Terminado' : (esHoy ? 'Hoy' : 'Programado'),
                        color: !corte.vigente ? AppColors.textSecondary : (esHoy ? AppColors.red : AppColors.orange),
                      ),
                    ],
                  ),
                  if (motivo.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        motivo,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                  if (corte.barrios.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final b in visibles) _Barrio(texto: nombreBarrio(b)),
                        if (resto > 0) _Barrio(texto: '+$resto más', destacado: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, size: 17, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${corte.barrios.length} ${corte.barrios.length == 1 ? 'barrio' : 'barrios'}'
                          ' · ${corte.usuariosAfectados} '
                          '${corte.usuariosAfectados == 1 ? 'usuario' : 'usuarios'} en la zona',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ),
                      if (onCancelar != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.red,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: cancelando ? null : onCancelar,
                          icon: cancelando
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Cancelar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  final String texto;
  final Color color;

  const _Estado({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Barrio extends StatelessWidget {
  final String texto;
  final bool destacado;

  const _Barrio({required this.texto, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: destacado ? AppColors.primary.withValues(alpha: 0.10) : AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: destacado ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!destacado) ...[
            const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: destacado ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
