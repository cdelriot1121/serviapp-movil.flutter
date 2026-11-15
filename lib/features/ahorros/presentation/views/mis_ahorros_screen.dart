import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../admin/presentation/widgets/graficas.dart';
import '../../../analisis/presentation/views/historial_analisis_screen.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/escanear_recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recibos/presentation/widgets/consumo_chart.dart';
import '../../data/models/resumen_ahorro.dart';
import '../../data/services/ahorro_service.dart';
import '../widgets/barras_ahorro.dart';

/// Gestor de ahorros: cuánto ha ahorrado el usuario mes a mes desde que usa
/// ServiApp, comparando cada recibo con su consumo de antes. Spring Boot hace
/// todos los cálculos; aquí solo se cuentan con palabras sencillas.
class MisAhorrosScreen extends StatefulWidget {
  /// Permite usar datos de prueba en los tests.
  final AhorroService? servicio;

  const MisAhorrosScreen({super.key, this.servicio});

  @override
  State<MisAhorrosScreen> createState() => _MisAhorrosScreenState();
}

class _MisAhorrosScreenState extends State<MisAhorrosScreen> {
  late final AhorroService _service = widget.servicio ?? AhorroService();

  ResumenAhorro? _resumen;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final resumen = await _service.resumen();
      if (mounted) {
        setState(() {
          _resumen = resumen;
          _cargando = false;
        });
      }
    } on AhorroException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _cargando = false;
        });
      }
    }
  }

  Future<void> _escanear() async {
    await iniciarEscaneoRecibo(context);
    if (mounted) _cargar();
  }

  void _verConsejos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistorialAnalisisScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ahorros'),
        actions: const [BotonInicio()],
      ),
      floatingActionButton: _resumen == null || _resumen!.servicios.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _escanear,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Escanear'),
            ),
      body: _buildCuerpo(),
    );
  }

  Widget _buildCuerpo() {
    final resumen = _resumen;
    if (_cargando && resumen == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (resumen == null) {
      return _EstadoVacio(
        icono: Icons.cloud_off_rounded,
        texto: _error ?? 'No pudimos cargar tus ahorros.',
        accion: 'Reintentar',
        onAccion: () {
          setState(() => _cargando = true);
          _cargar();
        },
      );
    }
    if (resumen.servicios.isEmpty) {
      return _EstadoVacio(
        icono: Icons.savings_outlined,
        texto:
            'Aún no tienes recibos.\n'
            'Escanea tu primer recibo y empezaremos a contar '
            'cuánto ahorras cada mes.',
        accion: 'Escanear recibo',
        onAccion: _escanear,
      );
    }

    final ultimos = resumen.meses.length > 6
        ? resumen.meses.sublist(resumen.meses.length - 6)
        : resumen.meses;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _TarjetaTotal(resumen: resumen),
          const SizedBox(height: 16),
          if (resumen.tieneComparaciones) ...[
            _MensajeDelMes(resumen: resumen, onVerConsejos: _verConsejos),
            const SizedBox(height: 16),
            TarjetaPanel(
              titulo: 'Mes a mes',
              subtitulo: 'Verde: ahorraste · Rojo: gastaste de más',
              icono: Icons.bar_chart_rounded,
              color: AppColors.green,
              child: BarrasAhorro(meses: ultimos),
            ),
            const SizedBox(height: 22),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Tus servicios', style: estiloTitulo(18)),
          ),
          for (final servicio in resumen.servicios) ...[
            _TarjetaServicio(servicio: servicio),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 8),
          const _ComoCalculamos(),
        ],
      ),
    );
  }
}

// =====================================================================
// Total ahorrado
// =====================================================================

class _TarjetaTotal extends StatelessWidget {
  final ResumenAhorro resumen;

  const _TarjetaTotal({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final total = resumen.ahorroTotal;
    final sinComparar = !resumen.tieneComparaciones;
    final deMas = total < 0;

    final titulo = sinComparar
        ? 'Tu punto de partida está listo'
        : deMas
        ? 'Has gastado de más'
        : 'Has ahorrado';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: deMas
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.orange, AppColors.red],
              )
            : AppColors.naturaleza,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: (deMas ? AppColors.red : AppColors.primary).withValues(
              alpha: 0.22,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                deMas ? Icons.trending_up_rounded : Icons.savings_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sinComparar)
            Text(
              'Ya sabemos cuánto consumías antes. Escanea tu próximo recibo '
              'y aquí verás cuánto ahorras cada mes.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 14,
                height: 1.5,
              ),
            )
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: NumeroAnimado(
                valor: total.abs().toDouble(),
                formato: (v) => formatearPesos(v.round()),
                estilo: estiloTitulo(36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Aproximado, desde que usas ServiApp',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (resumen.rachaMeses > 0)
                  _Pastilla(
                    icono: Icons.local_fire_department_rounded,
                    texto: resumen.rachaMeses == 1
                        ? 'Ahorraste el último mes'
                        : '${resumen.rachaMeses} meses seguidos ahorrando',
                  ),
                _Pastilla(
                  icono: Icons.calendar_month_rounded,
                  texto:
                      '${resumen.mesesConAhorro} de ${resumen.mesesEvaluados} '
                      '${resumen.mesesEvaluados == 1 ? 'mes' : 'meses'} con ahorro',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Pastilla({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Mensaje del último mes
// =====================================================================

class _MensajeDelMes extends StatelessWidget {
  final ResumenAhorro resumen;
  final VoidCallback onVerConsejos;

  const _MensajeDelMes({required this.resumen, required this.onVerConsejos});

  @override
  Widget build(BuildContext context) {
    final pesos = resumen.ahorroUltimoMes ?? 0;
    final estado = EstadoAhorro.dePesos(pesos);
    final mes = formatearPeriodoLargo(resumen.ultimoPeriodo);
    final valor = formatearPesos(pesos.abs());

    final (titulo, texto) = switch (estado) {
      EstadoAhorro.ahorro => (
        '¡Vas muy bien!',
        'En $mes gastaste aprox. $valor menos que antes de usar ServiApp.',
      ),
      EstadoAhorro.exceso => (
        'Este mes se te fue un poco la mano',
        'En $mes gastaste aprox. $valor más que antes de usar ServiApp. '
            'Revisa tus consejos para volver a ahorrar.',
      ),
      EstadoAhorro.estable => (
        'Vas igual que antes',
        'En $mes consumiste casi lo mismo que antes de usar ServiApp.',
      ),
    };

    final mejor = resumen.mejorPeriodo;
    final mostrarMejor =
        mejor != null &&
        mejor != resumen.ultimoPeriodo &&
        resumen.mesesEvaluados > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.surface, estado.color, 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: estado.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(estado.icono, color: estado.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: estiloTitulo(16))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          if (mostrarMejor) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: AppColors.sun,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tu mejor mes: ${formatearPeriodoLargo(mejor)} '
                    '(${formatearPesos(resumen.mejorAhorro)})',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (estado == EstadoAhorro.exceso) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onVerConsejos,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
              label: const Text('Ver mis consejos'),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Un servicio
// =====================================================================

class _TarjetaServicio extends StatelessWidget {
  final AhorroServicio servicio;

  const _TarjetaServicio({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final ultimo = s.ultimoMes;
    final unidad = s.unidadVisible;

    // Últimos 6 consumos, con el más reciente resaltado (misma gráfica del recibo)
    final puntos = s.historial.length > 6
        ? s.historial.sublist(s.historial.length - 6)
        : s.historial;
    final grafica = [
      for (var i = 0; i < puntos.length; i++)
        ConsumoMensual(
          periodo: puntos[i].periodo,
          consumo: puntos[i].consumo,
          esActual: i == puntos.length - 1,
        ),
    ];

    return TarjetaPanel(
      titulo: s.nombre,
      subtitulo:
          '${s.empresa?.identificador ?? 'N.º'} ${s.identificador} · '
          'con ServiApp desde ${formatearPeriodoLargo(s.inicio)}',
      icono: s.icono,
      color: s.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FraseEstado(servicio: s),
          const SizedBox(height: 14),
          _AntesAhora(servicio: s),
          const SizedBox(height: 18),
          if (grafica.length > 1) ...[
            ConsumoChart(historial: grafica, color: s.color, unidad: unidad),
            const SizedBox(height: 14),
          ],
          if (ultimo != null) ...[
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    etiqueta: s.ahorroTotal >= 0
                        ? 'Ahorro acumulado'
                        : 'Gasto de más acumulado',
                    valor: s.precioUnidad != null
                        ? formatearPesos(s.ahorroTotal.abs())
                        : '${formatearNumero(s.ahorroConsumo.abs())} $unidad',
                    color: EstadoAhorro.dePesos(
                      s.precioUnidad != null
                          ? s.ahorroTotal
                          : s.ahorroConsumo.round(),
                    ).color,
                  ),
                ),
                if (s.variacionMesAnterior != null)
                  Expanded(child: _VariacionMesAnterior(servicio: s)),
              ],
            ),
            const SizedBox(height: 4),
            _MesAMes(servicio: s),
          ],
        ],
      ),
    );
  }
}

/// "Consumes 17 % menos que antes", con el color del semáforo.
class _FraseEstado extends StatelessWidget {
  final AhorroServicio servicio;

  const _FraseEstado({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final ultimo = servicio.ultimoMes;
    if (ultimo == null) {
      return const Text(
        'Este es tu punto de partida. Con tu próximo recibo te diremos '
        'si estás ahorrando.',
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      );
    }

    final estado = ultimo.estado;
    final porcentaje = ultimo.porcentaje.abs().round();
    final frase = switch (estado) {
      EstadoAhorro.ahorro => 'Consumes $porcentaje % menos que antes',
      EstadoAhorro.exceso => 'Consumes $porcentaje % más que antes',
      EstadoAhorro.estable => 'Consumes casi lo mismo que antes',
    };

    return Row(
      children: [
        Icon(estado.icono, color: estado.color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            frase,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: estado.color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Antes de ServiApp (promedio) frente al último mes.
class _AntesAhora extends StatelessWidget {
  final AhorroServicio servicio;

  const _AntesAhora({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final ultimo = s.ultimoMes;
    final unidad = s.unidadVisible;
    final colorAhora = ultimo?.estado.color ?? s.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Dato(
              etiqueta: s.mesesLineaBase > 1
                  ? 'Antes (promedio de ${s.mesesLineaBase} meses)'
                  : 'Antes',
              valor: '${formatearNumero(s.lineaBase)} $unidad',
              color: AppColors.textPrimary,
            ),
          ),
          if (ultimo != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
            Expanded(
              child: _Dato(
                etiqueta: 'Ahora (${formatearPeriodoLargo(ultimo.periodo)})',
                valor: '${formatearNumero(ultimo.consumo)} $unidad',
                color: colorAhora,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VariacionMesAnterior extends StatelessWidget {
  final AhorroServicio servicio;

  const _VariacionMesAnterior({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final variacion = servicio.variacionMesAnterior!;
    final porcentaje = variacion.abs().round();
    final bajo = variacion < 0;
    final igual = porcentaje == 0;
    final color = igual
        ? AppColors.textSecondary
        : (bajo ? AppColors.green : AppColors.red);

    return _Dato(
      etiqueta: 'Frente al mes anterior',
      valor: igual
          ? 'Igual'
          : '${bajo ? '↓' : '↑'} $porcentaje % ${bajo ? 'menos' : 'más'}',
      color: color,
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color color;

  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Detalle desplegable con cada mes comparado (del más reciente al más antiguo).
class _MesAMes extends StatelessWidget {
  final AhorroServicio servicio;

  const _MesAMes({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final conPesos = servicio.precioUnidad != null;
    final unidad = servicio.unidadVisible;

    // Material propio para que el toque se vea sobre la tarjeta blanca
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text(
            'Ver mes a mes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          children: [
            for (final m in servicio.meses.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatearPeriodoLargo(m.periodo),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${formatearNumero(m.consumo)} $unidad'
                            '${m.fuente == 'GRAFICA' ? ' · de la gráfica del recibo' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: m.estado.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _textoMes(m, conPesos, unidad),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: m.estado.color,
                        ),
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

  String _textoMes(MesServicio m, bool conPesos, String unidad) {
    if (m.estado == EstadoAhorro.estable) return 'Igual que antes';
    final cantidad = conPesos
        ? formatearPesos(m.ahorro.abs())
        : '${formatearNumero(m.diferencia.abs())} $unidad';
    return m.estado == EstadoAhorro.ahorro
        ? 'Ahorraste $cantidad'
        : 'De más $cantidad';
  }
}

// =====================================================================
// Explicación y estados vacíos
// =====================================================================

class _ComoCalculamos extends StatelessWidget {
  const _ComoCalculamos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '¿Cómo lo calculamos? Con la gráfica de tu primer recibo sabemos '
              'cuánto consumías antes de ServiApp. Cada mes comparamos tu '
              'consumo con ese promedio y lo pasamos a pesos con el precio '
              'de tus propios recibos (sin aseo, Brilla ni deudas). '
              'Por eso los valores son aproximados.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String accion;
  final VoidCallback onAccion;

  const _EstadoVacio({
    required this.icono,
    required this.texto,
    required this.accion,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onAccion, child: Text(accion)),
          ],
        ),
      ),
    );
  }
}
