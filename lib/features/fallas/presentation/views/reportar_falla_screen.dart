import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../predio/presentation/registro_predio_screen.dart' show SelectorBarrio;
import '../../data/models/falla.dart';
import '../../data/services/fallas_service.dart';

/// Formulario de reporte, con los mismos campos de la web: servicio, barrio
/// afectado, hora aproximada de inicio y comentario, más fotos opcionales
/// (cámara o galería). Devuelve la falla creada y cuántos vecinos recibieron
/// el aviso.
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

  // Fotos ya comprimidas, listas para enviar
  final List<Uint8List> _fotos = [];
  bool _preparandoFoto = false;

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

  int get _maxFotos => _opciones?.maxFotos ?? 0;

  // ------------------------------------------------------------- fotos

  Future<void> _agregarFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(hoja).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(hoja).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    final restantes = _maxFotos - _fotos.length;
    final picker = ImagePicker();
    List<XFile> elegidas;
    try {
      if (origen == ImageSource.gallery && restantes > 1) {
        elegidas = await picker.pickMultiImage(limit: restantes);
      } else {
        final una = await picker.pickImage(source: origen);
        elegidas = una == null ? const [] : [una];
      }
    } catch (_) {
      _avisar('No pudimos abrir la ${origen == ImageSource.camera ? 'cámara' : 'galería'}. Revisa los permisos de ServiApp.');
      return;
    }
    if (elegidas.isEmpty || !mounted) return;

    setState(() => _preparandoFoto = true);
    var fallidas = 0;
    for (final archivo in elegidas.take(restantes)) {
      final foto = await _comprimir(archivo);
      if (foto == null) {
        fallidas++;
      } else if (mounted) {
        setState(() => _fotos.add(foto));
      }
    }
    if (!mounted) return;
    setState(() => _preparandoFoto = false);
    if (fallidas > 0) _avisar('No pudimos usar ${fallidas == 1 ? 'una foto' : '$fallidas fotos'}. Intenta con otra.');
    if (elegidas.length > restantes) _avisar('Solo puedes adjuntar $_maxFotos fotos.');
  }

  /// JPEG de unos 300 KB, derecho y sin metadatos (como la ubicación GPS).
  static Future<Uint8List?> _comprimir(XFile archivo) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        archivo.path,
        minWidth: 1280,
        minHeight: 1280,
        quality: 80,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
    } catch (_) {
      return null;
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ------------------------------------------------------------- enviar

  Future<void> _enviar({bool sinFotos = false}) async {
    setState(() => _mostrarErrores = true);
    final servicio = _servicio;
    final barrio = _barrio;
    if (servicio == null || barrio == null || _preparandoFoto) return;

    setState(() => _enviando = true);
    try {
      final resultado = await _service.reportar(
        servicio: servicio,
        barrio: barrio,
        horaInicio: _horaTexto,
        comentarios: _comentario.text.trim().isEmpty ? null : _comentario.text.trim(),
        fotos: sinFotos ? const [] : List.of(_fotos),
      );
      if (mounted) Navigator.of(context).pop(resultado);
    } on FallaException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      if (e.codigo == 'FOTOS_NO_DISPONIBLES') {
        final enviar = await showDialog<bool>(
          context: context,
          builder: (dialogo) => AlertDialog(
            icon: const Icon(Icons.no_photography_outlined, size: 40, color: AppColors.orange),
            title: const Text('No se pudieron subir las fotos'),
            content: Text(e.mensaje, textAlign: TextAlign.center),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Volver')),
              TextButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Enviar sin fotos')),
            ],
          ),
        );
        if (enviar == true && mounted) await _enviar(sinFotos: true);
      } else if (e.repetida || e.codigo == 'LIMITE_DIARIO') {
        await showDialog<void>(
          context: context,
          builder: (dialogo) => AlertDialog(
            icon: const Icon(Icons.info_outline_rounded, size: 40, color: AppColors.primary),
            title: Text(e.repetida ? 'Ya la reportaste' : 'Límite de reportes de hoy'),
            content: Text(e.mensaje, textAlign: TextAlign.center),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Entendido')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.mensaje),
          // Sin código: no hubo respuesta del servidor (sin internet)
          action: e.codigo == null
              ? SnackBarAction(label: 'Reintentar', onPressed: () => _enviar(sinFotos: sinFotos))
              : null,
        ));
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
          if (_opciones?.fotosHabilitadas == true && _maxFotos > 0) ...[
            const SizedBox(height: 14),
            Text('Fotos (opcional)', style: estiloTitulo(16)),
            const SizedBox(height: 4),
            Text(
              'Hasta $_maxFotos fotos del daño: un poste caído, una fuga, el contador… '
              'Evita que se vean caras o placas de carros.',
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            _SeccionFotos(
              fotos: _fotos,
              maximo: _maxFotos,
              preparando: _preparandoFoto,
              onAgregar: _enviando ? null : _agregarFoto,
              onQuitar: _enviando ? null : (i) => setState(() => _fotos.removeAt(i)),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _enviando || _preparandoFoto ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.campaign_rounded),
            label: Text(_enviando
                ? (_fotos.isEmpty ? 'Reportando…' : 'Subiendo fotos…')
                : 'Reportar falla'),
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

/// Fotos elegidas (con una X para quitarlas) y el cuadro para agregar otra.
class _SeccionFotos extends StatelessWidget {
  final List<Uint8List> fotos;
  final int maximo;
  final bool preparando;
  final VoidCallback? onAgregar;
  final void Function(int indice)? onQuitar;

  const _SeccionFotos({
    required this.fotos,
    required this.maximo,
    required this.preparando,
    required this.onAgregar,
    required this.onQuitar,
  });

  static const _lado = 88.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < fotos.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(fotos[i], width: _lado, height: _lado, fit: BoxFit.cover),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: Material(
                  color: AppColors.textPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onQuitar == null ? null : () => onQuitar!(i),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white, semanticLabel: 'Quitar foto'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (preparando)
          Container(
            width: _lado,
            height: _lado,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (fotos.length < maximo)
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onAgregar,
              child: Container(
                width: _lado,
                height: _lado,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(
                      fotos.isEmpty ? 'Agregar' : '${fotos.length}/$maximo',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
