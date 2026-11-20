import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../fallas/data/models/falla.dart';
import '../../../fallas/presentation/widgets/tarjeta_falla.dart';
import '../../data/services/admin_service.dart';

/// Fallas reportadas por los usuarios (igual que Reportes de usuarios en la
/// web). Al cambiar el estado, Spring le avisa por push a quien la reportó y,
/// al solucionarla, a los vecinos que la confirmaron.
class AdminFallasScreen extends StatefulWidget {
  /// Permite usar datos de prueba en los tests.
  final AdminService? servicio;

  const AdminFallasScreen({super.key, this.servicio});

  /// Una falla pendiente por más de este tiempo se resalta.
  static const demora = Duration(hours: 24);

  @override
  State<AdminFallasScreen> createState() => _AdminFallasScreenState();
}

class _AdminFallasScreenState extends State<AdminFallasScreen> {
  late final AdminService _service = widget.servicio ?? AdminService();

  // null = todas
  EstadoFalla? _estado = EstadoFalla.pendiente;
  ServicioFalla? _servicioFiltro;
  List<Falla>? _fallas;
  String? _error;
  final Set<String> _ocupadas = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // Se traen todas para mostrar cuántas hay en cada estado
  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final fallas = await _service.fallas();
      if (mounted) setState(() => _fallas = fallas);
    } on AdminException catch (e) {
      if (mounted) {
        setState(() {
          _fallas ??= const [];
          _error = e.mensaje;
        });
      }
    }
  }

  Future<void> _cambiar(Falla falla, EstadoFalla estado) async {
    setState(() => _ocupadas.add(falla.id));
    try {
      await _service.cambiarEstadoFalla(falla.id, estado);
      if (!mounted) return;
      setState(() {
        _fallas = [
          for (final f in _fallas!)
            f.id == falla.id
                ? f.copiar(
                    estado: estado,
                    fechaSolucion: estado == EstadoFalla.completado ? DateTime.now() : null,
                  )
                : f,
        ];
      });
      final vecinos = estado == EstadoFalla.completado && falla.confirmaciones > 0
          ? ' y a ${falla.confirmaciones} ${falla.confirmaciones == 1 ? 'vecino' : 'vecinos'}'
          : '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Falla marcada como "${estado.texto.toLowerCase()}". '
              'Le avisamos a quien la reportó$vecinos.'),
        ));
    } on AdminException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupadas.remove(falla.id));
    }
  }

  bool _demorada(Falla f) =>
      f.estado == EstadoFalla.pendiente &&
      f.fechaReporte != null &&
      DateTime.now().difference(f.fechaReporte!) > AdminFallasScreen.demora;

  @override
  Widget build(BuildContext context) {
    final todas = _fallas ?? const <Falla>[];
    final delServicio = [
      for (final f in todas)
        if (_servicioFiltro == null || f.servicio == _servicioFiltro) f,
    ];
    final visibles = [
      for (final f in delServicio)
        if (_estado == null || f.estado == _estado) f,
    ];
    int cuantas(EstadoFalla? e) => e == null ? delServicio.length : delServicio.where((f) => f.estado == e).length;
    final demoradas = delServicio.where(_demorada).length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Fallas reportadas')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final e in EstadoFalla.values) _chipEstado(e, e.texto, cuantas(e)),
                _chipEstado(null, 'Todas', cuantas(null)),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              children: [
                _chipServicio(null),
                for (final s in ServicioFalla.values) _chipServicio(s),
              ],
            ),
          ),
          if (demoradas > 0 && _estado != EstadoFalla.completado)
            _AvisoDemoradas(
              cantidad: demoradas,
              onTap: () => setState(() => _estado = EstadoFalla.pendiente),
            ),
          Expanded(child: _buildLista(visibles)),
        ],
      ),
    );
  }

  Widget _buildLista(List<Falla> fallas) {
    if (_fallas == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _fallas!.isEmpty) {
      return Center(
        child: MensajeFallas(icono: Icons.cloud_off_rounded, texto: _error!, accion: 'Reintentar', onAccion: _cargar),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: fallas.isEmpty
          ? ListView(
              children: [
                MensajeFallas(
                  icono: _estado == EstadoFalla.pendiente ? Icons.task_alt_rounded : Icons.inbox_outlined,
                  color: _estado == EstadoFalla.pendiente ? AppColors.green : null,
                  texto: _estado == EstadoFalla.pendiente
                      ? '¡Todo al día! No hay fallas pendientes por revisar.'
                      : 'No hay fallas en este estado.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: fallas.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _tarjeta(fallas[i]),
            ),
    );
  }

  Widget _tarjeta(Falla f) {
    final ocupada = _ocupadas.contains(f.id);
    final siguiente = switch (f.estado) {
      EstadoFalla.pendiente => (EstadoFalla.recibido, 'Marcar en revisión', Icons.engineering_rounded),
      EstadoFalla.recibido => (EstadoFalla.completado, 'Marcar solucionada', Icons.check_circle_outline_rounded),
      EstadoFalla.completado => null,
    };
    return TarjetaFalla(
      falla: f,
      pie: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_demorada(f))
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.timer_off_rounded, size: 17, color: AppColors.red),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lleva más de un día sin revisar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [f.usuarioNombre, f.usuarioEmail].whereType<String>().join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (siguiente != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                // Una falla ya resuelta se puede cerrar sin pasar por revisión
                if (f.estado == EstadoFalla.pendiente) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.green),
                      onPressed: ocupada ? null : () => _cambiar(f, EstadoFalla.completado),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Solucionada'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: siguiente.$1.color),
                    onPressed: ocupada ? null : () => _cambiar(f, siguiente.$1),
                    icon: Icon(siguiente.$3),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(siguiente.$2)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipEstado(EstadoFalla? estado, String texto, int cantidad) {
    final seleccionado = _estado == estado;
    final color = estado?.color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: seleccionado,
        avatar: estado == null ? null : Icon(estado.icono, size: 17, color: seleccionado ? Colors.white : color),
        label: Text('$texto · $cantidad'),
        showCheckmark: false,
        selectedColor: color,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _estado = estado),
      ),
    );
  }

  Widget _chipServicio(ServicioFalla? servicio) {
    final seleccionado = _servicioFiltro == servicio;
    final color = servicio?.color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: seleccionado,
        showCheckmark: false,
        avatar: Icon(servicio?.icono ?? Icons.apps_rounded, size: 16, color: seleccionado ? color : AppColors.textSecondary),
        label: Text(servicio?.nombre ?? 'Todos los servicios'),
        selectedColor: color.withValues(alpha: 0.14),
        side: BorderSide(color: seleccionado ? color : AppColors.border),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: seleccionado ? color : AppColors.textSecondary,
        ),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _servicioFiltro = servicio),
      ),
    );
  }
}

class _AvisoDemoradas extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;

  const _AvisoDemoradas({required this.cantidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.priority_high_rounded, color: AppColors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cantidad == 1
                        ? '1 falla lleva más de un día sin revisar.'
                        : '$cantidad fallas llevan más de un día sin revisar.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red),
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
