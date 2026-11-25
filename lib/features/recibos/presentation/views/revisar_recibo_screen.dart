import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/boton_inicio.dart';
import '../../../analisis/presentation/views/analisis_consumo_screen.dart';
import '../../../perfil/data/perfil_service.dart';
import '../../../predio/data/predio_service.dart';
import '../../../recordatorios/recordatorios_service.dart';
import '../../data/models/recibo.dart';
import '../../data/services/recibo_service.dart';
import '../utils/formatos.dart';
import '../widgets/consumo_chart.dart';
import '../widgets/selector_periodo.dart';
import 'analizando_recibo_screen.dart';
import 'detalle_recibo_screen.dart';

/// Muestra los datos extraídos por FastAPI para que el usuario los revise,
/// corrija y confirme antes de guardarlos en Spring Boot. Con
/// [RevisarReciboScreen.editar] corrige un recibo ya guardado y devuelve el
/// recibo actualizado.
class RevisarReciboScreen extends StatefulWidget {
  final ResultadoAnalisis resultado;

  /// Foto del recibo; null al editar un recibo guardado.
  final String? rutaImagen;

  /// Id del recibo que se edita; null al guardar uno nuevo.
  final String? reciboId;

  const RevisarReciboScreen({
    super.key,
    required this.resultado,
    required String this.rutaImagen,
  }) : reciboId = null;

  RevisarReciboScreen.editar({super.key, required Recibo recibo})
      : resultado = ResultadoAnalisis(
          recibo: recibo,
          confianza: const {},
          camposFaltantes: const [],
          advertencias: const [],
          versionExtractor: '',
        ),
        rutaImagen = null,
        reciboId = recibo.id;

  @override
  State<RevisarReciboScreen> createState() => _RevisarReciboScreenState();
}

enum _Estado { ok, revisar, falta }

class _FilaConsumo {
  /// Meses respecto al mes facturado (0 = mes facturado, -1 = mes anterior...)
  final int desplazamiento;
  final TextEditingController controller;

  _FilaConsumo(this.desplazamiento, double? valor)
      : controller = TextEditingController(text: _textoNumero(valor));
}

String _textoNumero(num? valor) {
  if (valor == null) return '';
  if (valor == valor.roundToDouble()) return valor.toInt().toString();
  return valor.toString();
}

double? _leerNumero(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));

class _RevisarReciboScreenState extends State<RevisarReciboScreen> {
  static const _umbralRevision = 0.6;
  static const _maxMeses = 12;

  // Igual que Spring: un total mayor es un error de lectura
  static const _valorTotalMaximo = 10000000;

  final _formKey = GlobalKey<FormState>();
  final ReciboService _service = ReciboService();

  late final Recibo _original = widget.resultado.recibo;
  late final Map<String, double> _confianza = widget.resultado.confianza;
  late final Set<String> _faltantes = widget.resultado.camposFaltantes.toSet();

  // Campos que el usuario ya tocó: dejan de resaltarse como "revisar"
  final Set<String> _tocados = {};

  late final Map<String, TextEditingController> _texto = {
    'identificador': TextEditingController(text: _original.identificador ?? ''),
    'numeroFactura': TextEditingController(text: _original.numeroFactura ?? ''),
    'titular': TextEditingController(text: _original.titular ?? ''),
    'direccion': TextEditingController(text: _original.direccion ?? ''),
    'barrio': TextEditingController(text: _original.barrio ?? ''),
    'valorTotal': TextEditingController(text: _textoNumero(_original.valorTotal)),
    'lecturaAnterior': TextEditingController(text: _textoNumero(_original.lecturaAnterior)),
    'lecturaActual': TextEditingController(text: _textoNumero(_original.lecturaActual)),
    'diasFacturados': TextEditingController(text: _textoNumero(_original.diasFacturados)),
  };

  late Periodo? _periodo = Periodo.parse(_original.periodoFacturado);
  late int? _estrato = _original.estrato;
  late DateTime? _periodoInicio = _original.periodoInicio;
  late DateTime? _periodoFin = _original.periodoFin;
  late DateTime? _fechaEmision = _original.fechaEmision;
  late DateTime? _fechaLimitePago = _original.fechaLimitePago;
  late DateTime? _fechaSuspension = _original.fechaSuspension;
  late final List<_FilaConsumo> _filas = _filasIniciales();

  String? _duplicadoId;

  // NIC, póliza o contrato de los recibos ya guardados de la empresa cuando
  // este recibo es de otro: solo se pueden guardar recibos de ese
  String? _identificadorRegistrado;
  bool _guardando = false;

  // Predio del usuario, para avisar si el estrato o el barrio no coinciden
  Predio? _predio;

  Empresa get _empresa => _original.empresa;

  bool get _editando => widget.reciboId != null;

  String get _identificadorEscrito =>
      _texto['identificador']!.text.replaceAll(RegExp(r'\s'), '');

  bool get _esOtroIdentificador =>
      _identificadorRegistrado != null &&
      _identificadorEscrito != _identificadorRegistrado;

  @override
  void initState() {
    super.initState();
    _verificar();
    _cargarPredio();
  }

  Future<void> _cargarPredio() async {
    try {
      final perfil = await PerfilService().obtener();
      if (mounted) setState(() => _predio = perfil.predio);
    } on PerfilException {
      // Sin el predio solo se omite el aviso
    }
  }

  @override
  void dispose() {
    for (final c in _texto.values) {
      c.dispose();
    }
    for (final f in _filas) {
      f.controller.dispose();
    }
    super.dispose();
  }

  List<_FilaConsumo> _filasIniciales() {
    final filas = <_FilaConsumo>[];
    final periodo = _periodo;
    final historial = _original.historialConsumos;
    for (var i = 0; i < historial.length; i++) {
      final p = Periodo.parse(historial[i].periodo);
      // Sin mes facturado: se ubican por orden (el último es el actual)
      final desplazamiento = (periodo != null && p != null)
          ? p.compareTo(periodo)
          : i - (historial.length - 1);
      if (desplazamiento <= 0 && !filas.any((f) => f.desplazamiento == desplazamiento)) {
        filas.add(_FilaConsumo(desplazamiento, historial[i].consumo));
      }
    }
    if (!filas.any((f) => f.desplazamiento == 0)) {
      filas.add(_FilaConsumo(0, _original.consumoActual));
    }
    filas.sort((a, b) => a.desplazamiento.compareTo(b.desplazamiento));
    return filas;
  }

  Future<void> _verificar() async {
    final verificacion = await _service.verificar(_original);
    if (!mounted) return;
    setState(() {
      // Al editar, el "duplicado" es el mismo recibo
      _duplicadoId = verificacion.duplicadoId == widget.reciboId ? null : verificacion.duplicadoId;
      _identificadorRegistrado = verificacion.identificadorRegistrado;
    });
  }

  void _usarIdentificadorRegistrado() {
    final registrado = _identificadorRegistrado;
    if (registrado == null) return;
    setState(() {
      _texto['identificador']!.text = registrado;
      _tocados.add('identificador');
    });
  }

  // ---------------------------------------------------------------- estado

  _Estado _estado(String campo, {required bool vacio}) {
    if (vacio) {
      return _faltantes.contains(campo) ? _Estado.falta : _Estado.ok;
    }
    final c = _confianza[campo];
    if (c != null && c < _umbralRevision && !_tocados.contains(campo)) {
      return _Estado.revisar;
    }
    return _Estado.ok;
  }

  int get _pendientes {
    var total = 0;
    for (final campo in ['identificador', 'valorTotal']) {
      if (_estado(campo, vacio: _texto[campo]!.text.trim().isEmpty) != _Estado.ok) {
        total++;
      }
    }
    if (_periodo == null) total++;
    if (_estado('historialConsumos', vacio: false) == _Estado.revisar) total++;
    if (_filas.any((f) => f.controller.text.trim().isEmpty)) total++;
    return total;
  }

  // ---------------------------------------------------------------- guardar

  Recibo _construirRecibo() {
    String? texto(String campo) {
      final valor = _texto[campo]!.text.trim();
      return valor.isEmpty ? null : valor;
    }

    final periodo = _periodo!;
    final historial = [
      for (final f in _filas)
        ConsumoMensual(
          periodo: periodo.sumar(f.desplazamiento).toString(),
          consumo: _leerNumero(f.controller.text),
          esActual: f.desplazamiento == 0,
        ),
    ];
    final actual = _filas.firstWhere((f) => f.desplazamiento == 0);

    return Recibo(
      empresa: _empresa,
      identificador: texto('identificador')?.replaceAll(RegExp(r'\s'), ''),
      numeroFactura: texto('numeroFactura'),
      titular: texto('titular')?.toUpperCase(),
      direccion: texto('direccion')?.toUpperCase(),
      barrio: texto('barrio')?.toUpperCase(),
      estrato: _estrato,
      periodoFacturado: periodo.toString(),
      periodoInicio: _periodoInicio,
      periodoFin: _periodoFin,
      fechaEmision: _fechaEmision,
      fechaLimitePago: _fechaLimitePago,
      fechaSuspension: _fechaSuspension,
      valorTotal: int.tryParse(texto('valorTotal') ?? ''),
      consumoActual: _leerNumero(actual.controller.text),
      lecturaAnterior: _leerNumero(_texto['lecturaAnterior']!.text),
      lecturaActual: _leerNumero(_texto['lecturaActual']!.text),
      diasFacturados: int.tryParse(texto('diasFacturados') ?? ''),
      historialConsumos: historial,
      conceptos: _original.conceptos,
    );
  }

  /// Campos que el usuario cambió respecto a lo que leyó el OCR (calidad del dato).
  List<String> _camposCorregidos(Recibo r) {
    final o = _original;
    final cambios = <String>[];
    void comparar(String campo, Object? antes, Object? despues) {
      if ('${antes ?? ''}'.trim().toUpperCase() != '${despues ?? ''}'.trim().toUpperCase()) {
        cambios.add(campo);
      }
    }

    comparar('identificador', o.identificador, r.identificador);
    comparar('numeroFactura', o.numeroFactura, r.numeroFactura);
    comparar('titular', o.titular, r.titular);
    comparar('direccion', o.direccion, r.direccion);
    comparar('barrio', o.barrio, r.barrio);
    comparar('estrato', o.estrato, r.estrato);
    comparar('periodoFacturado', o.periodoFacturado, r.periodoFacturado);
    comparar('periodoInicio', o.periodoInicio, r.periodoInicio);
    comparar('periodoFin', o.periodoFin, r.periodoFin);
    comparar('fechaEmision', o.fechaEmision, r.fechaEmision);
    comparar('fechaLimitePago', o.fechaLimitePago, r.fechaLimitePago);
    comparar('fechaSuspension', o.fechaSuspension, r.fechaSuspension);
    comparar('valorTotal', o.valorTotal, r.valorTotal);
    comparar('consumoActual', o.consumoActual, r.consumoActual);
    comparar('lecturaAnterior', o.lecturaAnterior, r.lecturaAnterior);
    comparar('lecturaActual', o.lecturaActual, r.lecturaActual);
    comparar('diasFacturados', o.diasFacturados, r.diasFacturados);
    final antes = {for (final c in o.historialConsumos) c.periodo: c.consumo};
    final despues = {for (final c in r.historialConsumos) c.periodo: c.consumo};
    if (antes.length != despues.length ||
        despues.entries.any((e) => antes[e.key] != e.value)) {
      cambios.add('historialConsumos');
    }
    return cambios;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final formularioValido = _formKey.currentState!.validate();
    if (_periodo == null) {
      _mostrarMensaje('Selecciona el mes facturado del recibo.');
      return;
    }
    if (!formularioValido) {
      _mostrarMensaje('Revisa los campos marcados en rojo.');
      return;
    }
    final problema = _primerProblema();
    if (problema != null) {
      _mostrarMensaje(problema);
      return;
    }
    if (!await _confirmarDatosDelPredio() || !mounted) return;

    final recibo = _construirRecibo();
    setState(() => _guardando = true);
    try {
      final id = widget.reciboId;
      if (id != null) {
        final actualizado = await _service.actualizar(
          id,
          recibo,
          camposCorregidos: _camposCorregidos(recibo),
        );
        await RecordatoriosService.actualizarRecibo(actualizado);
        if (mounted) Navigator.of(context).pop(actualizado);
        return;
      }
      final guardado = await _service.guardar(
        recibo,
        confianza: _confianza,
        camposCorregidos: _camposCorregidos(recibo),
        versionExtractor: widget.resultado.versionExtractor,
      );
      // Programa los recordatorios de pago del recibo nuevo
      await RecordatoriosService.actualizarRecibo(guardado);
      if (!mounted) return;
      // Spring analiza el consumo del recibo y se muestra de una vez
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AnalisisConsumoScreen(recibo: guardado, recienGuardado: true),
        ),
      );
    } on ReciboException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (e.esDuplicado) {
        setState(() => _duplicadoId = e.reciboId);
        _dialogoDuplicado(e.mensaje);
      } else if (e.esIdentificadorDistinto) {
        setState(() => _identificadorRegistrado = e.identificadorRegistrado);
        _dialogoIdentificadorDistinto(e.mensaje);
      } else {
        // Sin código: no hubo respuesta del servidor (sin internet)
        _mostrarMensaje(e.mensaje, reintentar: e.codigo == null ? _guardar : null);
      }
    }
  }

  // ---------------------------------------------------------- validaciones
  // Las mismas reglas de Spring, para avisar antes de enviar

  String? _errorPeriodo() {
    final periodo = _periodo;
    if (periodo == null || periodo.esValidoParaRecibo) return null;
    return 'Elige un mes entre ${formatearPeriodoLargo(Periodo.minimoRecibo.toString())} '
        'y ${formatearPeriodoLargo(Periodo.maximoRecibo.toString())}';
  }

  String? _errorValorTotal(String texto) {
    final valor = int.tryParse(texto.trim());
    if (valor == null) return null;
    if (valor <= 0) return 'Debe ser mayor que cero';
    if (valor > _valorTotalMaximo) return 'Parece demasiado alto, revísalo';
    return null;
  }

  String? _errorLecturaActual(String texto) {
    final actual = _leerNumero(texto);
    final anterior = _leerNumero(_texto['lecturaAnterior']!.text);
    if (actual != null && anterior != null && actual < anterior) {
      return 'No puede ser menor que la anterior';
    }
    return null;
  }

  String? _errorConsumo(String texto) {
    final consumo = _leerNumero(texto);
    final maximo = _empresa.consumoMaximo;
    if (consumo != null && consumo > maximo) {
      return 'Máx. ${_textoNumero(maximo)} ${_empresa.unidad}';
    }
    return null;
  }

  String? _errorFecha(String campo) {
    final emision = _fechaEmision;
    final limite = _fechaLimitePago;
    if (campo == 'fechaLimitePago' && emision != null && limite != null && limite.isBefore(emision)) {
      return 'No puede ser antes de la emisión';
    }
    final inicio = _periodoInicio;
    final fin = _periodoFin;
    if (campo == 'periodoFin' && inicio != null && fin != null && fin.isBefore(inicio)) {
      return 'Es antes de "Desde"';
    }
    return null;
  }

  /// Primer dato fuera de las reglas que no es un campo de formulario.
  String? _primerProblema() {
    final periodo = _errorPeriodo();
    if (periodo != null) return 'Mes facturado: $periodo.';
    if (_errorFecha('fechaLimitePago') != null) {
      return 'La fecha de pago oportuno no puede ser anterior a la de emisión.';
    }
    if (_errorFecha('periodoFin') != null) {
      return 'El periodo facturado termina antes de empezar. Revisa las fechas.';
    }
    if (_filas.any((f) => _errorConsumo(f.controller.text) != null)) {
      return 'Un consumo supera ${_textoNumero(_empresa.consumoMaximo)} ${_empresa.unidad}. '
          'Revisa que esté bien escrito.';
    }
    return null;
  }

  // ------------------------------------------------------------ predio

  static String _normalizar(String texto) => texto
      .toUpperCase()
      .replaceAll(RegExp('[ÁÀ]'), 'A')
      .replaceAll(RegExp('[ÉÈ]'), 'E')
      .replaceAll(RegExp('[ÍÌ]'), 'I')
      .replaceAll(RegExp('[ÓÒ]'), 'O')
      .replaceAll(RegExp('[ÚÙÜ]'), 'U')
      .replaceAll(RegExp(r'[^A-ZÑ0-9]+'), ' ')
      .trim();

  /// El barrio leído del recibo no corresponde al del predio.
  bool get _barrioDistinto {
    final predio = _predio;
    final barrio = _texto['barrio']!.text.trim();
    if (predio == null || barrio.isEmpty) return false;
    final delRecibo = _normalizar(barrio);
    final delPredio = _normalizar(predio.barrio);
    return !delRecibo.contains(delPredio) && !delPredio.contains(delRecibo);
  }

  bool get _estratoDistinto {
    final predio = _predio;
    return predio != null && _estrato != null && _estrato != predio.estrato;
  }

  /// Si el estrato o el barrio no coinciden con el predio, pregunta antes de
  /// guardar (el análisis de consumo usa el estrato). Devuelve si se guarda.
  Future<bool> _confirmarDatosDelPredio() async {
    final predio = _predio;
    if (predio == null || (!_estratoDistinto && !_barrioDistinto)) return true;

    final diferencias = [
      if (_estratoDistinto)
        'El recibo dice estrato $_estrato y tu predio es estrato ${predio.estrato}.',
      if (_barrioDistinto)
        'El recibo dice barrio ${_texto['barrio']!.text.trim().toUpperCase()} '
            'y tu predio está en ${predio.barrio}.',
    ];
    final opcion = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.home_work_outlined, color: AppColors.orange, size: 36),
        title: const Text('No coincide con tu predio'),
        content: Text(
          '${diferencias.join('\n\n')}\n\nEl análisis de consumo usa el estrato. '
          'Si el recibo es de tu casa, usa los datos de tu predio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop('guardar'),
            child: const Text('Guardar así'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop('predio'),
            child: const Text('Usar mi predio'),
          ),
        ],
      ),
    );
    if (opcion == 'predio') {
      setState(() {
        if (_estratoDistinto) {
          _estrato = predio.estrato;
          _tocados.add('estrato');
        }
        if (_barrioDistinto) {
          _texto['barrio']!.text = predio.barrio;
          _tocados.add('barrio');
        }
      });
    }
    return opcion != null;
  }

  void _dialogoDuplicado(String mensaje) {
    showDialog<void>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.inventory_2_outlined, color: AppColors.orange, size: 36),
        title: const Text('Recibo ya registrado'),
        content: Text(
          '$mensaje\n\nSi quieres registrarlo de nuevo, primero bórralo de '
          'Mis recibos. Si el mes o ${_empresa.identificadorEnFrase} están '
          'mal leídos, corrígelos y vuelve a guardar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Corregir datos'),
          ),
          if (_duplicadoId != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogo).pop();
                _abrirExistente();
              },
              child: const Text('Ver recibo guardado'),
            ),
        ],
      ),
    );
  }

  void _dialogoIdentificadorDistinto(String mensaje) {
    final registrado = _identificadorRegistrado;
    showDialog<void>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.badge_outlined, color: AppColors.red, size: 36),
        title: Text('${_empresa.identificador} diferente'),
        content: Text(
          '$mensaje\n\nSi leímos mal ${_empresa.identificadorEnFrase} de este '
          'recibo, corrígelo y vuelve a guardar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Corregir datos'),
          ),
          if (registrado != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogo).pop();
                _usarIdentificadorRegistrado();
              },
              child: Text('Usar $registrado'),
            ),
        ],
      ),
    );
  }

  Future<void> _abrirExistente() async {
    final id = _duplicadoId;
    if (id == null) return;
    try {
      final recibo = await _service.obtener(id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetalleReciboScreen(recibo: recibo)),
      );
    } on ReciboException catch (e) {
      _mostrarMensaje(e.mensaje);
    }
  }

  void _mostrarMensaje(String mensaje, {VoidCallback? reintentar}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        action: reintentar == null
            ? null
            : SnackBarAction(label: 'Reintentar', onPressed: reintentar),
      ),
    );
  }

  void _cambiarEmpresa() async {
    final empresa = await showModalBottomSheet<Empresa>(
      context: context,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                '¿De qué empresa es el recibo?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final e in Empresa.values.where((e) => e != _empresa))
              ListTile(
                leading: Icon(e.icono, color: e.color),
                title: Text(e.nombre),
                subtitle: Text(e.servicio),
                onTap: () => Navigator.of(hoja).pop(e),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (empresa == null || !mounted) return;
    // Se vuelve a analizar la foto con el extractor de la empresa correcta
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AnalizandoReciboScreen(rutaImagen: widget.rutaImagen!, empresa: empresa),
      ),
    );
  }

  void _verFoto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Foto del recibo'),
          ),
          body: InteractiveViewer(
            maxScale: 6,
            child: Center(child: Image.file(File(widget.rutaImagen!))),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final pendientes = _pendientes;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar recibo' : 'Revisa los datos'),
        actions: [
          if (widget.rutaImagen != null)
            IconButton(
              tooltip: 'Ver foto',
              onPressed: _verFoto,
              icon: const Icon(Icons.image_search_rounded),
            ),
          const BotonInicio(),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
          children: [
            _buildEmpresa(),
            if (_esOtroIdentificador) _buildAvisoIdentificador(),
            if (_duplicadoId != null) _buildAvisoDuplicado(),
            if (_editando)
              _aviso(
                color: AppColors.primary,
                icono: Icons.edit_note_rounded,
                texto: 'Corrige los datos que estén mal y guarda los cambios. '
                    'El análisis de consumo se volverá a calcular.',
              )
            else
              _buildResumenRevision(pendientes),
            _seccion('Datos principales', Icons.receipt_long_outlined, [
              _campoTexto(
                'identificador',
                _empresa.identificador,
                obligatorio: true,
                teclado: TextInputType.number,
                formatos: [FilteringTextInputFormatter.digitsOnly],
              ),
              _campoPeriodo(),
              _campoTexto(
                'valorTotal',
                'Total a pagar',
                obligatorio: true,
                validar: _errorValorTotal,
                prefijo: '\$ ',
                teclado: TextInputType.number,
                formatos: [FilteringTextInputFormatter.digitsOnly],
              ),
              _campoTexto('numeroFactura', 'Número de factura'),
            ]),
            _seccion('Fechas', Icons.event_outlined, [
              _campoFecha('fechaEmision', 'Fecha de emisión', _fechaEmision,
                  (f) => _fechaEmision = f),
              _campoFecha('fechaLimitePago', 'Pago oportuno (límite)', _fechaLimitePago,
                  (f) => _fechaLimitePago = f),
              _campoFecha('fechaSuspension', 'Fecha de corte (suspensión)', _fechaSuspension,
                  (f) => _fechaSuspension = f),
              Row(
                children: [
                  Expanded(
                    child: _campoFecha('periodoInicio', 'Desde', _periodoInicio,
                        (f) => _periodoInicio = f),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _campoFecha('periodoFin', 'Hasta', _periodoFin,
                        (f) => _periodoFin = f),
                  ),
                ],
              ),
            ]),
            _seccion('Consumo', Icons.speed_rounded, [
              Row(
                children: [
                  Expanded(
                    child: _campoTexto('lecturaAnterior', 'Lectura anterior',
                        teclado: const TextInputType.numberWithOptions(decimal: true),
                        formatos: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _campoTexto('lecturaActual', 'Lectura actual',
                        validar: _errorLecturaActual,
                        teclado: const TextInputType.numberWithOptions(decimal: true),
                        formatos: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]),
                  ),
                ],
              ),
              _campoTexto('diasFacturados', 'Días facturados',
                  teclado: TextInputType.number,
                  formatos: [FilteringTextInputFormatter.digitsOnly]),
            ]),
            _buildHistorial(),
            _seccion('Titular y ubicación', Icons.home_outlined, [
              _campoTexto('titular', 'Titular', mayusculas: true),
              _campoTexto('direccion', 'Dirección', mayusculas: true),
              _campoTexto('barrio', 'Barrio', mayusculas: true),
              _campoEstrato(),
            ]),
            if (widget.resultado.advertencias.isNotEmpty) _buildAdvertencias(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_guardando
                ? 'Guardando…'
                : _editando
                ? 'Guardar cambios'
                : 'Confirmar y guardar'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpresa() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (widget.rutaImagen case final ruta?)
          GestureDetector(
            onTap: _verFoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(ruta),
                width: 54,
                height: 68,
                fit: BoxFit.cover,
                cacheWidth: 200,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_empresa.icono, color: _empresa.color, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _empresa.nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_empresa.servicio} · consumo en ${_empresa.unidad}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                if (!_editando)
                GestureDetector(
                  onTap: _cambiarEmpresa,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '¿No es esta empresa?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoDuplicado() {
    return _aviso(
      color: AppColors.orange,
      icono: Icons.inventory_2_outlined,
      texto: 'Ya registraste el recibo de ${_empresa.nombre} de '
          '${formatearPeriodoLargo(_original.periodoFacturado)} y no se puede '
          'guardar dos veces. Para registrarlo de nuevo, primero bórralo de Mis recibos.',
      accion: TextButton(onPressed: _abrirExistente, child: const Text('Ver')),
    );
  }

  Widget _buildAvisoIdentificador() {
    return _aviso(
      color: AppColors.red,
      icono: Icons.badge_outlined,
      texto: 'Tus recibos de ${_empresa.nombre} tienen '
          '${_empresa.identificadorEnFrase} $_identificadorRegistrado y solo '
          'puedes guardar recibos con ese número. Para usar otro, borra tus '
          'recibos de ${_empresa.nombre} o restablece tu cuenta desde tu perfil.',
      accion: TextButton(
        onPressed: _usarIdentificadorRegistrado,
        child: const Text('Usar'),
      ),
    );
  }

  Widget _buildResumenRevision(int pendientes) {
    if (pendientes == 0) {
      return _aviso(
        color: AppColors.green,
        icono: Icons.verified_outlined,
        texto: 'Leímos tu recibo. Confirma que los datos coinciden con el papel.',
      );
    }
    return _aviso(
      color: AppColors.orange,
      icono: Icons.edit_note_rounded,
      texto: pendientes == 1
          ? 'Hay 1 dato por revisar o completar (resaltado en naranja o rojo).'
          : 'Hay $pendientes datos por revisar o completar (resaltados en naranja o rojo).',
    );
  }

  Widget _buildAdvertencias() {
    return _seccion('Notas del análisis', Icons.info_outline_rounded, [
      for (final a in widget.resultado.advertencias)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(color: AppColors.textSecondary)),
              Expanded(
                child: Text(
                  a,
                  style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _aviso({
    required Color color,
    required IconData icono,
    required String texto,
    Widget? accion,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.textPrimary),
            ),
          ),
          ?accion,
        ],
      ),
    );
  }

  Widget _seccion(String titulo, IconData icono, List<Widget> hijos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...hijos,
        ],
      ),
    );
  }

  InputDecoration _decoracion(
    String? etiqueta,
    _Estado estado, {
    String? prefijo,
    Widget? sufijo,
    bool mostrarAyuda = true,
    // Dato fuera de las reglas (mes, consumo, fechas)
    String? error,
  }) {
    final color = switch (estado) {
      _Estado.ok => AppColors.border,
      _Estado.revisar => AppColors.orange,
      _Estado.falta => AppColors.red,
    };
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: estado == _Estado.ok ? 1 : 1.6),
    );
    return InputDecoration(
      labelText: etiqueta,
      prefixText: prefijo,
      isDense: true,
      enabledBorder: borde,
      border: borde,
      helperText: !mostrarAyuda ? null : switch (estado) {
        _Estado.ok => null,
        _Estado.revisar => 'Revisa este dato con el recibo',
        _Estado.falta => 'No se pudo leer, ingrésalo',
      },
      helperStyle: TextStyle(color: color == AppColors.border ? null : color),
      errorText: error,
      errorMaxLines: 2,
      suffixIcon: sufijo ??
          (estado == _Estado.ok
              ? null
              : Icon(Icons.warning_amber_rounded, color: color, size: 20)),
    );
  }

  Widget _campoTexto(
    String campo,
    String etiqueta, {
    bool obligatorio = false,
    bool mayusculas = false,
    String? prefijo,
    TextInputType? teclado,
    List<TextInputFormatter>? formatos,
    String? Function(String valor)? validar,
  }) {
    final controller = _texto[campo]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: teclado,
        inputFormatters: formatos,
        textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.none,
        decoration: _decoracion(
          etiqueta,
          _estado(campo, vacio: controller.text.trim().isEmpty),
          prefijo: prefijo,
        ),
        autovalidateMode: validar == null ? null : AutovalidateMode.onUserInteraction,
        validator: (valor) {
          if (obligatorio && (valor == null || valor.trim().isEmpty)) {
            return 'Este dato es obligatorio';
          }
          return validar?.call(valor ?? '');
        },
        onChanged: (_) => setState(() => _tocados.add(campo)),
      ),
    );
  }

  Widget _campoFecha(
    String campo,
    String etiqueta,
    DateTime? valor,
    void Function(DateTime?) asignar,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final ahora = DateTime.now();
          final elegida = await showDatePicker(
            context: context,
            initialDate: valor ?? ahora,
            firstDate: DateTime(2015),
            lastDate: DateTime(ahora.year + 2),
          );
          if (elegida != null) {
            setState(() {
              asignar(elegida);
              _tocados.add(campo);
            });
          }
        },
        child: InputDecorator(
          isEmpty: valor == null,
          decoration: _decoracion(
            etiqueta,
            _estado(campo, vacio: valor == null),
            error: _errorFecha(campo),
            sufijo: valor == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() {
                      asignar(null);
                      _tocados.add(campo);
                    }),
                  ),
          ),
          child: Text(valor == null ? '' : formatearFecha(valor)),
        ),
      ),
    );
  }

  Widget _campoPeriodo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final elegido = await seleccionarPeriodo(context, _periodo);
          if (elegido != null) {
            setState(() {
              _periodo = elegido;
              _tocados.add('periodoFacturado');
            });
          }
        },
        child: InputDecorator(
          isEmpty: _periodo == null,
          decoration: _decoracion(
            'Mes facturado',
            _periodo == null
                ? _Estado.falta
                : _estado('periodoFacturado', vacio: false),
            sufijo: const Icon(Icons.expand_more_rounded),
            error: _errorPeriodo(),
          ),
          child: Text(_periodo == null ? '' : formatearPeriodoLargo(_periodo.toString())),
        ),
      ),
    );
  }

  Widget _campoEstrato() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        // Se reconstruye si el estrato cambia desde "Usar mi predio"
        key: ValueKey(_estrato),
        initialValue: _estrato,
        decoration: _decoracion('Estrato', _estado('estrato', vacio: _estrato == null)),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Sin estrato / no aplica')),
          for (var i = 1; i <= 6; i++)
            DropdownMenuItem<int?>(value: i, child: Text('Estrato $i')),
        ],
        onChanged: (valor) => setState(() {
          _estrato = valor;
          _tocados.add('estrato');
        }),
      ),
    );
  }

  Widget _buildHistorial() {
    final periodo = _periodo;
    final estado = _estado('historialConsumos', vacio: false);
    final vista = periodo == null
        ? <ConsumoMensual>[]
        : [
            for (final f in _filas)
              ConsumoMensual(
                periodo: periodo.sumar(f.desplazamiento).toString(),
                consumo: _leerNumero(f.controller.text),
                esActual: f.desplazamiento == 0,
              ),
          ];

    return _seccion('Historial de consumo (${_empresa.unidad})', Icons.bar_chart_rounded, [
      Text(
        _empresa == Empresa.surtigas
            ? 'El recibo de gas solo trae el consumo del mes. '
                'Puedes agregar meses anteriores si los conoces.'
            : 'Valores de la gráfica del recibo. El último es el mes facturado.',
        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
      ),
      if (estado == _Estado.revisar)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'La gráfica fue difícil de leer: compara cada mes con el recibo.',
            style: TextStyle(fontSize: 13, color: AppColors.orange, fontWeight: FontWeight.w600),
          ),
        ),
      const SizedBox(height: 14),
      if (vista.isNotEmpty && vista.any((c) => c.consumo != null)) ...[
        ConsumoChart(historial: vista, color: _empresa.color, unidad: _empresa.unidad),
        const SizedBox(height: 16),
      ],
      for (final fila in _filas) _buildFilaConsumo(fila),
      if (_filas.length < _maxMeses)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              final primero = _filas.first.desplazamiento;
              _filas.insert(0, _FilaConsumo(primero - 1, null));
              _tocados.add('historialConsumos');
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar mes anterior'),
          ),
        ),
    ]);
  }

  Widget _buildFilaConsumo(_FilaConsumo fila) {
    final periodo = _periodo;
    final esActual = fila.desplazamiento == 0;
    final etiqueta = periodo == null
        ? (esActual ? 'Mes facturado' : 'Mes ${fila.desplazamiento}')
        : formatearPeriodoLargo(periodo.sumar(fila.desplazamiento).toString());
    final vacio = fila.controller.text.trim().isEmpty;
    final estado = vacio
        ? _Estado.falta
        : (esActual ? _estado('consumoActual', vacio: false) : _Estado.ok);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (esActual)
                  const Text(
                    'Mes facturado',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: TextField(
              controller: fila.controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textAlign: TextAlign.end,
              decoration: _decoracion(
                null,
                estado,
                mostrarAyuda: false,
                error: _errorConsumo(fila.controller.text),
                sufijo: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 12),
                  child: Text(_empresa.unidad, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              onChanged: (_) => setState(() {
                _tocados.add(esActual ? 'consumoActual' : 'historialConsumos');
              }),
            ),
          ),
          SizedBox(
            width: 44,
            child: esActual
                ? null
                : IconButton(
                    tooltip: 'Quitar mes',
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                    onPressed: () {
                      setState(() {
                        _filas.remove(fila);
                        _tocados.add('historialConsumos');
                      });
                      // Se libera cuando el campo ya salió de la pantalla
                      WidgetsBinding.instance.addPostFrameCallback((_) => fila.controller.dispose());
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
