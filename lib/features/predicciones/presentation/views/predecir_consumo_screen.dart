import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../admin/presentation/widgets/graficas.dart';
import '../../../analisis/presentation/views/analisis_consumo_screen.dart';
import '../../../perfil/data/perfil_service.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/data/services/recibo_service.dart';
import '../../../recibos/presentation/escanear_recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../data/models/prediccion.dart';
import 'historial_predicciones_screen.dart';
import 'prediccion_screen.dart';

/// Elige el servicio y revisa que haya meses suficientes antes de pedir la
/// predicción del próximo mes a la red neuronal.
class PredecirConsumoScreen extends StatefulWidget {
  const PredecirConsumoScreen({super.key});

  @override
  State<PredecirConsumoScreen> createState() => _PredecirConsumoScreenState();
}

class _PredecirConsumoScreenState extends State<PredecirConsumoScreen> {
  final _perfilService = PerfilService();

  Map<Empresa, HistorialServicio>? _historiales;
  Perfil? _perfil;
  Empresa? _empresa;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    // El perfil solo completa los datos del hogar: si falla se puede seguir
    final perfil = _perfilService.obtener().then<Perfil?>((p) => p).catchError((_) => null);
    try {
      final recibos = await ReciboService().listar();
      final historiales = {
        for (final e in Empresa.values) e: HistorialServicio.de(e, recibos),
      };
      final datosPerfil = await perfil;
      if (!mounted) return;
      setState(() {
        _historiales = historiales;
        _perfil = datosPerfil;
        // Primero el servicio con más meses registrados
        _empresa ??= Empresa.values.reduce(
          (a, b) => historiales[b]!.meses > historiales[a]!.meses ? b : a,
        );
      });
    } on ReciboException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _escanear() async {
    await iniciarEscaneoRecibo(context);
    if (mounted) _cargar();
  }

  ServicioHogar? get _servicioHogar => _perfil?.servicios
      .where((s) => s.tipoServicio == _empresa?.tipoServicio)
      .firstOrNull;

  Future<void> _editarHabitantes(ServicioHogar servicio) async {
    final nuevos = await mostrarDialogoHabitantes(
      context,
      empresa: _empresa,
      inicial: servicio.habitantes,
      mensaje: 'La red neuronal lo tiene en cuenta para estimar tu consumo.',
      confirmar: 'Guardar',
    );
    if (nuevos == null || nuevos == servicio.habitantes || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await _perfilService.actualizarHabitantes(servicio.tipoServicio, nuevos);
      if (!mounted) return;
      final perfil = _perfil!;
      setState(() {
        _perfil = Perfil(
          nombre: perfil.nombre,
          email: perfil.email,
          miembroDesde: perfil.miembroDesde,
          predio: perfil.predio,
          servicios: [
            for (final s in perfil.servicios)
              s.tipoServicio == servicio.tipoServicio ? s.conHabitantes(nuevos) : s,
          ],
          actividad: perfil.actividad,
        );
      });
    } on PerfilException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _calcular(HistorialServicio historial) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrediccionScreen(
          empresa: historial.empresa,
          usuarioId: historial.usuarioId!,
        ),
      ),
    );
    // Actualiza cuántas predicciones hay guardadas
    if (mounted) _cargar();
  }

  Future<void> _verHistorial() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistorialPrediccionesScreen()),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predecir consumo'),
        actions: [
          IconButton(
            tooltip: 'Mis predicciones',
            onPressed: _verHistorial,
            icon: const Icon(Icons.history_rounded),
          ),
          const BotonInicio(),
        ],
      ),
      body: _buildCuerpo(),
    );
  }

  Widget _buildCuerpo() {
    final historiales = _historiales;
    if (historiales == null) {
      if (_error == null) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.border),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final empresa = _empresa!;
    final historial = historiales[empresa]!;
    final servicioHogar = _servicioHogar;
    final estrato = _perfil?.predio?.estrato;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
            'Calcula cuánto podrías consumir el próximo mes a partir del '
            'historial de tus recibos.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _AccesoHistorial(total: _perfil?.actividad.predicciones, onTap: _verHistorial),
          const SizedBox(height: 20),
          Text('Tipo de servicio', style: estiloTitulo(16)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final e in Empresa.values) ...[
                if (e != Empresa.values.first) const SizedBox(width: 10),
                Expanded(
                  child: _OpcionServicio(
                    empresa: e,
                    seleccionada: e == empresa,
                    meses: historiales[e]!.meses,
                    onTap: () => setState(() => _empresa = e),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text('Datos de la predicción', style: estiloTitulo(16)),
          const SizedBox(height: 10),
          _Campo(
            icono: Icons.calendar_month_rounded,
            etiqueta: 'Mes a predecir',
            valor: historial.periodoAPredecir == null
                ? 'Escanea un recibo para saberlo'
                : formatearPeriodoLargo(historial.periodoAPredecir),
          ),
          if (servicioHogar != null) ...[
            const SizedBox(height: 10),
            _Campo(
              icono: Icons.groups_rounded,
              etiqueta: 'Número de habitantes',
              valor: '${servicioHogar.habitantes}',
              onTap: () => _editarHabitantes(servicioHogar),
            ),
          ],
          if (estrato != null && estrato > 0) ...[
            const SizedBox(height: 10),
            _Campo(icono: Icons.home_work_rounded, etiqueta: 'Estrato', valor: '$estrato'),
          ],
          if (servicioHogar != null || estrato != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Autocompletado desde tu predio y tus recibos.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 16),
          _EstadoMeses(historial: historial, onEscanear: _escanear),
          const SizedBox(height: 22),
          _BotonCalcular(
            onPressed: historial.listo ? () => _calcular(historial) : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'Usamos una red neuronal (LSTM) con tus últimos '
            '${HistorialServicio.mesesRequeridos} meses de consumo, tu estrato '
            'y los habitantes del hogar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OpcionServicio extends StatelessWidget {
  final Empresa empresa;
  final bool seleccionada;
  final int meses;
  final VoidCallback onTap;

  const _OpcionServicio({
    required this.empresa,
    required this.seleccionada,
    required this.meses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = empresa.color;
    return Material(
      color: seleccionada ? color.withValues(alpha: 0.12) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: seleccionada ? color : AppColors.border,
          width: seleccionada ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(empresa.icono, color: color, size: 24),
              const SizedBox(height: 14),
              Text(
                empresa.servicio,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meses == 0 ? 'Sin recibos' : '${empresa.unidad} · $meses meses',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dato de solo lectura (o editable si tiene [onTap]) con el estilo de los
/// campos de texto de la app.
class _Campo extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final VoidCallback? onTap;

  const _Campo({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(icono, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valor,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verde si ya hay meses suficientes; naranja con cuántos faltan si no.
class _EstadoMeses extends StatelessWidget {
  final HistorialServicio historial;
  final VoidCallback onEscanear;

  const _EstadoMeses({required this.historial, required this.onEscanear});

  @override
  Widget build(BuildContext context) {
    final listo = historial.listo;
    final color = listo ? AppColors.green : AppColors.orange;
    final meses = historial.meses;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            listo ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: listo ? AppColors.green : const Color(0xFFE08A00),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$meses ${meses == 1 ? 'mes registrado' : 'meses registrados'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  listo
                      ? 'Listo · se usan los últimos ${HistorialServicio.mesesRequeridos}'
                      : 'Necesitas ${HistorialServicio.mesesRequeridos} · '
                          'faltan ${historial.faltan}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEscanear,
            child: Text(listo ? 'Registrar más' : 'Escanear recibo'),
          ),
        ],
      ),
    );
  }
}

/// Botón con el degradado de ServiApp (gris mientras no se puede calcular).
class _BotonCalcular extends StatelessWidget {
  final VoidCallback? onPressed;

  const _BotonCalcular({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 56,
      decoration: BoxDecoration(
        gradient: activo ? AppColors.naturaleza : null,
        color: activo ? null : AppColors.border,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (activo)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textSecondary,
        ),
        icon: const Icon(Icons.trending_up_rounded),
        label: const Text('Calcular predicción'),
      ),
    );
  }
}

/// Lleva al historial de predicciones guardadas.
class _AccesoHistorial extends StatelessWidget {
  /// null mientras no se sabe (sin perfil).
  final int? total;
  final VoidCallback onTap;

  const _AccesoHistorial({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = this.total;
    final detalle = total == null || total == 0
        ? 'Compara lo que predijimos con tu consumo real'
        : '${total == 1 ? '1 predicción guardada' : '$total predicciones guardadas'} · '
            'compáralas con tu consumo real';

    return Material(
      color: ColoresPanel.violeta.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ColoresPanel.violeta.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColoresPanel.violeta.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded, color: ColoresPanel.violeta),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis predicciones',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ColoresPanel.violeta),
            ],
          ),
        ),
      ),
    );
  }
}
