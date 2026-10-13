import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/services/auth_service.dart';
import '../../auth/presentation/views/home_screen.dart';
import '../../auth/presentation/views/login_screen.dart';
import '../data/predio_service.dart';

/// Registro obligatorio del predio, igual que /registrar-predio-obligatorio
/// de la web: sin predio no se puede usar la app. El estrato es el que usa
/// el análisis de consumo.
class RegistroPredioScreen extends StatefulWidget {
  final String nombre;

  const RegistroPredioScreen({super.key, required this.nombre});

  @override
  State<RegistroPredioScreen> createState() => _RegistroPredioScreenState();
}

class _RegistroPredioScreenState extends State<RegistroPredioScreen> {
  final PredioService _service = PredioService();
  final _formKey = GlobalKey<FormState>();
  final _direccion = TextEditingController();

  OpcionesPredio? _opciones;
  String? _errorCarga;

  String? _barrio;
  int? _estrato;
  String? _tipo;

  bool _mostrarErrores = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  @override
  void dispose() {
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _cargarOpciones() async {
    setState(() => _errorCarga = null);
    try {
      final opciones = await _service.opciones();
      if (mounted) setState(() => _opciones = opciones);
    } on PredioException catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    }
  }

  Future<void> _guardar() async {
    setState(() => _mostrarErrores = true);
    final valido = _formKey.currentState!.validate();
    if (!valido || _barrio == null || _estrato == null || _tipo == null) return;
    FocusScope.of(context).unfocus();

    setState(() => _guardando = true);
    try {
      await _service.registrar(
        direccion: _direccion.text.trim(),
        barrio: _barrio!,
        estrato: _estrato!,
        tipoPredio: _tipo!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(nombre: widget.nombre)),
      );
    } on PredioException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Sin predio no se puede continuar: la única salida es cerrar sesión
  Future<void> _salir() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _elegirBarrio() async {
    final barrios = _opciones?.barrios ?? const <String>[];
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SelectorBarrio(barrios: barrios, seleccionado: _barrio),
    );
    if (elegido != null) setState(() => _barrio = elegido);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Registra tu predio'),
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          actions: [
            TextButton.icon(
              onPressed: _guardando ? null : _salir,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Salir'),
            ),
          ],
        ),
        body: SafeArea(child: _cuerpo()),
      ),
    );
  }

  Widget _cuerpo() {
    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.border),
              const SizedBox(height: 16),
              Text(_errorCarga!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargarOpciones, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final opciones = _opciones;
    if (opciones == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Form(
        key: _formKey,
        autovalidateMode: _mostrarErrores ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¡Hola, ${widget.nombre.split(' ').first}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Antes de empezar, cuéntanos dónde vives. Con tu estrato comparamos tu consumo '
              'con el de hogares como el tuyo.',
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: _direccion,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              autofillHints: const [AutofillHints.fullStreetAddress],
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Ingresa la dirección de tu predio' : null,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Ej: Calle 30 # 17-45',
                prefixIcon: Icon(Icons.signpost_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            _CampoSeleccion(
              etiqueta: 'Barrio',
              valor: _barrio,
              textoVacio: 'Selecciona tu barrio',
              icono: Icons.location_city_rounded,
              error: _mostrarErrores && _barrio == null ? 'Selecciona un barrio de la lista' : null,
              onTap: _elegirBarrio,
            ),
            const SizedBox(height: 24),
            _titulo('Estrato socioeconómico'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in opciones.estratos)
                  ChoiceChip(
                    label: Text('Estrato $e'),
                    selected: _estrato == e,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _estrato == e ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _estrato = e),
                  ),
              ],
            ),
            if (_mostrarErrores && _estrato == null) _error('Selecciona tu estrato'),
            const SizedBox(height: 24),
            _titulo('Tipo de predio'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final t in opciones.tiposPredio) ...[
                  Expanded(
                    child: _TarjetaTipo(
                      tipo: t,
                      seleccionado: _tipo == t,
                      onTap: () => setState(() => _tipo = t),
                    ),
                  ),
                  if (t != opciones.tiposPredio.last) const SizedBox(width: 12),
                ],
              ],
            ),
            if (_mostrarErrores && _tipo == null) _error('Selecciona el tipo de predio'),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.home_rounded),
                label: Text(_guardando ? 'Guardando…' : 'Registrar predio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto) => Text(
        texto,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      );

  Widget _error(String texto) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(texto, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
      );
}

class _CampoSeleccion extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final String textoVacio;
  final IconData icono;
  final String? error;
  final VoidCallback onTap;

  const _CampoSeleccion({
    required this.etiqueta,
    required this.valor,
    required this.textoVacio,
    required this.icono,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          suffixIcon: const Icon(Icons.expand_more_rounded),
          errorText: error,
        ),
        child: Text(
          valor ?? textoVacio,
          style: TextStyle(
            fontSize: 16,
            color: valor == null ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TarjetaTipo extends StatelessWidget {
  final String tipo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaTipo({required this.tipo, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final esCasa = tipo == 'CASA';
    final texto = tipo[0] + tipo.substring(1).toLowerCase();
    return Material(
      color: seleccionado ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: seleccionado ? AppColors.primary : AppColors.border,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                esCasa ? Icons.house_rounded : Icons.apartment_rounded,
                size: 34,
                color: seleccionado ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: seleccionado ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de barrios con buscador (como el Select2 de la web).
class _SelectorBarrio extends StatefulWidget {
  final List<String> barrios;
  final String? seleccionado;

  const _SelectorBarrio({required this.barrios, required this.seleccionado});

  @override
  State<_SelectorBarrio> createState() => _SelectorBarrioState();
}

class _SelectorBarrioState extends State<_SelectorBarrio> {
  String _busqueda = '';

  // Sin tildes ni mayúsculas para que "nariño" encuentre "NARIÑO" y "candelaria" a "LA CANDELARIA"
  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final filtro = _normalizar(_busqueda.trim());
    final barrios = filtro.isEmpty
        ? widget.barrios
        : widget.barrios.where((b) => _normalizar(b).contains(filtro)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar barrio',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: barrios.isEmpty
                  ? const Center(
                      child: Text('No encontramos ese barrio',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      itemCount: barrios.length,
                      itemBuilder: (_, i) {
                        final barrio = barrios[i];
                        final elegido = barrio == widget.seleccionado;
                        return ListTile(
                          title: Text(barrio),
                          trailing: elegido
                              ? const Icon(Icons.check_rounded, color: AppColors.primary)
                              : null,
                          selected: elegido,
                          onTap: () => Navigator.of(context).pop(barrio),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
