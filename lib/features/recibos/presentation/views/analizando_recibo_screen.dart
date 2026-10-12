import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../data/models/recibo.dart';
import '../../data/services/recibo_service.dart';
import 'revisar_recibo_screen.dart';

/// Envía la foto a FastAPI y muestra el progreso mientras se analiza.
class AnalizandoReciboScreen extends StatefulWidget {
  final String rutaImagen;
  final Empresa? empresa;

  const AnalizandoReciboScreen({
    super.key,
    required this.rutaImagen,
    this.empresa,
  });

  @override
  State<AnalizandoReciboScreen> createState() => _AnalizandoReciboScreenState();
}

class _AnalizandoReciboScreenState extends State<AnalizandoReciboScreen>
    with SingleTickerProviderStateMixin {
  final ReciboService _service = ReciboService();
  late final AnimationController _escaneo;
  Timer? _timerMensajes;

  static const _mensajes = [
    'Enderezando la foto…',
    'Mejorando el contraste…',
    'Leyendo el texto del recibo…',
    'Buscando el código de barras…',
    'Interpretando la gráfica de consumo…',
    'Validando los datos…',
  ];

  int _mensaje = 0;
  double _progresoSubida = 0;
  ReciboException? _error;

  @override
  void initState() {
    super.initState();
    _escaneo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _analizar(widget.empresa);
  }

  @override
  void dispose() {
    _escaneo.dispose();
    _timerMensajes?.cancel();
    super.dispose();
  }

  Future<void> _analizar(Empresa? empresa) async {
    setState(() {
      _error = null;
      _mensaje = 0;
      _progresoSubida = 0;
    });
    _timerMensajes?.cancel();
    _timerMensajes = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && _mensaje < _mensajes.length - 1) {
        setState(() => _mensaje++);
      }
    });

    try {
      final resultado = await _service.analizar(
        widget.rutaImagen,
        empresa: empresa,
        onProgreso: (p) {
          if (mounted) setState(() => _progresoSubida = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RevisarReciboScreen(
            resultado: resultado,
            rutaImagen: widget.rutaImagen,
          ),
        ),
      );
    } on ReciboException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _timerMensajes?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Escanear recibo'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: const [BotonInicio()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Expanded(child: _buildFoto()),
              const SizedBox(height: 24),
              _error == null ? _buildProgreso() : _buildError(_error!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(widget.rutaImagen), fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          if (_error == null)
            AnimatedBuilder(
              animation: _escaneo,
              builder: (context, _) => Align(
                alignment: Alignment(0, -1 + 2 * _escaneo.value),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7CC4FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7CC4FF).withValues(alpha: 0.8),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgreso() {
    final subiendo = _progresoSubida < 1;
    return Column(
      children: [
        Text(
          subiendo ? 'Enviando la foto…' : _mensajes[_mensaje],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: subiendo ? _progresoSubida : null,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Esto puede tardar unos segundos.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildError(ReciboException error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE5484D)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.mensaje,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (error.empresaNoReconocida) ...[
          const Text(
            '¿De qué empresa es el recibo?',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final empresa in Empresa.values)
                ActionChip(
                  avatar: Icon(empresa.icono, color: empresa.color, size: 18),
                  label: Text(empresa.nombre),
                  onPressed: () => _analizar(empresa),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ] else
          ElevatedButton.icon(
            onPressed: () => _analizar(widget.empresa),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Tomar otra foto'),
        ),
      ],
    );
  }
}
