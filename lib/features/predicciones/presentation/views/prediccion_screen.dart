import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../admin/presentation/widgets/graficas.dart';
import '../../../clima/presentation/widgets/consejo_clima.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recibos/presentation/widgets/consumo_chart.dart';
import '../../data/models/prediccion.dart';
import '../../data/services/prediccion_service.dart';

/// Pide la predicción a FastAPI, muestra el avance del cálculo y luego el
/// resultado.
class PrediccionScreen extends StatefulWidget {
  final Empresa empresa;
  final String usuarioId;

  /// Permite usar datos de prueba en los tests.
  final PrediccionService? servicio;

  const PrediccionScreen({
    super.key,
    required this.empresa,
    required this.usuarioId,
    this.servicio,
  });

  @override
  State<PrediccionScreen> createState() => _PrediccionScreenState();
}

class _PrediccionScreenState extends State<PrediccionScreen> {
  late final PrediccionService _service = widget.servicio ?? PrediccionService();
  Prediccion? _prediccion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _calcular();
  }

  Future<void> _calcular() async {
    setState(() {
      _prediccion = null;
      _error = null;
    });
    // Un mínimo de espera para que el avance se alcance a leer
    final espera = Future<void>.delayed(const Duration(milliseconds: 1800));
    try {
      final prediccion = await _service.predecir(
        empresa: widget.empresa,
        usuarioId: widget.usuarioId,
      );
      await espera;
      if (mounted) setState(() => _prediccion = prediccion);
    } on PrediccionException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediccion = _prediccion;
    return Scaffold(
      appBar: AppBar(
        title: Text(prediccion == null ? 'Predecir consumo' : 'Tu predicción'),
        actions: const [BotonInicio()],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: prediccion != null
            ? _Resultado(prediccion: prediccion)
            : _error != null
            ? _Error(mensaje: _error!, onReintentar: _calcular)
            : const _Calculando(),
      ),
    );
  }
}

// =====================================================================
// Calculando
// =====================================================================

class _Calculando extends StatefulWidget {
  const _Calculando();

  @override
  State<_Calculando> createState() => _CalculandoState();
}

class _CalculandoState extends State<_Calculando> with SingleTickerProviderStateMixin {
  static const _pasos = [
    'Historial de tus recibos leído',
    'Datos de tu hogar preparados (estrato, habitantes)',
    'Ejecutando la red neuronal…',
  ];

  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Timer _timer;
  int _paso = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_paso < _pasos.length - 1) setState(() => _paso++);
    });
  }

  @override
  void dispose() {
    _pulso.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        SizedBox(
          height: 280,
          child: AnimatedBuilder(
            animation: _pulso,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                for (final (tam, alfa) in const [(1.0, 0.07), (0.72, 0.10), (0.46, 0.16)])
                  Container(
                    width: 280 * tam * (0.94 + 0.06 * _pulso.value),
                    height: 280 * tam * (0.94 + 0.06 * _pulso.value),
                    decoration: BoxDecoration(
                      color: ColoresPanel.teal.withValues(alpha: alfa),
                      shape: BoxShape.circle,
                    ),
                  ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: AppColors.naturaleza,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 38),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Calculando tu predicción…',
          textAlign: TextAlign.center,
          style: estiloTitulo(20),
        ),
        const SizedBox(height: 8),
        const Text(
          'La red neuronal está analizando tus últimos '
          '${HistorialServicio.mesesRequeridos} meses de consumo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: LinearProgressIndicator(
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: ColoresPanel.teal,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i <= _paso; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 12),
            child: Row(
              children: [
                if (i < _paso)
                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22)
                else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: ColoresPanel.teal),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pasos[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: i == _paso ? FontWeight.w600 : FontWeight.w500,
                      color: i == _paso ? AppColors.textPrimary : AppColors.textSecondary,
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

class _Error extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _Error({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Resultado
// =====================================================================

class _Resultado extends StatelessWidget {
  final Prediccion prediccion;

  const _Resultado({required this.prediccion});

  @override
  Widget build(BuildContext context) {
    final p = prediccion;
    final empresa = p.empresa;
    final ultimo = p.ultimoMes;
    final promedio = p.promedio;
    final mayor = p.mesMayor;
    final menor = p.mesMenor;
    final mes = formatearPeriodoLargo(p.periodoEstimado);
    final cambioPromedio = p.cambioFrente(promedio);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _Encabezado(prediccion: p),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Cifra(
                titulo: ultimo == null ? 'Último mes' : '${mesCorto(ultimo.periodo)} · real',
                valor: ultimo?.consumo,
                unidad: p.unidad,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Cifra(titulo: 'Tu promedio', valor: promedio, unidad: p.unidad),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Cifra(
                titulo: '${mesCorto(p.periodoEstimado)} · predicción',
                valor: p.consumoEstimado,
                unidad: p.unidad,
                color: empresa.color,
                cambio: p.cambioFrente(ultimo?.consumo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TarjetaPanel(
          titulo: 'Tendencia y predicción (${p.unidad})',
          subtitulo: 'Tus últimos ${p.historico.length} meses y el que viene',
          icono: Icons.bar_chart_rounded,
          color: empresa.color,
          child: Column(
            children: [
              ConsumoChart(
                historial: [
                  ...p.historico,
                  ConsumoMensual(
                    periodo: p.periodoEstimado,
                    consumo: _redondeo(p.consumoEstimado),
                    esActual: true,
                  ),
                ],
                color: empresa.color,
                unidad: p.unidad,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 6,
                children: [
                  _Leyenda(color: empresa.color.withValues(alpha: 0.28), texto: 'Tus recibos'),
                  _Leyenda(color: empresa.color, texto: 'Predicción'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TarjetaPanel(
          titulo: 'Resumen',
          icono: Icons.insights_rounded,
          color: AppColors.primary,
          child: Column(
            children: [
              _Fila('Promedio de tus últimos meses', _cantidad(promedio, p.unidad)),
              if (mayor != null)
                _Fila('Mes de mayor consumo',
                    '${formatearPeriodoLargo(mayor.periodo)} · ${_cantidad(mayor.consumo, p.unidad)}'),
              if (menor != null)
                _Fila('Mes de menor consumo',
                    '${formatearPeriodoLargo(menor.periodo)} · ${_cantidad(menor.consumo, p.unidad)}'),
              if (cambioPromedio != null)
                _Fila('$mes frente a tu promedio', porcentaje(cambioPromedio)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TarjetaPanel(
          titulo: 'Consejos para $mes',
          icono: Icons.lightbulb_rounded,
          color: const Color(0xFFE08A00),
          child: Column(
            children: [
              for (final consejo in _consejos(p)) ...[
                ConsejoClima(texto: consejo, color: empresa.color),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        TarjetaPanel(
          titulo: 'Datos del modelo',
          icono: Icons.memory_rounded,
          color: ColoresPanel.violeta,
          child: Column(
            children: [
              _Fila('Modelo', p.algoritmo),
              _Fila('Versión', p.versionModelo),
              const _Fila('Servicio de cálculo', 'FastAPI'),
              _Fila('Meses de historial usados', '${p.mesesUsados}'),
              _Fila('Calculado el', formatearFecha(p.calculadaEl)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Es una estimación: tu consumo real puede cambiar según tus hábitos '
          'y los días que se facturen.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          icon: const Icon(Icons.trending_up_rounded),
          label: const Text('Calcular otra predicción'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.home_rounded),
          label: const Text('Volver al inicio'),
        ),
      ],
    );
  }

  static String _cantidad(double? valor, String unidad) =>
      valor == null ? '—' : '${formatearNumero(_redondeo(valor))} $unidad';

  // Un decimal basta para leer el consumo
  static double _redondeo(double valor) => (valor * 10).roundToDouble() / 10;

  /// Uno según la tendencia y dos de ahorro del servicio.
  static List<String> _consejos(Prediccion p) {
    final ultimo = p.ultimoMes;
    final cambio = p.cambioFrente(ultimo?.consumo);
    final mes = formatearPeriodoLargo(p.periodoEstimado).split(' ').first;
    final anterior = ultimo == null ? 'el último mes' : formatearPeriodoLargo(ultimo.periodo).split(' ').first;

    final tendencia = cambio == null || cambio.abs() < 0.03
        ? 'Se espera que $mes se parezca a $anterior. Mantén tus hábitos para que siga así.'
        : cambio > 0
        ? '$mes sería más alto que $anterior (${porcentaje(cambio)}). Planifica desde ya '
              'para que el recibo no te sorprenda.'
        : '¡Vas bien! Se espera que en $mes consumas menos que en $anterior '
              '(${porcentaje(cambio)}).';

    final delServicio = switch (p.empresa) {
      Empresa.afinia => const [
        'Desconecta los equipos que no uses: en modo espera también consumen.',
        'Usa el aire acondicionado entre 24 y 25 °C y con puertas y ventanas cerradas.',
      ],
      Empresa.aguasDeCartagena => const [
        'Revisa fugas: una llave que gotea desperdicia miles de litros al mes.',
        'Cierra la llave mientras te enjabonas o te cepillas los dientes.',
      ],
      Empresa.surtigas => const [
        'Tapa las ollas al cocinar: se calientan más rápido y gastan menos gas.',
        'Ajusta la llama al tamaño de la olla y revisa que sea azul.',
      ],
    };
    return [tendencia, ...delServicio];
  }
}

class _Encabezado extends StatelessWidget {
  final Prediccion prediccion;

  const _Encabezado({required this.prediccion});

  @override
  Widget build(BuildContext context) {
    final p = prediccion;
    final ultimo = p.ultimoMes;
    final cambio = p.cambioFrente(ultimo?.consumo);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.naturaleza,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
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
              Icon(p.empresa.icono, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${p.empresa.servicio} · ${formatearPeriodoLargo(p.periodoEstimado)}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const _Pastilla(icono: Icons.hub_rounded, texto: 'Red neuronal'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Consumo esperado',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: NumeroAnimado(
              valor: p.consumoEstimado,
              formato: (v) => '${formatearNumero(_Resultado._redondeo(v))} ${p.unidad}',
              estilo: estiloTitulo(38, color: Colors.white),
            ),
          ),
          if (cambio != null && ultimo != null) ...[
            const SizedBox(height: 10),
            _Pastilla(
              icono: cambio.abs() < 0.03
                  ? Icons.trending_flat_rounded
                  : cambio > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              texto: '${porcentaje(cambio)} frente a ${formatearPeriodoLargo(ultimo.periodo)}',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadro pequeño con una cifra; resaltado con [color] y su [cambio].
class _Cifra extends StatelessWidget {
  final String titulo;
  final double? valor;
  final String unidad;
  final Color? color;
  final double? cambio;

  const _Cifra({
    required this.titulo,
    required this.valor,
    required this.unidad,
    this.color,
    this.cambio,
  });

  @override
  Widget build(BuildContext context) {
    final resaltado = color != null;
    final cambio = this.cambio;
    final sube = cambio != null && cambio > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: resaltado ? color!.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: resaltado ? color! : AppColors.border,
          width: resaltado ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: resaltado ? color : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor == null ? '—' : formatearNumero(valor!.roundToDouble()),
              style: estiloTitulo(24),
            ),
          ),
          Text(unidad, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          if (cambio != null) ...[
            const SizedBox(height: 4),
            Text(
              porcentaje(cambio),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sube ? AppColors.red : AppColors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;

  const _Leyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Fila(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
