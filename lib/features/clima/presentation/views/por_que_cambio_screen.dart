import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../analisis/presentation/views/analisis_consumo_screen.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../data/clima_historico.dart';
import '../../data/explicacion_consumo.dart';
import '../../data/pronostico.dart';
import '../widgets/consejo_clima.dart';
import '../widgets/tarjeta_por_que.dart';

/// "¿Por qué subió mi recibo?": el cambio de consumo frente al periodo
/// anterior, separado en días cobrados, clima y hogar, con el clima día a día.
class PorQueCambioScreen extends StatelessWidget {
  final ExplicacionConsumo explicacion;

  const PorQueCambioScreen({super.key, required this.explicacion});

  @override
  Widget build(BuildContext context) {
    final e = explicacion;

    return Scaffold(
      appBar: AppBar(
        title: Text(e.pregunta),
        actions: const [BotonInicio()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          _Cabecera(e),
          const SizedBox(height: 14),
          _Tarjeta(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: e.colores.last.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(e.icono, color: e.colores.last, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.titulo, style: estiloTitulo(16)),
                      const SizedBox(height: 4),
                      Text(
                        e.resumen,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Tarjeta(child: _Desglose(e)),
          const SizedBox(height: 14),
          _Tarjeta(child: _ClimaComparado(e)),
          const SizedBox(height: 14),
          ConsejoClima(texto: e.consejo, color: e.colores.last),
          if (e.recibo.id != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnalisisConsumoScreen(recibo: e.recibo),
                ),
              ),
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Ver análisis de consumo'),
            ),
          ],
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

// Degradado del servicio, como el detalle del recibo, con el cambio grande.
class _Cabecera extends StatelessWidget {
  final ExplicacionConsumo e;

  const _Cabecera(this.e);

  @override
  Widget build(BuildContext context) {
    final empresa = e.empresa;
    final pesos = e.diferenciaPesos;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [empresa.color, Color.lerp(empresa.color, Colors.black, 0.25)!],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(empresa.icono, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${empresa.servicio} · '
                  '${formatearPeriodoLargo(e.recibo.periodoFacturado)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Frente a ${formatearPeriodoLargo(e.periodoAnterior).toLowerCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                porcentaje(e.cambio),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                e.causa == Causa.estable
                    ? Icons.drag_handle_rounded
                    : e.subio
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatearNumero(e.consumoAnterior)} → '
            '${formatearNumero(e.consumoActual)} ${empresa.unidad}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (pesos != null && pesos != 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                pesos > 0
                    ? 'Pagas ${formatearPesos(pesos)} más'
                    : 'Pagas ${formatearPesos(-pesos)} menos',
                style: TextStyle(
                  color: pesos > 0 ? Tendencia.muchoMas.color : Tendencia.menos.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Cuánto aportó cada causa, con barras que salen del centro.
class _Desglose extends StatelessWidget {
  final ExplicacionConsumo e;

  const _Desglose(this.e);

  @override
  Widget build(BuildContext context) {
    final filas = [
      (
        Icons.calendar_month_rounded,
        'Días cobrados',
        e.efectoDias,
        e.diasActual != null && e.diasAnterior != null
            ? '${e.diasAnterior} → ${e.diasActual} días'
            : 'Sin las fechas del periodo anterior',
      ),
      (
        Icons.thermostat_rounded,
        'Clima',
        e.efectoClima,
        e.sensibilidad == 0
            ? 'El ${e.empresa.servicio.toLowerCase()} casi no depende del clima'
            : 'Sensación ${_signo(e.diferenciaSensacion)} °C en promedio',
      ),
      (
        Icons.home_rounded,
        'Tu hogar',
        e.efectoHogar,
        'Hábitos, aparatos, visitas o fugas',
      ),
    ];
    final mayor = filas.fold<double>(0.1, (m, f) => f.$3.abs() > m ? f.$3.abs() : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué explica el cambio?', style: estiloTitulo(16)),
        const SizedBox(height: 4),
        const Text(
          'Cada parte suma al cambio total de tu consumo.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        for (final (icono, nombre, efecto, detalle) in filas)
          _FilaEfecto(
            icono: icono,
            nombre: nombre,
            efecto: efecto,
            detalle: detalle,
            escala: mayor,
          ),
        const Divider(height: 18, color: AppColors.border),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cambio total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              porcentaje(e.cambio),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _colorEfecto(e.cambio),
              ),
            ),
          ],
        ),
        if (e.sensibilidad > 0) ...[
          const SizedBox(height: 10),
          Text(
            e.mesesPropios > 0
                ? 'Con tus últimos ${e.mesesPropios} meses calculamos que tu '
                    '${e.empresa.servicio.toLowerCase()} sube cerca de '
                    '${(e.sensibilidad * 100).toStringAsFixed(1)} % por cada '
                    'grado más de sensación térmica.'
                : 'Estimamos que en Cartagena el consumo de '
                    '${e.empresa.servicio.toLowerCase()} sube cerca de '
                    '${(e.sensibilidad * 100).round()} % por cada grado más de '
                    'sensación térmica. Con más recibos lo calcularemos para tu hogar.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  static String _signo(double v) =>
      '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)}';
}

Color _colorEfecto(double efecto) {
  if (efecto.abs() < 0.01) return Tendencia.normal.color;
  return efecto > 0 ? Tendencia.mas.color : Tendencia.menos.color;
}

class _FilaEfecto extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final double efecto;
  final String detalle;
  final double escala;

  const _FilaEfecto({
    required this.icono,
    required this.nombre,
    required this.efecto,
    required this.detalle,
    required this.escala,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorEfecto(efecto);
    final fraccion = (efecto.abs() / escala).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                porcentaje(efecto),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Negativo hacia la izquierda, positivo hacia la derecha
          SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final lado in [-1, 1])
                  Expanded(
                    child: Align(
                      alignment:
                          lado < 0 ? Alignment.centerRight : Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: efecto.sign == lado ? fraccion : 0,
                        ),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, f, _) => FractionallySizedBox(
                          widthFactor: f,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(lado < 0 ? 8 : 0),
                                right: Radius.circular(lado > 0 ? 8 : 0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Container(width: 2, height: 4, color: AppColors.border),
          ),
          const SizedBox(height: 2),
          Text(
            detalle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Los dos periodos lado a lado y el calor de cada día.
class _ClimaComparado extends StatelessWidget {
  final ExplicacionConsumo e;

  const _ClimaComparado(this.e);

  @override
  Widget build(BuildContext context) {
    final antes = e.climaAnterior;
    final ahora = e.climaActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Así estuvo el clima', style: estiloTitulo(16)),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            _Encabezado(mesCorto(e.periodoAnterior)),
            _Encabezado(mesCorto(e.recibo.periodoFacturado ?? ''), resaltado: true),
          ],
        ),
        const SizedBox(height: 6),
        _FilaClima(
          icono: Icons.thermostat_rounded,
          nombre: 'Sensación promedio',
          antes: '${antes.sensacionPromedio.toStringAsFixed(1)}°',
          ahora: '${ahora.sensacionPromedio.toStringAsFixed(1)}°',
        ),
        _FilaClima(
          icono: TipoDia.caluroso.icono,
          nombre: 'Días calurosos',
          antes: '${antes.calurosos}',
          ahora: '${ahora.calurosos}',
        ),
        _FilaClima(
          icono: TipoDia.lluvioso.icono,
          nombre: 'Días lluviosos',
          antes: '${antes.lluviosos}',
          ahora: '${ahora.lluviosos}',
        ),
        _FilaClima(
          icono: TipoDia.fresco.icono,
          nombre: 'Días frescos',
          antes: '${antes.frescos}',
          ahora: '${ahora.frescos}',
        ),
        const SizedBox(height: 16),
        const Text(
          'Día a día',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _FranjaDias(
          titulo: formatearPeriodoLargo(e.periodoAnterior),
          clima: antes,
        ),
        const SizedBox(height: 12),
        _FranjaDias(
          titulo: formatearPeriodoLargo(e.recibo.periodoFacturado),
          clima: ahora,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final tipo in [
              TipoDia.muyCaluroso,
              TipoDia.caluroso,
              TipoDia.normal,
              TipoDia.fresco,
              TipoDia.lluvioso,
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colorDia(tipo),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _nombreTipo(tipo),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

Color _colorDia(TipoDia tipo) =>
    tipo == TipoDia.normal ? AppColors.sky : tipo.colores.last;

String _nombreTipo(TipoDia tipo) => switch (tipo) {
      TipoDia.muyCaluroso => 'Muy caluroso',
      TipoDia.caluroso => 'Caluroso',
      TipoDia.normal => 'Típico',
      TipoDia.fresco => 'Fresco',
      TipoDia.lluvioso => 'Lluvioso',
    };

class _Encabezado extends StatelessWidget {
  final String texto;
  final bool resaltado;

  const _Encabezado(this.texto, {this.resaltado = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: resaltado ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _FilaClima extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final String antes;
  final String ahora;

  const _FilaClima({
    required this.icono,
    required this.nombre,
    required this.antes,
    required this.ahora,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              antes,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ahora,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Una barrita por día: la altura es la sensación térmica y el color el tipo.
class _FranjaDias extends StatelessWidget {
  final String titulo;
  final ClimaPeriodo clima;

  const _FranjaDias({required this.titulo, required this.clima});

  @override
  Widget build(BuildContext context) {
    final dias = clima.dias;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$titulo · ${formatearFecha(clima.inicio)} – ${formatearFecha(clima.fin)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in dias)
                Expanded(
                  child: Tooltip(
                    message: '${formatearFecha(d.fecha)}: sensación '
                        '${grados(d.sensacionMaxima)}'
                        '${d.lluviaMm >= 1 ? ', ${d.lluviaMm.toStringAsFixed(1)} mm' : ''}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _alto(d)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, f, _) => FractionallySizedBox(
                          heightFactor: f,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _colorDia(d.tipo),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // De 32 °C (bajita) a 44 °C (llena)
  static double _alto(DiaPasado d) =>
      (0.2 + (d.sensacionMaxima - 32) / 12 * 0.8).clamp(0.2, 1.0);
}
