import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../predio/presentation/registro_predio_screen.dart' show SelectorBarrio;
import '../../data/models/falla.dart';
import '../../data/services/fallas_service.dart';

/// Formulario de reporte, con los mismos campos de la web: servicio, barrio
/// afectado, hora aproximada de inicio y comentario. Devuelve la falla creada
/// y cuántos vecinos recibieron el aviso.
class ReportarFallaScreen extends StatefulWidget {
  /// Fallas activas del barrio del usuario, para sugerir confirmar en vez de repetir.
  final ResumenBarrio? barrio;

  const ReportarFallaScreen({super.key, this.barrio});

  @override
  State<ReportarFallaScreen> createState() => _ReportarFallaScreenState();
}

class _ReportarFallaScreenState extends State<ReportarFallaScreen> {
  static const _maxComentario = 500;

  final _service = FallasService();
  final _comentario = TextEditingController();

  OpcionesFalla? _opciones;
  String? _errorOpciones;

  ServicioFalla? _servicio;
  String? _barrio;
  TimeOfDay _hora = TimeOfDay.now();
  bool _enviando = false;
  bool _mostrarErrores = false;

  @override
  void initState() {
    super.initState();
    _barrio = widget.barrio?.barrio;
    _cargarOpciones();
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _cargarOpciones() async {
    setState(() => _errorOpciones = null);
    try {
      final opciones = await _service.opciones();
      if (!mounted) return;
      setState(() {
        _opciones = opciones;
        _barrio ??= opciones.miBarrio;
      });
    } on FallaException catch (e) {
      if (mounted) setState(() => _errorOpciones = e.mensaje);
    }
  }

  // Fallas activas del mismo servicio que ya reportaron vecinos en ese barrio
  List<Falla> get _yaReportadas {
    final resumen = widget.barrio;
    if (resumen == null || _servicio == null || _barrio != resumen.barrio) return const [];
    return resumen.fallas.where((f) => f.servicio == _servicio && !f.esMia).toList();
  }

  Future<void> _elegirBarrio() async {
    final barrios = _opciones?.barrios ?? const <String>[];
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SelectorBarrio(barrios: barrios, seleccionado: _barrio),
    );
    if (elegido != null) setState(() => _barrio = elegido);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora,
      helpText: '¿A qué hora empezó la falla?',
    );
    if (hora != null) setState(() => _hora = hora);
  }

  String get _horaTexto =>
      '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  Future<void> _enviar() async {
    setState(() => _mostrarErrores = true);
    final servicio = _servicio;
    final barrio = _barrio;
    if (servicio == null || barrio == null) return;

    setState(() => _enviando = true);
    try {
      final resultado = await _service.reportar(
        servicio: servicio,
        barrio: barrio,
        horaInicio: _horaTexto,
        comentarios: _comentario.text.trim().isEmpty ? null : _comentario.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(resultado);
    } on FallaException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      if (e.repetida) {
        await showDialog<void>(
          context: context,
          builder: (dialogo) => AlertDialog(
            icon: const Icon(Icons.info_outline_rounded, size: 40, color: AppColors.primary),
            title: const Text('Ya la reportaste'),
            content: Text(e.mensaje, textAlign: TextAlign.center),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Entendido')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar falla')),
      body: _opciones == null
          ? Center(
              child: _errorOpciones == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 60, color: AppColors.border),
                          const SizedBox(height: 12),
                          Text(_errorOpciones!, textAlign: TextAlign.center),
                          TextButton(onPressed: _cargarOpciones, child: const Text('Reintentar')),
                        ],
                      ),
                    ),
            )
          : _buildFormulario(),
    );
  }

  Widget _buildFormulario() {
    final yaReportadas = _yaReportadas;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Cuéntanos qué servicio falla. Avisaremos a los vecinos de ese barrio '
            'y podrás seguir el estado de tu reporte.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          Text('Servicio afectado', style: estiloTitulo(16)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in ServicioFalla.values) ...[
                if (s.index > 0) const SizedBox(width: 10),
                Expanded(child: _OpcionServicio(
                  servicio: s,
                  seleccionado: _servicio == s,
                  onTap: () => setState(() => _servicio = s),
                )),
              ],
            ],
          ),
          if (_mostrarErrores && _servicio == null)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('Selecciona el servicio', style: TextStyle(color: AppColors.red, fontSize: 12.5)),
            ),
          const SizedBox(height: 22),
          Text('Barrio afectado', style: estiloTitulo(16)),
          const SizedBox(height: 10),
          _Campo(
            icono: Icons.location_on_outlined,
            texto: _barrio == null ? 'Selecciona el barrio' : nombreBarrio(_barrio),
            vacio: _barrio == null,
            detalle: _barrio != null && _barrio == _opciones?.miBarrio ? 'Tu barrio' : null,
            error: _mostrarErrores && _barrio == null,
            onTap: _elegirBarrio,
          ),
          const SizedBox(height: 22),
          Text('¿Desde qué hora?', style: estiloTitulo(16)),
          const SizedBox(height: 10),
          _Campo(
            icono: Icons.schedule_rounded,
            texto: _hora.format(context),
            detalle: 'Aproximada',
            onTap: _elegirHora,
          ),
          if (yaReportadas.isNotEmpty) ...[
            const SizedBox(height: 18),
            _AvisoYaReportada(fallas: yaReportadas),
          ],
          const SizedBox(height: 22),
          Text('Comentario (opcional)', style: estiloTitulo(16)),
          const SizedBox(height: 10),
          TextField(
            controller: _comentario,
            maxLines: 4,
            maxLength: _maxComentario,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ej.: Se fue la luz en toda la cuadra después de un ruido en el transformador.',
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.campaign_rounded),
            label: Text(_enviando ? 'Reportando…' : 'Reportar falla'),
          ),
        ],
      ),
    );
  }
}

class _OpcionServicio extends StatelessWidget {
  final ServicioFalla servicio;
  final bool seleccionado;
  final VoidCallback onTap;

  const _OpcionServicio({required this.servicio, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = servicio.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: seleccionado ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: seleccionado ? color : AppColors.border, width: seleccionado ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(servicio.icono, color: color, size: 30),
                const SizedBox(height: 6),
                Text(
                  servicio.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: seleccionado ? color : AppColors.textPrimary,
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

class _Campo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? detalle;
  final bool vacio;
  final bool error;
  final VoidCallback onTap;

  const _Campo({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.detalle,
    this.vacio = false,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: error ? AppColors.red : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icono, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 16,
                    color: vacio ? AppColors.textSecondary : AppColors.textPrimary,
                    fontWeight: vacio ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              if (detalle != null)
                Text(detalle!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// Sugiere confirmar la falla existente en lugar de repetir el reporte.
class _AvisoYaReportada extends StatelessWidget {
  final List<Falla> fallas;

  const _AvisoYaReportada({required this.fallas});

  @override
  Widget build(BuildContext context) {
    final f = fallas.first;
    final otros = fallas.length > 1 ? ' (y ${fallas.length - 1} más)' : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sun.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sun.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFB7791F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Un vecino ya reportó esta falla ${haceCuanto(f.fechaReporte)}$otros. '
              'Si es la misma, puedes volver y tocar "A mí también me pasa" en Mi barrio.',
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
