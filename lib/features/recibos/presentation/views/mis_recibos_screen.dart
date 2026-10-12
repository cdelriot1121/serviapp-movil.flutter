import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/recibo.dart';
import '../../data/services/recibo_service.dart';
import '../escanear_recibo.dart';
import '../utils/formatos.dart';
import 'detalle_recibo_screen.dart';

/// Archivero de recibos escaneados del usuario, filtrable por servicio.
class MisRecibosScreen extends StatefulWidget {
  const MisRecibosScreen({super.key});

  @override
  State<MisRecibosScreen> createState() => _MisRecibosScreenState();
}

class _MisRecibosScreenState extends State<MisRecibosScreen> {
  final ReciboService _service = ReciboService();

  // null = todos; si no, ENERGIA, AGUA o GAS
  String? _filtro;
  List<Recibo>? _recibos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final recibos = await _service.listar(tipoServicio: _filtro);
      if (mounted) setState(() => _recibos = recibos);
    } on ReciboException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _recibos = [];
        });
      }
    }
  }

  Future<void> _abrir(Recibo recibo) async {
    final eliminado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DetalleReciboScreen(recibo: recibo)),
    );
    if (eliminado == true) _cargar();
  }

  Future<void> _escanear() async {
    await iniciarEscaneoRecibo(context);
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis recibos'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _escanear,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Escanear'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _chip(null, 'Todos', Icons.all_inbox_rounded, AppColors.primary),
                for (final e in Empresa.values)
                  _chip(e.tipoServicio, e.servicio, e.icono, e.color),
              ],
            ),
          ),
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  Widget _chip(String? tipo, String texto, IconData icono, Color color) {
    final seleccionado = _filtro == tipo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: seleccionado,
        avatar: Icon(icono, size: 18, color: seleccionado ? Colors.white : color),
        label: Text(texto),
        showCheckmark: false,
        selectedColor: color,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() {
            _filtro = tipo;
            _recibos = null;
          });
          _cargar();
        },
      ),
    );
  }

  Widget _buildContenido() {
    final recibos = _recibos;
    if (recibos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _estadoVacio(Icons.cloud_off_rounded, _error!, accion: 'Reintentar', onAccion: _cargar);
    }
    if (recibos.isEmpty) {
      return _estadoVacio(
        Icons.receipt_long_outlined,
        _filtro == null
            ? 'Aún no tienes recibos guardados.\nEscanea tu primer recibo para empezar tu historial.'
            : 'No tienes recibos de este servicio todavía.',
        accion: 'Escanear recibo',
        onAccion: _escanear,
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: recibos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TarjetaRecibo(recibo: recibos[i], onTap: () => _abrir(recibos[i])),
      ),
    );
  }

  Widget _estadoVacio(IconData icono, String texto, {required String accion, required VoidCallback onAccion}) {
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
              style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onAccion, child: Text(accion)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaRecibo extends StatelessWidget {
  final Recibo recibo;
  final VoidCallback onTap;

  const _TarjetaRecibo({required this.recibo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final empresa = recibo.empresa;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: empresa.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(empresa.icono, color: empresa.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatearPeriodoLargo(recibo.periodoFacturado),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${empresa.nombre} · ${empresa.identificador} ${recibo.identificador ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatearPesos(recibo.valorTotal),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatearNumero(recibo.consumoActual)} ${empresa.unidad}',
                    style: TextStyle(fontSize: 13, color: empresa.color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
