import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../fallas/data/models/falla.dart';
import '../../../fallas/presentation/widgets/tarjeta_falla.dart';
import '../../data/models/corte_admin.dart';
import '../../data/services/admin_service.dart';

/// Resultado al programar: el corte y a cuántos usuarios se les avisó.
typedef CorteProgramadoResultado = ({CorteAdmin corte, int usuariosNotificados});

/// Formulario para programar un corte (como "Cortes" en la web). Al guardar,
/// Spring avisa por push a los usuarios de los barrios elegidos.
class ProgramarCorteScreen extends StatefulWidget {
  /// Permite usar datos de prueba en los tests.
  final AdminService? servicio;

  /// "Ahora" fijo para las pruebas.
  final DateTime? ahora;

  const ProgramarCorteScreen({super.key, this.servicio, this.ahora});

  static const maxMotivo = 300;

  @override
  State<ProgramarCorteScreen> createState() => _ProgramarCorteScreenState();
}

class _ProgramarCorteScreenState extends State<ProgramarCorteScreen> {
  late final AdminService _service = widget.servicio ?? AdminService();
  final _motivo = TextEditingController();

  OpcionesCorte? _opciones;
  String? _errorCarga;
  bool _enviando = false;

  ServicioFalla? _servicioCorte;
  // Por defecto mañana: los cortes se anuncian con anticipación
  late DateTime _fecha = DateTime(_ahora.year, _ahora.month, _ahora.day + 1);
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 12, minute: 0);
  final List<String> _barrios = [];

  DateTime get _ahora => widget.ahora ?? DateTime.now();
  DateTime get _hoy => DateTime(_ahora.year, _ahora.month, _ahora.day);

  @override
  void initState() {
    super.initState();
    _motivo.addListener(() => setState(() {}));
    _cargar();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _errorCarga = null);
    try {
      final opciones = await _service.opcionesCorte();
      if (mounted) setState(() => _opciones = opciones);
    } on AdminException catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    }
  }

  // ------------------------------------------------------------- validación

  int _minutos(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Lo que falta o está mal; null si se puede enviar.
  String? get _problema {
    if (_servicioCorte == null) return 'Elige el servicio que se cortará.';
    if (_minutos(_fin) <= _minutos(_inicio)) {
      return 'La hora de fin debe ser después de la de inicio.';
    }
    final esHoy = _fecha == _hoy;
    if (esHoy && _minutos(_fin) <= _ahora.hour * 60 + _ahora.minute) {
      return 'Ese horario de hoy ya terminó.';
    }
    if (_barrios.isEmpty) return 'Elige al menos un barrio afectado.';
    if (_motivo.text.trim().isEmpty) return 'Escribe el motivo del corte.';
    return null;
  }

  int get _usuarios => _opciones?.usuariosEn(_barrios) ?? 0;

  // ------------------------------------------------------------- acciones

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _hoy,
      // Igual que Spring: máximo 60 días de anticipación
      lastDate: _hoy.add(const Duration(days: 60)),
      helpText: 'Día del corte',
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _elegirHora({required bool inicio}) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: inicio ? _inicio : _fin,
      helpText: inicio ? 'Empieza a las' : 'Termina a las',
    );
    if (hora == null) return;
    setState(() {
      if (inicio) {
        _inicio = hora;
        // Mantiene un horario válido sin que el admin tenga que corregirlo
        if (_minutos(_fin) <= _minutos(hora)) {
          _fin = TimeOfDay(hour: (hora.hour + 2).clamp(0, 23), minute: hora.minute);
        }
      } else {
        _fin = hora;
      }
    });
  }

  Future<void> _elegirBarrios() async {
    final opciones = _opciones;
    if (opciones == null) return;
    final elegidos = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _SelectorBarrios(opciones: opciones, iniciales: _barrios),
    );
    if (elegidos != null) {
      setState(() {
        _barrios
          ..clear()
          ..addAll(elegidos);
      });
    }
  }

  Future<void> _enviar({bool confirmarSuperposicion = false}) async {
    if (_problema != null || _enviando) return;
    setState(() => _enviando = true);
    try {
      final resultado = await _service.programarCorte(
        servicio: _servicioCorte!,
        fecha: _fecha,
        horaInicio: horaTexto(_inicio),
        horaFinal: horaTexto(_fin),
        motivo: _motivo.text.trim(),
        barrios: List.of(_barrios),
        confirmarSuperposicion: confirmarSuperposicion,
      );
      if (mounted) Navigator.of(context).pop<CorteProgramadoResultado>(resultado);
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      if (!e.corteSuperpuesto) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      } else if (await _confirmarSuperposicion(e.mensaje) && mounted) {
        await _enviar(confirmarSuperposicion: true);
      }
    }
  }

  // Ya hay un corte que se cruza con este: el administrador decide
  Future<bool> _confirmarSuperposicion(String mensaje) async {
    final programar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.event_busy_rounded, color: AppColors.orange, size: 36),
        title: const Text('Ya hay un corte en ese horario'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Programar igual'),
          ),
        ],
      ),
    );
    return programar == true;
  }

  // ------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Programar corte')),
      body: _opciones == null
          ? Center(
              child: _errorCarga == null
                  ? const CircularProgressIndicator()
                  : MensajeFallas(
                      icono: Icons.cloud_off_rounded,
                      texto: _errorCarga!,
                      accion: 'Reintentar',
                      onAccion: _cargar,
                    ),
            )
          : _buildFormulario(),
    );
  }

  Widget _buildFormulario() {
    final problema = _problema;
    final horarioMalo = _minutos(_fin) <= _minutos(_inicio);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                'Los usuarios de los barrios que elijas recibirán una notificación '
                'en su celular y verán el corte en "Mi barrio".',
                style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textSecondary),
              ),
              _Paso(numero: 1, titulo: 'Servicio'),
              Row(
                children: [
                  for (final s in ServicioFalla.values) ...[
                    if (s != ServicioFalla.values.first) const SizedBox(width: 10),
                    Expanded(
                      child: _OpcionServicio(
                        servicio: s,
                        elegido: _servicioCorte == s,
                        onTap: () => setState(() => _servicioCorte = s),
                      ),
                    ),
                  ],
                ],
              ),
              _Paso(numero: 2, titulo: '¿Cuándo?'),
              _Campo(
                icono: Icons.calendar_month_rounded,
                etiqueta: 'Día',
                valor: diaRelativo(_fecha, hoy: _ahora),
                detalle: fechaLarga(_fecha),
                onTap: _elegirFecha,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Campo(
                      icono: Icons.play_circle_outline_rounded,
                      etiqueta: 'Desde',
                      valor: horaTexto(_inicio),
                      onTap: () => _elegirHora(inicio: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Campo(
                      icono: Icons.stop_circle_outlined,
                      etiqueta: 'Hasta',
                      valor: horaTexto(_fin),
                      error: horarioMalo,
                      onTap: () => _elegirHora(inicio: false),
                    ),
                  ),
                ],
              ),
              _Paso(numero: 3, titulo: 'Barrios afectados'),
              _buildBarrios(),
              _Paso(numero: 4, titulo: 'Motivo'),
              TextField(
                controller: _motivo,
                maxLength: ProgramarCorteScreen.maxMotivo,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ej.: Mantenimiento de la red en la calle 30',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 8),
              _VistaPrevia(
                servicio: _servicioCorte,
                fecha: _fecha,
                inicio: horaTexto(_inicio),
                fin: horaTexto(_fin),
                barrio: _barrios.firstOrNull,
                motivo: _motivo.text.trim(),
              ),
            ],
          ),
        ),
        _buildPie(problema),
      ],
    );
  }

  Widget _buildBarrios() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_barrios.isEmpty)
            const Text(
              'Aún no has elegido barrios.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in _barrios)
                  InputChip(
                    label: Text(nombreBarrio(b)),
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        '${_opciones!.usuariosPorBarrio[b] ?? 0}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    onDeleted: () => setState(() => _barrios.remove(b)),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _elegirBarrios,
            icon: Icon(_barrios.isEmpty ? Icons.add_location_alt_rounded : Icons.edit_location_alt_rounded),
            label: Text(_barrios.isEmpty ? 'Elegir barrios' : 'Cambiar barrios'),
          ),
        ],
      ),
    );
  }

  Widget _buildPie(String? problema) {
    final usuarios = _usuarios;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                problema == null ? Icons.notifications_active_rounded : Icons.info_outline_rounded,
                size: 18,
                color: problema == null ? AppColors.green : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  problema ??
                      (usuarios == 0
                          ? 'Aún no hay usuarios registrados en esos barrios.'
                          : usuarios == 1
                              ? '1 usuario recibirá la notificación.'
                              : '$usuarios usuarios recibirán la notificación.'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: problema == null ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.red,
            ),
            onPressed: problema == null && !_enviando ? _enviar : null,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Icon(Icons.campaign_rounded),
            label: Text(_enviando ? 'Programando…' : 'Programar y avisar'),
          ),
        ],
      ),
    );
  }
}

/// 8:05 -> "08:05"
String horaTexto(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

// =====================================================================
// Piezas del formulario
// =====================================================================

class _Paso extends StatelessWidget {
  final int numero;
  final String titulo;

  const _Paso({required this.numero, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(gradient: AppColors.naturaleza, shape: BoxShape.circle),
            child: Text(
              '$numero',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Text(titulo, style: estiloTitulo(16)),
        ],
      ),
    );
  }
}

class _OpcionServicio extends StatelessWidget {
  final ServicioFalla servicio;
  final bool elegido;
  final VoidCallback onTap;

  const _OpcionServicio({required this.servicio, required this.elegido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = servicio.color;
    return Semantics(
      selected: elegido,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: elegido ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: elegido ? color : AppColors.border, width: elegido ? 2 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(servicio.icono, color: color, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    servicio.nombre,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: elegido ? color : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final String? detalle;
  final bool error;
  final VoidCallback onTap;

  const _Campo({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.onTap,
    this.detalle,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.red : AppColors.primary;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: error ? AppColors.red : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icono, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                    ),
                    if (detalle != null && detalle != valor.toLowerCase())
                      Text(detalle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// La notificación tal como le llegará a un usuario (mismo texto que arma Spring).
class _VistaPrevia extends StatelessWidget {
  final ServicioFalla? servicio;
  final DateTime fecha;
  final String inicio;
  final String fin;
  final String? barrio;
  final String motivo;

  const _VistaPrevia({
    required this.servicio,
    required this.fecha,
    required this.inicio,
    required this.fin,
    required this.barrio,
    required this.motivo,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = servicio?.nombre.toLowerCase() ?? 'servicio';
    final titulo = 'Corte de $nombre programado en ${barrio == null ? 'tu barrio' : nombreBarrio(barrio)}';
    final mensaje = 'Habrá un corte de $nombre en tu barrio el ${fechaLarga(fecha)} de $inicio a $fin.'
        '${motivo.isEmpty ? '' : ' Motivo: $motivo.'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.visibility_outlined, size: 17, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Así les llegará la notificación',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_busy_rounded, color: AppColors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ServiApp · ahora',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      mensaje,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lista de barrios con buscador; muestra cuántos usuarios hay en cada uno.
class _SelectorBarrios extends StatefulWidget {
  final OpcionesCorte opciones;
  final List<String> iniciales;

  const _SelectorBarrios({required this.opciones, required this.iniciales});

  @override
  State<_SelectorBarrios> createState() => _SelectorBarriosState();
}

class _SelectorBarriosState extends State<_SelectorBarrios> {
  late final List<String> _elegidos = List.of(widget.iniciales);
  String _busqueda = '';

  static String _normal(String texto) => texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  @override
  Widget build(BuildContext context) {
    final filtro = _normal(_busqueda.trim());
    final barrios = [
      for (final b in widget.opciones.barrios)
        if (filtro.isEmpty || _normal(b).contains(filtro)) b,
    ];
    final usuarios = widget.opciones.usuariosEn(_elegidos);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Barrios afectados', style: estiloTitulo(18))),
                  if (_elegidos.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_elegidos.clear),
                      child: const Text('Quitar todos'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar barrio',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: barrios.isEmpty
                  ? const MensajeFallas(icono: Icons.location_off_outlined, texto: 'Ningún barrio coincide.')
                  : ListView.builder(
                      itemCount: barrios.length,
                      itemBuilder: (_, i) {
                        final b = barrios[i];
                        final cantidad = widget.opciones.usuariosPorBarrio[b] ?? 0;
                        return CheckboxListTile(
                          value: _elegidos.contains(b),
                          onChanged: (_) => setState(() {
                            if (!_elegidos.remove(b)) _elegidos.add(b);
                          }),
                          title: Text(nombreBarrio(b)),
                          subtitle: Text(
                            cantidad == 1 ? '1 usuario' : '$cantidad usuarios',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: () => Navigator.of(context).pop(List.of(_elegidos)),
                  child: Text(
                    _elegidos.isEmpty
                        ? 'Listo'
                        : 'Listo · ${_elegidos.length} ${_elegidos.length == 1 ? 'barrio' : 'barrios'}'
                            ' · $usuarios ${usuarios == 1 ? 'usuario' : 'usuarios'}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
