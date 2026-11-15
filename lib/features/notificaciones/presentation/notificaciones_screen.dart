import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/boton_inicio.dart';
import '../../fallas/data/models/falla.dart';
import '../../fallas/data/services/fallas_service.dart';
import '../../fallas/presentation/views/fallas_screen.dart';
import '../../fallas/presentation/widgets/tarjeta_falla.dart';
import '../data/aviso.dart';
import '../notificaciones_service.dart';

/// Bandeja de avisos: fallas en el barrio, estado de los reportes y cortes.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _api = AvisosApi();

  List<Aviso>? _avisos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    NotificacionesService.cambios.addListener(_cargar);
  }

  @override
  void dispose() {
    NotificacionesService.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await _api.listar();
      NotificacionesService.actualizarNoLeidas(r.noLeidas);
      if (mounted) {
        setState(() {
          _avisos = r.avisos;
          _error = null;
        });
      }
    } on FallaException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _marcarTodas() async {
    try {
      await _api.marcarTodasLeidas();
      NotificacionesService.actualizarNoLeidas(0);
      if (mounted) setState(() => _avisos = [for (final a in _avisos ?? const <Aviso>[]) a.leido()]);
    } on FallaException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _abrir(Aviso aviso) async {
    if (!aviso.leida) {
      setState(() => _avisos = [for (final a in _avisos!) a.id == aviso.id ? a.leido() : a]);
      _api.marcarLeida(aviso.id).then(NotificacionesService.actualizarNoLeidas).catchError((_) {});
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FallasScreen(pestanaInicial: aviso.tipo.esDeMisReportes ? 1 : 0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayNoLeidas = _avisos?.any((a) => !a.leida) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (hayNoLeidas)
            IconButton(
              tooltip: 'Marcar todo como leído',
              onPressed: _marcarTodas,
              icon: const Icon(Icons.done_all_rounded),
            ),
          const BotonInicio(),
        ],
      ),
      body: _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final avisos = _avisos;
    if (avisos == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : MensajeFallas(icono: Icons.cloud_off_rounded, texto: _error!, accion: 'Reintentar', onAccion: _cargar),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: avisos.isEmpty
          ? ListView(
              children: const [
                MensajeFallas(
                  icono: Icons.notifications_none_rounded,
                  texto: 'No tienes avisos.\nTe avisaremos cuando un vecino reporte una falla en tu barrio '
                      'o cambie el estado de tus reportes.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: avisos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TarjetaAviso(aviso: avisos[i], onTap: () => _abrir(avisos[i])),
            ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  final Aviso aviso;
  final VoidCallback onTap;

  const _TarjetaAviso({required this.aviso, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = aviso.servicio?.color ?? aviso.tipo.color;
    return Material(
      color: aviso.leida ? AppColors.surface : AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: aviso.leida ? AppColors.border : AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(aviso.servicio?.icono ?? aviso.tipo.icono, color: color, size: 22),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: Icon(aviso.tipo.icono, size: 15, color: aviso.tipo.color),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            aviso.titulo,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: aviso.leida ? FontWeight.w600 : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!aviso.leida)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      aviso.mensaje,
                      style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      haceCuanto(aviso.fecha),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
