import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recibos/presentation/views/detalle_recibo_screen.dart';
import '../../data/models/analisis_consumo.dart';
import '../../data/services/analisis_service.dart';
import 'historial_analisis_screen.dart';

/// Resultado del análisis de consumo (el mismo que muestra la web al
/// registrar un consumo). Spring Boot hace todos los cálculos.
///
/// - Con [analisis]: lo muestra tal cual (desde el historial).
/// - Con [recibo]: lo pide a Spring. Si [recienGuardado], lo analiza de una;
///   si no, busca el análisis existente y solo lo calcula si falta.
class AnalisisConsumoScreen extends StatefulWidget {
  final Recibo? recibo;
  final AnalisisConsumo? analisis;
  final bool recienGuardado;

  const AnalisisConsumoScreen({
    super.key,
    this.recibo,
    this.analisis,
    this.recienGuardado = false,
  }) : assert(recibo != null || analisis != null);

  @override
  State<AnalisisConsumoScreen> createState() => _AnalisisConsumoScreenState();
}

class _AnalisisConsumoScreenState extends State<AnalisisConsumoScreen> {
  final AnalisisService _service = AnalisisService();

  late AnalisisConsumo? _analisis = widget.analisis;
  AnalisisException? _error;
  bool _cargando = false;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    if (_analisis == null) _cargar();
  }

  Future<void> _cargar({int? habitantes}) async {
    final reciboId = widget.recibo?.id;
    if (reciboId == null) return;

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      AnalisisConsumo? analisis;
      if (!widget.recienGuardado && habitantes == null) {
        analisis = await _service.obtenerPorRecibo(reciboId);
      }
      analisis ??= await _service.analizarRecibo(reciboId, habitantes: habitantes);
      if (mounted) {
        setState(() {
          _analisis = analisis;
          _cargando = false;
        });
      }
    } on AnalisisException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
      if (e.habitantesRequeridos) _pedirHabitantes();
    }
  }

  // El servicio no está registrado en Spring: se pregunta y se vuelve a analizar
  Future<void> _pedirHabitantes() async {
    final habitantes = await mostrarDialogoHabitantes(
      context,
      mensaje: _error?.mensaje,
      empresa: widget.recibo?.empresa,
    );
    if (habitantes != null && mounted) _cargar(habitantes: habitantes);
  }

  Future<void> _eliminar() async {
    final analisis = _analisis;
    if (analisis == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Eliminar análisis'),
        content: Text(
          '¿Quitar el análisis de ${analisis.tipoServicio.toLowerCase()} de '
          '${analisis.mes} ${analisis.ano} de tu historial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _eliminando = true);
    try {
      await _service.eliminar(analisis.id);
      if (mounted) Navigator.of(context).pop(true);
    } on AnalisisException catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _verRecibo() {
    final recibo = widget.recibo;
    if (recibo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalleReciboScreen(recibo: recibo)),
    );
  }

  void _verHistorial() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HistorialAnalisisScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Análisis de consumo'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Solo desde el historial: quitarlo de la lista
          if (widget.analisis != null)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _eliminando ? null : _eliminar,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const BotonInicio(),
        ],
      ),
      body: _buildCuerpo(),
    );
  }

  Widget _buildCuerpo() {
    final analisis = _analisis;
    if (analisis != null) return _buildAnalisis(analisis);

    if (_cargando || (_error == null)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'Analizando tu consumo…',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final error = _error!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error.habitantesRequeridos ? Icons.groups_rounded : Icons.cloud_off_rounded,
              size: 64,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              error.mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (error.habitantesRequeridos)
              FilledButton.icon(
                onPressed: _pedirHabitantes,
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Indicar habitantes'),
              )
            else if (!error.sesionExpirada)
              TextButton(onPressed: () => _cargar(), child: const Text('Reintentar')),
            if (widget.recibo != null)
              TextButton(onPressed: _verRecibo, child: const Text('Ver mi recibo')),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalisis(AnalisisConsumo a) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        if (widget.recienGuardado) _bannerGuardado(),
        if (a.consumoIrregular) _AdvertenciaIrregular(analisis: a),
        _CabeceraAnalisis(analisis: a),
        const SizedBox(height: 14),
        _TextoCategoria(analisis: a),
        const SizedBox(height: 14),
        _BarraComparacion(analisis: a),
        const SizedBox(height: 14),
        _CuadrosConsumo(analisis: a),
        const SizedBox(height: 14),
        _Consejos(analisis: a),
        const SizedBox(height: 14),
        _DatosUsados(analisis: a),
        const SizedBox(height: 8),
        if (widget.recibo != null) ...[
          OutlinedButton.icon(
            onPressed: _verRecibo,
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Ver mi recibo'),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.analisis == null)
          ElevatedButton.icon(
            onPressed: _verHistorial,
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Ver historial de consumos'),
          ),
      ],
    );
  }

  Widget _bannerGuardado() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '¡Recibo guardado! Ya analizamos tu consumo del mes.',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pregunta cuántas personas viven en el hogar (1 a 30). null si se cancela.
Future<int?> mostrarDialogoHabitantes(
  BuildContext context, {
  String? mensaje,
  Empresa? empresa,
}) {
  var habitantes = 1;
  return showDialog<int>(
    context: context,
    builder: (dialogo) => StatefulBuilder(
      builder: (dialogo, setEstado) => AlertDialog(
        icon: Icon(Icons.groups_rounded, size: 40, color: empresa?.color ?? AppColors.primary),
        title: const Text('¿Cuántas personas viven en tu hogar?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensaje ??
                  'Lo usamos para comparar tu consumo con hogares de tu mismo estrato.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: habitantes > 1 ? () => setEstado(() => habitantes--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$habitantes',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: habitantes < 30 ? () => setEstado(() => habitantes++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(habitantes),
            child: const Text('Analizar'),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ secciones

class _AdvertenciaIrregular extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _AdvertenciaIrregular({required this.analisis});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB54708);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Consumo irregular detectado',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Este recibo tiene un consumo ${analisis.tipoIrregularidad ?? 'irregular'} '
            'según tu estrato y número de habitantes '
            '(${formatearNumero(analisis.consumo)} ${analisis.unidadVisible}). '
            'Si el consumo quedó mal leído, elimina el recibo y escanéalo de nuevo; '
            'si es correcto, revisa posibles fugas o fallas.',
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _CabeceraAnalisis extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _CabeceraAnalisis({required this.analisis});

  @override
  Widget build(BuildContext context) {
    final color = analisis.colorServicio;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(analisis.iconoServicio, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${analisis.tipoServicio} · ${analisis.mes} ${analisis.ano}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Consumo del hogar', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            '${formatearNumero(analisis.consumo)} ${analisis.unidadVisible}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 10, color: analisis.colorCategoria),
                const SizedBox(width: 6),
                Text(
                  'Consumo ${analisis.categoria}',
                  style: TextStyle(
                    color: analisis.colorCategoria,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextoCategoria extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _TextoCategoria({required this.analisis});

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary);
    return _Tarjeta(
      child: Text.rich(
        TextSpan(
          style: estilo,
          children: [
            const TextSpan(
              text: 'Respecto a hogares con su mismo número de habitantes, '
                  'el consumo de su servicio de ',
            ),
            TextSpan(
              text: analisis.tipoServicio,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const TextSpan(text: ' en este periodo es '),
            TextSpan(
              text: analisis.categoria,
              style: TextStyle(fontWeight: FontWeight.w800, color: analisis.colorCategoria),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}

/// Ubica el consumo frente al rango esperado (promedio ± tolerancia) que
/// calculó Spring. Solo es una representación visual de esos valores.
class _BarraComparacion extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _BarraComparacion({required this.analisis});

  @override
  Widget build(BuildContext context) {
    final esperado = analisis.consumoEsperado;
    final margen = esperado * analisis.tolerancia / 100;
    final bajo = math.max(0.0, esperado - margen);
    final alto = esperado + margen;
    final maximo = math.max(analisis.consumo, alto) * 1.2;
    double pos(double v) => maximo <= 0 ? 0 : (v / maximo).clamp(0.0, 1.0);

    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu consumo frente al esperado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Rango moderado para tu hogar: ${formatearNumero(_r(bajo))} – '
            '${formatearNumero(_r(alto))} ${analisis.unidadVisible}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, restricciones) {
              final ancho = restricciones.maxWidth;
              final x = pos(analisis.consumo) * ancho;
              return SizedBox(
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Zonas Bajo / Moderado / Elevado
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            _zona(pos(bajo), colorDeCategoria('Bajo')),
                            _zona(pos(alto) - pos(bajo), colorDeCategoria('Moderado')),
                            _zona(1 - pos(alto), colorDeCategoria('Elevado')),
                          ],
                        ),
                      ),
                    ),
                    // Marcador del consumo
                    Positioned(
                      left: (x - 9).clamp(0.0, math.max(0.0, ancho - 18)),
                      top: 0,
                      child: Column(
                        children: [
                          Icon(Icons.arrow_drop_down_rounded, size: 18, color: analisis.colorCategoria),
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _Leyenda('Bajo'),
              SizedBox(width: 14),
              _Leyenda('Moderado'),
              SizedBox(width: 14),
              _Leyenda('Elevado'),
            ],
          ),
        ],
      ),
    );
  }

  static double _r(double v) => (v * 100).round() / 100;

  Widget _zona(double fraccion, Color color) {
    final flex = (fraccion * 1000).round();
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: Container(height: 10, color: color.withValues(alpha: 0.75)),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final String categoria;

  const _Leyenda(this.categoria);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: colorDeCategoria(categoria)),
        const SizedBox(width: 5),
        Text(categoria, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Los cuatro cuadros de la web.
class _CuadrosConsumo extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _CuadrosConsumo({required this.analisis});

  @override
  Widget build(BuildContext context) {
    final u = analisis.unidadVisible;
    final alto = analisis.porEncimaDeCartagena;
    final colorCartagena = alto ? colorDeCategoria('Elevado') : colorDeCategoria('Bajo');

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _Cuadro(
          titulo: 'Tu consumo del hogar actual',
          valor: '${formatearNumero(analisis.consumo)} $u',
          icono: Icons.home_rounded,
          color: analisis.colorServicio,
        ),
        _Cuadro(
          titulo: 'Promedio en Cartagena',
          valor: '${formatearNumero(analisis.consumoEsperado)} $u',
          icono: alto ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: colorCartagena,
          resaltado: true,
          ayuda: 'Es el promedio de los hogares de tu estrato con tu número de habitantes. '
              'Si el cuadro es verde, tu consumo está por debajo; si es rojo, '
              'estás por encima del promedio general de la ciudad.',
        ),
        _Cuadro(
          titulo: 'Promedio mensual por habitante',
          valor: '${formatearNumero(analisis.promedioHabitante)} $u',
          icono: Icons.person_rounded,
          color: AppColors.primary,
        ),
        _Cuadro(
          titulo: 'Promedio semanal',
          valor: '${formatearNumero(analisis.promedioSemanal)} $u',
          icono: Icons.date_range_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _Cuadro extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final bool resaltado;
  final String? ayuda;

  const _Cuadro({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.resaltado = false,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: resaltado ? color.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: resaltado ? color.withValues(alpha: 0.45) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 22),
              const Spacer(),
              if (ayuda != null)
                Tooltip(
                  message: ayuda!,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 6),
                  child: const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
                ),
            ],
          ),
          const Spacer(),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: resaltado ? color : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Consejos extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _Consejos({required this.analisis});

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: AppColors.orange),
              SizedBox(width: 8),
              Text(
                'Consejos personalizados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (analisis.consejos.isEmpty)
            const Text(
              'No hay consejos disponibles para tu consumo actual.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            )
          else
            for (final consejo in analisis.consejos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        consejo,
                        style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DatosUsados extends StatelessWidget {
  final AnalisisConsumo analisis;

  const _DatosUsados({required this.analisis});

  @override
  Widget build(BuildContext context) {
    final fecha = analisis.fechaAnalisis;
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos del análisis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          _fila('Estrato', '${analisis.estrato}'),
          _fila('Habitantes del hogar', '${analisis.habitantes}'),
          _fila('Tolerancia del estrato', '${formatearNumero(analisis.tolerancia)} %'),
          if (fecha != null) _fila('Analizado el', formatearFecha(fecha)),
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(etiqueta, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;

  const _Tarjeta({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
