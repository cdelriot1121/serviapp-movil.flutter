import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/falla.dart';

/// Quita una foto; devuelve true si se quitó (para cerrar el visor).
typedef EliminarFoto = Future<bool> Function(FotoFalla foto);

/// Foto de una falla guardada en el celular por su id: el enlace de S3 vence
/// en una hora, pero la foto nunca cambia.
class ImagenFalla extends StatelessWidget {
  final FotoFalla foto;
  final bool miniatura;
  final BoxFit fit;

  const ImagenFalla({super.key, required this.foto, this.miniatura = false, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: miniatura ? foto.miniatura : foto.url,
      cacheKey: miniatura ? foto.claveCacheMiniatura : foto.claveCache,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => Container(
        color: miniatura ? AppColors.border.withValues(alpha: 0.5) : Colors.black,
        alignment: Alignment.center,
        child: miniatura ? null : const CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (_, _, _) => Container(
        color: miniatura ? AppColors.border.withValues(alpha: 0.5) : Colors.black,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: miniatura ? AppColors.textSecondary : Colors.white70,
          size: miniatura ? 24 : 48,
        ),
      ),
    );
  }
}

/// Miniaturas de la tarjeta de una falla. Al tocarlas se abre el visor.
class MiniaturasFalla extends StatelessWidget {
  final List<FotoFalla> fotos;
  final EliminarFoto? onEliminar;

  const MiniaturasFalla({super.key, required this.fotos, this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fotos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Semantics(
          button: true,
          label: 'Ver foto ${i + 1} de ${fotos.length}',
          child: GestureDetector(
            onTap: () => VisorFotosFalla.abrir(context, fotos: fotos, inicial: i, onEliminar: onEliminar),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 76, height: 76, child: ImagenFalla(foto: fotos[i], miniatura: true)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fotos en pantalla completa, con zoom y deslizando entre ellas. Con
/// [onEliminar] (quien reportó o un administrador) se puede quitar una.
class VisorFotosFalla extends StatefulWidget {
  final List<FotoFalla> fotos;
  final int inicial;
  final EliminarFoto? onEliminar;

  const VisorFotosFalla({super.key, required this.fotos, this.inicial = 0, this.onEliminar});

  static Future<void> abrir(
    BuildContext context, {
    required List<FotoFalla> fotos,
    int inicial = 0,
    EliminarFoto? onEliminar,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisorFotosFalla(fotos: fotos, inicial: inicial, onEliminar: onEliminar),
      ),
    );
  }

  @override
  State<VisorFotosFalla> createState() => _VisorFotosFallaState();
}

class _VisorFotosFallaState extends State<VisorFotosFalla> {
  late final PageController _paginas = PageController(initialPage: widget.inicial);
  late int _actual = widget.inicial;
  bool _eliminando = false;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    final onEliminar = widget.onEliminar;
    if (onEliminar == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, size: 40, color: AppColors.red),
        title: const Text('¿Quitar esta foto?'),
        content: const Text(
          'Dejará de verse en el reporte. Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _eliminando = true);
    final quitada = await onEliminar(widget.fotos[_actual]);
    if (!mounted) return;
    if (quitada) {
      Navigator.of(context).pop();
    } else {
      setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.fotos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(total > 1 ? 'Foto ${_actual + 1} de $total' : 'Foto del reporte'),
        actions: [
          if (widget.onEliminar != null)
            _eliminando
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    tooltip: 'Quitar foto',
                    onPressed: _eliminar,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
        ],
      ),
      body: PageView.builder(
        controller: _paginas,
        itemCount: total,
        onPageChanged: (i) => setState(() => _actual = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(child: ImagenFalla(foto: widget.fotos[i], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
