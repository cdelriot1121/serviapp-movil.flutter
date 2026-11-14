import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../fallas/data/models/falla.dart';
import '../../../fallas/presentation/widgets/tarjeta_falla.dart';
import '../../data/services/admin_service.dart';

/// Fallas reportadas por los usuarios (igual que Reportes de usuarios en la
/// web). Al cambiar el estado, Spring avisa a quien la reportó.
class AdminFallasScreen extends StatefulWidget {
  const AdminFallasScreen({super.key});

  @override
  State<AdminFallasScreen> createState() => _AdminFallasScreenState();
}

class _AdminFallasScreenState extends State<AdminFallasScreen> {
  final _service = AdminService();

  // null = todas
  EstadoFalla? _filtro = EstadoFalla.pendiente;
  List<Falla>? _fallas;
  String? _error;
  final Set<String> _ocupadas = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final fallas = await _service.fallas(estado: _filtro);
      if (mounted) setState(() => _fallas = fallas);
    } on AdminException catch (e) {
      if (mounted) {
        setState(() {
          _fallas = const [];
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falla marcada como "${estado.texto.toLowerCase()}". Avisamos al usuario.')),
      );
      await _cargar();
    } on AdminException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupadas.remove(falla.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fallas reportadas')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final e in EstadoFalla.values) _chip(e, e.texto),
                _chip(null, 'Todas'),
              ],
            ),
          ),
          Expanded(child: _buildLista()),
        ],
      ),
    );
  }

  Widget _buildLista() {
    final fallas = _fallas;
    if (fallas == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: MensajeFallas(icono: Icons.cloud_off_rounded, texto: _error!, accion: 'Reintentar', onAccion: _cargar),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: fallas.isEmpty
          ? ListView(
              children: const [
                MensajeFallas(icono: Icons.inbox_outlined, texto: 'No hay fallas en este estado.'),
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
      EstadoFalla.pendiente => (EstadoFalla.recibido, 'Marcar recibida', Icons.engineering_rounded),
      EstadoFalla.recibido => (EstadoFalla.completado, 'Marcar solucionada', Icons.check_circle_outline_rounded),
      EstadoFalla.completado => null,
    };
    return TarjetaFalla(
      falla: f,
      pie: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: siguiente.$1.color),
              onPressed: ocupada ? null : () => _cambiar(f, siguiente.$1),
              icon: Icon(siguiente.$3),
              label: Text(siguiente.$2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(EstadoFalla? estado, String texto) {
    final seleccionado = _filtro == estado;
    final color = estado?.color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: seleccionado,
        avatar: estado == null ? null : Icon(estado.icono, size: 17, color: seleccionado ? Colors.white : color),
        label: Text(texto),
        showCheckmark: false,
        selectedColor: color,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() {
            _filtro = estado;
            _fallas = null;
          });
          _cargar();
        },
      ),
    );
  }
}
