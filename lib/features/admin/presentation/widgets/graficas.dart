import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../data/models/estadisticas.dart';

// =====================================================================
// Colores
// =====================================================================

/// Colores del panel: los servicios usan los mismos de los recibos y las
/// categorías siguen el semáforo de la app (verde, sol, rojo).
class ColoresPanel {
  static const Color teal = Color(0xFF12917F);
  static const Color violeta = Color(0xFF7C6FE0);

  /// Paleta para series sin color propio (estratos, barrios…).
  static const List<Color> paleta = [
    AppColors.primary,
    AppColors.green,
    AppColors.orange,
    teal,
    violeta,
    AppColors.sky,
  ];

  static Color de(String etiqueta, int indice) {
    final clave = _sinTildes(etiqueta.toLowerCase());
    for (final empresa in Empresa.values) {
      if (_sinTildes(empresa.servicio.toLowerCase()) == clave) {
        return empresa.color;
      }
    }
    switch (clave) {
      case 'bajo':
      case 'completado':
      case 'pagados':
      case 'activos':
        return AppColors.green;
      case 'moderado':
      case 'pendiente':
      case 'pendientes':
        return AppColors.orange;
      case 'elevado':
      case 'alto':
      case 'vencidos':
      case 'inhabilitados':
        return AppColors.red;
      case 'recibido':
        return AppColors.sky;
      case 'casa':
        return AppColors.green;
      case 'apartamento':
        return AppColors.primary;
    }
    return paleta[indice % paleta.length];
  }

  static String _sinTildes(String texto) => texto
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

// =====================================================================
// Contenedores
// =====================================================================

/// Tarjeta blanca de una gráfica, con el mismo borde y sombra azul suave
/// de las filas de pagos del inicio.
class TarjetaPanel extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icono;
  final Color color;
  final Widget child;

  const TarjetaPanel({
    super.key,
    required this.titulo,
    required this.icono,
    required this.child,
    this.subtitulo,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icono, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: estiloTitulo(15)),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitulo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Texto para las gráficas que aún no tienen datos.
class SinDatos extends StatelessWidget {
  final String texto;

  const SinDatos({super.key, this.texto = 'Aún no hay datos para mostrar.'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.eco_outlined, size: 18, color: AppColors.leafLight),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Números animados
// =====================================================================

/// Número que cuenta hasta su valor y, al llegar un dato nuevo, avanza desde
/// el anterior: así se nota cuando algo cambia en la base de datos.
class NumeroAnimado extends StatelessWidget {
  final double valor;
  final TextStyle estilo;
  final String Function(double) formato;

  const NumeroAnimado({
    super.key,
    required this.valor,
    required this.estilo,
    this.formato = _entero,
  });

  static String _entero(double v) => formatearNumero(v.roundToDouble());

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: valor),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formato(v), style: estilo),
    );
  }
}

/// Tarjeta de una cifra principal. Si el valor sube muestra un "+N" verde
/// unos segundos.
class KpiTile extends StatefulWidget {
  final String titulo;
  final int valor;
  final IconData icono;
  final Color color;
  final String? detalle;

  const KpiTile({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.detalle,
  });

  @override
  State<KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<KpiTile> {
  int _aumento = 0;
  int _version = 0;

  @override
  void didUpdateWidget(covariant KpiTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final diferencia = widget.valor - oldWidget.valor;
    if (diferencia > 0) {
      final version = ++_version;
      setState(() => _aumento = diferencia);
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && version == _version) setState(() => _aumento = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            Color.lerp(AppColors.surface, color, 0.08)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.12),
                      color.withValues(alpha: 0.26),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icono, color: color, size: 20),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animacion) => ScaleTransition(
                  scale: animacion,
                  child: FadeTransition(opacity: animacion, child: child),
                ),
                child: _aumento > 0
                    ? Container(
                        key: ValueKey(_version),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$_aumento',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: NumeroAnimado(
              valor: widget.valor.toDouble(),
              estilo: estiloTitulo(26),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (widget.detalle != null) ...[
            const SizedBox(height: 3),
            Text(
              widget.detalle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Dona
// =====================================================================

/// Gráfica de dona con el total al centro y la leyenda a un lado.
class DonaChart extends StatelessWidget {
  final List<ItemConteo> items;
  final String etiquetaCentro;
  final double tamano;

  const DonaChart({
    super.key,
    required this.items,
    this.etiquetaCentro = 'Total',
    this.tamano = 128,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, i) => s + i.valor);
    if (total <= 0) return const SinDatos();

    final colores = [
      for (var i = 0; i < items.length; i++)
        ColoresPanel.de(items[i].etiqueta, i),
    ];

    return Row(
      children: [
        SizedBox(
          width: tamano,
          height: tamano,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, progreso, _) => CustomPaint(
              painter: _DonaPainter(
                valores: [for (final i in items) i.valor],
                colores: colores,
                progreso: progreso,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NumeroAnimado(valor: total, estilo: estiloTitulo(20)),
                    Text(
                      etiquetaCentro,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _FilaLeyenda(
                    color: colores[i],
                    etiqueta: items[i].etiqueta,
                    valor: items[i].valor,
                    porcentaje: items[i].valor * 100 / total,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaLeyenda extends StatelessWidget {
  final Color color;
  final String etiqueta;
  final double valor;
  final double porcentaje;

  const _FilaLeyenda({
    required this.color,
    required this.etiqueta,
    required this.valor,
    required this.porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        Text(
          formatearNumero(valor),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${porcentaje.round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonaPainter extends CustomPainter {
  final List<double> valores;
  final List<Color> colores;
  final double progreso;

  _DonaPainter({
    required this.valores,
    required this.colores,
    required this.progreso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0, (s, v) => s + v);
    const grosor = 16.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - grosor / 2,
    );

    // Pista de fondo
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..color = AppColors.border.withValues(alpha: 0.7),
    );

    final visibles = valores.where((v) => v > 0).length;
    final hueco = visibles > 1 ? 0.06 : 0.0;
    var inicio = -math.pi / 2;
    for (var i = 0; i < valores.length; i++) {
      if (valores[i] <= 0) continue;
      final barrido = (valores[i] / total) * math.pi * 2 * progreso;
      canvas.drawArc(
        rect,
        inicio + hueco / 2,
        math.max(0.001, barrido - hueco),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = visibles > 1 ? StrokeCap.butt : StrokeCap.round
          ..color = colores[i],
      );
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant _DonaPainter old) =>
      old.progreso != progreso ||
      old.valores != valores ||
      old.colores != colores;
}

// =====================================================================
// Anillo de porcentaje
// =====================================================================

/// Anillo con un porcentaje al centro (p. ej. "recibos pagados").
class AnilloPorcentaje extends StatelessWidget {
  final double porcentaje;
  final Color color;
  final String etiqueta;
  final double tamano;

  const AnilloPorcentaje({
    super.key,
    required this.porcentaje,
    required this.color,
    required this.etiqueta,
    this.tamano = 88,
  });

  @override
  Widget build(BuildContext context) {
    final fraccion = (porcentaje / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: tamano,
          height: tamano,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraccion),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, f, _) => CustomPaint(
              painter: _DonaPainter(
                valores: [f, 1 - f],
                colores: [color, Colors.transparent],
                progreso: 1,
              ),
              child: Center(
                child: Text('${(f * 100).round()}%', style: estiloTitulo(17)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// =====================================================================
// Barras horizontales
// =====================================================================

/// Barras horizontales con su etiqueta y valor (servicios, barrios…).
class BarrasHorizontales extends StatelessWidget {
  final List<ItemConteo> items;
  final String Function(ItemConteo)? formatoValor;
  final Color? colorUnico;

  const BarrasHorizontales({
    super.key,
    required this.items,
    this.formatoValor,
    this.colorUnico,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || items.every((i) => i.valor <= 0)) {
      return const SinDatos();
    }
    final maximo = items.fold<double>(0, (m, i) => math.max(m, i.valor));

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
            child: _BarraHorizontal(
              item: items[i],
              fraccion: maximo > 0 ? items[i].valor / maximo : 0,
              color: colorUnico ?? ColoresPanel.de(items[i].etiqueta, i),
              texto:
                  formatoValor?.call(items[i]) ??
                  formatearNumero(items[i].valor),
            ),
          ),
      ],
    );
  }
}

class _BarraHorizontal extends StatelessWidget {
  final ItemConteo item;
  final double fraccion;
  final Color color;
  final String texto;

  const _BarraHorizontal({
    required this.item,
    required this.fraccion,
    required this.color,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Container(
                height: 10,
                width: c.maxWidth,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: fraccion),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, f, _) => Container(
                  height: 10,
                  width: math.max(10, c.maxWidth * f),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.75), color],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Barras verticales
// =====================================================================

/// Barras verticales al estilo de la gráfica de consumo de los recibos
/// (p. ej. usuarios por estrato).
class BarrasVerticales extends StatelessWidget {
  final List<ItemConteo> items;
  final String Function(String)? etiqueta;
  final Color color;

  const BarrasVerticales({
    super.key,
    required this.items,
    this.etiqueta,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SinDatos();
    final maximo = items.fold<double>(0, (m, i) => math.max(m, i.valor));
    final mayor = items.indexWhere((i) => i.valor == maximo);

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      formatearNumero(items[i].valor),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == mayor
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: i == mayor ? color : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: maximo > 0 ? items[i].valor / maximo : 0,
                      ),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => Container(
                        height: 4 + 110 * f,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: i == mayor
                                ? [
                                    color,
                                    Color.lerp(color, AppColors.logo, 0.5)!,
                                  ]
                                : [
                                    color.withValues(alpha: 0.22),
                                    color.withValues(alpha: 0.34),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      etiqueta?.call(items[i].etiqueta) ?? items[i].etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
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
}

// =====================================================================
// Actividad mensual
// =====================================================================

/// Una serie de la gráfica de actividad.
class SerieActividad {
  final String nombre;
  final Color color;
  final int Function(ActividadMes) valor;

  const SerieActividad(this.nombre, this.color, this.valor);
}

/// Líneas suaves con la actividad de los últimos meses. Tocar una serie en
/// la leyenda la oculta o la muestra.
class ActividadChart extends StatefulWidget {
  final List<ActividadMes> meses;

  const ActividadChart({super.key, required this.meses});

  static const series = [
    SerieActividad('Registros', AppColors.primary, _registros),
    SerieActividad('Recibos', AppColors.green, _recibos),
    SerieActividad('Análisis', AppColors.orange, _analisis),
    SerieActividad('Predicciones', ColoresPanel.violeta, _predicciones),
  ];

  static int _registros(ActividadMes m) => m.registros;
  static int _recibos(ActividadMes m) => m.recibos;
  static int _analisis(ActividadMes m) => m.analisis;
  static int _predicciones(ActividadMes m) => m.predicciones;

  @override
  State<ActividadChart> createState() => _ActividadChartState();
}

class _ActividadChartState extends State<ActividadChart> {
  final Set<int> _ocultas = {};

  @override
  Widget build(BuildContext context) {
    final meses = widget.meses;
    if (meses.isEmpty) return const SinDatos();

    final visibles = [
      for (var i = 0; i < ActividadChart.series.length; i++)
        if (!_ocultas.contains(i)) ActividadChart.series[i],
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < ActividadChart.series.length; i++)
              _ChipSerie(
                serie: ActividadChart.series[i],
                total: meses.fold(
                  0,
                  (s, m) => s + ActividadChart.series[i].valor(m),
                ),
                activa: !_ocultas.contains(i),
                onTap: () => setState(() {
                  if (!_ocultas.remove(i)) _ocultas.add(i);
                }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 170,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_ocultas.length),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, progreso, _) => CustomPaint(
              size: Size.infinite,
              painter: _ActividadPainter(
                meses: meses,
                series: visibles,
                progreso: progreso,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final m in meses)
              Expanded(
                child: Text(
                  mesCorto(m.periodo),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipSerie extends StatelessWidget {
  final SerieActividad serie;
  final int total;
  final bool activa;
  final VoidCallback onTap;

  const _ChipSerie({
    required this.serie,
    required this.total,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activa ? serie.color.withValues(alpha: 0.12) : AppColors.cream,
      shape: StadiumBorder(
        side: BorderSide(
          color: activa
              ? serie.color.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: activa
                      ? serie.color
                      : AppColors.textSecondary.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${serie.nombre} · $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: activa
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  decoration: activa ? null : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActividadPainter extends CustomPainter {
  final List<ActividadMes> meses;
  final List<SerieActividad> series;
  final double progreso;

  _ActividadPainter({
    required this.meses,
    required this.series,
    required this.progreso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const arriba = 14.0;
    final alto = h - arriba;

    // Líneas guía punteadas
    final guia = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = arriba + alto * k / 3;
      for (var x = 0.0; x < w; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, w), y), guia);
      }
    }

    var maximo = 0;
    for (final s in series) {
      for (final m in meses) {
        maximo = math.max(maximo, s.valor(m));
      }
    }
    if (maximo == 0) maximo = 1;

    // Escala "bonita" para que el máximo no toque el borde
    final tope = maximo * 1.15;
    final paso = w / meses.length;

    Offset punto(int i, int valor) => Offset(
      paso * i + paso / 2,
      arriba + alto - alto * (valor / tope) * progreso,
    );

    for (final s in series) {
      final puntos = [
        for (var i = 0; i < meses.length; i++) punto(i, s.valor(meses[i])),
      ];
      final linea = _curva(puntos);

      // Relleno degradado bajo la línea
      final relleno = Path.from(linea)
        ..lineTo(puntos.last.dx, h)
        ..lineTo(puntos.first.dx, h)
        ..close();
      canvas.drawPath(
        relleno,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              s.color.withValues(alpha: 0.16),
              s.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );

      canvas.drawPath(
        linea,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = s.color,
      );

      for (final p in puntos) {
        canvas.drawCircle(p, 4.2, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = s.color,
        );
      }
    }
  }

  Path _curva(List<Offset> puntos) {
    final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (var i = 1; i < puntos.length; i++) {
      final a = puntos[i - 1];
      final b = puntos[i];
      final medio = (a.dx + b.dx) / 2;
      path.cubicTo(medio, a.dy, medio, b.dy, b.dx, b.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ActividadPainter old) =>
      old.progreso != progreso || old.meses != meses || old.series != series;
}
