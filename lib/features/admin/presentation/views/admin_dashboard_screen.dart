import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../../auth/presentation/widgets/escena_naturaleza.dart';
import '../../../recibos/data/models/recibo.dart';
import '../../../recibos/presentation/utils/formatos.dart';
import '../../../recordatorios/recordatorios_service.dart';
import '../../data/models/estadisticas.dart';
import '../../data/services/admin_service.dart';
import '../widgets/graficas.dart';
import 'admin_fallas_screen.dart';

/// Panel de los administradores: solo estadísticas de ServiApp, sin datos
/// personales. Se actualiza solo cada [intervalo] mientras está en pantalla.
class AdminDashboardScreen extends StatefulWidget {
  final String nombre;

  /// Permite usar datos de prueba en los tests.
  final AdminService? servicio;

  const AdminDashboardScreen({super.key, required this.nombre, this.servicio});

  /// Cada cuánto se vuelven a pedir las estadísticas a Spring Boot.
  static const Duration intervalo = Duration(seconds: 10);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

enum _Seccion {
  resumen('Resumen', Icons.dashboard_rounded),
  usuarios('Usuarios', Icons.groups_rounded),
  consumo('Consumo', Icons.insights_rounded),
  recibos('Recibos', Icons.receipt_long_rounded),
  reportes('Reportes', Icons.report_gmailerrorred_rounded);

  const _Seccion(this.titulo, this.icono);

  final String titulo;
  final IconData icono;
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin, RelojEscena, WidgetsBindingObserver {
  late final AdminService _service = widget.servicio ?? AdminService();
  final Map<_Seccion, GlobalKey> _anclas = {
    for (final s in _Seccion.values) s: GlobalKey(),
  };

  Estadisticas? _datos;
  String? _error;
  bool _consultando = false;
  bool _sinConexion = false;
  bool _visible = false;
  DateTime? _actualizado;
  Timer? _temporizador;
  _Seccion _seccion = _Seccion.resumen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _iniciarTemporizador();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Sin la app en pantalla no se consulta el servidor; al volver se refresca.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _cargar();
      _iniciarTemporizador();
    } else if (estado == AppLifecycleState.paused ||
        estado == AppLifecycleState.hidden) {
      _temporizador?.cancel();
    }
  }

  void _iniciarTemporizador() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(
      AdminDashboardScreen.intervalo,
      (_) => _cargar(),
    );
  }

  Future<void> _cargar() async {
    if (_consultando) return;
    _consultando = true;
    try {
      final datos = await _service.estadisticas();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _error = null;
        _sinConexion = false;
        _actualizado = DateTime.now();
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        _temporizador?.cancel();
        _irAlLogin(mensaje: e.mensaje);
        return;
      }
      // Se conservan los últimos datos y se sigue intentando
      setState(() {
        _sinConexion = true;
        if (_datos == null) _error = e.mensaje;
      });
    } finally {
      _consultando = false;
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          size: 40,
          color: AppColors.primary,
        ),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que iniciar sesión de nuevo para ver el panel.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    _temporizador?.cancel();
    await RecordatoriosService.alCerrarSesion();
    await AuthService().logout();
    if (mounted) _irAlLogin();
  }

  void _irAlLogin({String? mensaje}) {
    final mensajero = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    if (mensaje != null) {
      mensajero.showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  void _irA(_Seccion seccion) {
    setState(() => _seccion = seccion);
    final contexto = _anclas[seccion]?.currentContext;
    if (contexto != null) {
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    }
  }

  // ================================================================ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _cargar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildHeader(), _buildContenido()],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final primerNombre = widget.nombre.trim().split(RegExp(r'\s+')).first;

    return EncabezadoNaturaleza(
      tiempo: tiempo,
      cantidadHojas: 14,
      child: Padding(
        padding: EdgeInsets.fromLTRB(26, topPadding + 22, 26, 40),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 700),
          opacity: _visible ? 1 : 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'ServiApp',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: estiloTitulo(23, color: Colors.white)
                                .copyWith(
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _PildoraBlanca(
                          icono: Icons.verified_user_rounded,
                          texto: 'Admin',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PildoraBlanca(
                    icono: Icons.logout_rounded,
                    texto: 'Salir',
                    tooltip: 'Cerrar sesión',
                    onTap: _cerrarSesion,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Icon(
                    Icons.waving_hand_rounded,
                    color: AppColors.sun,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Hola, $primerNombre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Panel de control',
                style: estiloTitulo(26, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Así se mueve ServiApp en este momento.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _IndicadorEnVivo(
                tiempo: tiempo,
                actualizado: _actualizado,
                sinConexion: _sinConexion,
              ),
              const SizedBox(height: 14),
              // Fallas que reportan los usuarios (cambiar su estado les avisa)
              Align(
                alignment: Alignment.centerLeft,
                child: _PildoraBlanca(
                  icono: Icons.report_problem_rounded,
                  texto: 'Fallas reportadas',
                  tooltip: 'Gestionar las fallas que reportan los usuarios',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminFallasScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    final datos = _datos;

    if (datos == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: AppColors.primary)
              : _ErrorCarga(mensaje: _error!, onReintentar: _cargar),
        ),
      );
    }

    return AnimatedSlide(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.05),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 650),
        opacity: _visible ? 1 : 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildNavegacion(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._seccionResumen(datos),
                  ..._seccionUsuarios(datos),
                  ..._seccionConsumo(datos),
                  ..._seccionRecibos(datos),
                  ..._seccionReportes(datos),
                  const SizedBox(height: 26),
                  Center(
                    child: Text(
                      'Datos en vivo de la base de datos · '
                      'se actualizan cada ${AdminDashboardScreen.intervalo.inSeconds} s',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

  // Pestañas para saltar entre secciones
  Widget _buildNavegacion() {
    // Alto extra para que no se corte la sombra de la pestaña activa
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        itemCount: _Seccion.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final seccion = _Seccion.values[i];
          final activa = seccion == _seccion;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              gradient: activa ? AppColors.naturaleza : null,
              color: activa ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: activa ? Colors.transparent : AppColors.border,
              ),
              boxShadow: activa
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(21),
                onTap: () => _irA(seccion),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        seccion.icono,
                        size: 17,
                        color: activa ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        seccion.titulo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: activa ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _titulo(_Seccion seccion, String descripcion) {
    return Padding(
      key: _anclas[seccion],
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(seccion.titulo, style: estiloTitulo(20)),
              const SizedBox(width: 8),
              const Icon(Icons.eco_rounded, color: AppColors.green, size: 19),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            descripcion,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static const _espacio = SizedBox(height: 14);

  // ---------------------------------------------------------- Resumen

  List<Widget> _seccionResumen(Estadisticas d) {
    final r = d.resumen;
    final pendientesFallas = d.fallasPorEstado
        .where((i) => i.etiqueta == 'Pendiente')
        .fold<double>(0, (s, i) => s + i.valor)
        .toInt();

    return [
      _titulo(_Seccion.resumen, 'Las cifras más importantes de la plataforma.'),
      _CuadriculaKpi(
        tarjetas: [
          KpiTile(
            titulo: 'Usuarios registrados',
            valor: r.usuarios,
            icono: Icons.groups_rounded,
            color: AppColors.primary,
            detalle: '+${r.nuevosEsteMes} este mes',
          ),
          KpiTile(
            titulo: 'Predicciones realizadas',
            valor: r.predicciones,
            icono: Icons.auto_graph_rounded,
            color: ColoresPanel.violeta,
            detalle: d.confianzaPromedio == null
                ? 'Modelos por estrato'
                : 'Confianza ${_porcentajeConfianza(d.confianzaPromedio!)}',
          ),
          KpiTile(
            titulo: 'Recibos escaneados',
            valor: r.recibos,
            icono: Icons.document_scanner_outlined,
            color: AppColors.green,
            detalle: '${d.recibosPagados} pagados',
          ),
          KpiTile(
            titulo: 'Análisis de consumo',
            valor: r.analisis,
            icono: Icons.insights_rounded,
            color: const Color(0xFFE08A00),
            detalle: '${d.analisisIrregulares} irregulares',
          ),
          KpiTile(
            titulo: 'Reportes de fallas',
            valor: r.fallas,
            icono: Icons.report_gmailerrorred_rounded,
            color: AppColors.red,
            detalle: '$pendientesFallas pendientes',
          ),
          KpiTile(
            titulo: 'Consejos publicados',
            valor: r.consejos,
            icono: Icons.tips_and_updates_outlined,
            color: ColoresPanel.teal,
            detalle:
                '${formatearNumero(r.consumosRegistrados.toDouble())} consumos en la web',
          ),
        ],
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Actividad de los últimos 6 meses',
        subtitulo: 'Toca una serie para ocultarla o mostrarla',
        icono: Icons.show_chart_rounded,
        child: ActividadChart(meses: d.actividadMensual),
      ),
    ];
  }

  // --------------------------------------------------------- Usuarios

  List<Widget> _seccionUsuarios(Estadisticas d) {
    final r = d.resumen;
    final porcentajePredio = r.usuarios == 0
        ? 0.0
        : r.usuariosConPredio * 100 / r.usuarios;

    // Siempre los 6 estratos, aunque alguno esté en cero
    final estratos = [
      for (var e = 1; e <= 6; e++)
        ItemConteo(
          '$e',
          d.usuariosPorEstrato
              .where((i) => i.etiqueta == '$e')
              .fold<double>(0, (s, i) => s + i.valor),
        ),
    ];

    return [
      _titulo(
        _Seccion.usuarios,
        'Cómo están compuestas las cuentas, sin datos personales.',
      ),
      TarjetaPanel(
        titulo: 'Estado de las cuentas',
        subtitulo: '${r.administradores} administradores aparte',
        icono: Icons.verified_user_outlined,
        child: Column(
          children: [
            DonaChart(
              etiquetaCentro: 'usuarios',
              items: [
                ItemConteo('Activos', r.usuariosActivos.toDouble()),
                ItemConteo('Inhabilitados', r.usuariosInhabilitados.toDouble()),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              children: [
                AnilloPorcentaje(
                  porcentaje: porcentajePredio,
                  color: AppColors.green,
                  etiqueta: 'Con predio',
                  tamano: 78,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    '${r.usuariosConPredio} de ${r.usuarios} usuarios ya registraron '
                    'su vivienda (barrio, estrato y tipo de predio).',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Usuarios por estrato',
        subtitulo: 'Según el predio registrado',
        icono: Icons.stacked_bar_chart_rounded,
        child: BarrasVerticales(items: estratos, etiqueta: (e) => 'Est. $e'),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Tipo de vivienda',
        icono: Icons.home_work_outlined,
        color: AppColors.green,
        child: DonaChart(
          items: d.usuariosPorTipoPredio,
          etiquetaCentro: 'predios',
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Barrios con más usuarios',
        subtitulo: 'Top 5 de Cartagena',
        icono: Icons.location_on_outlined,
        color: ColoresPanel.teal,
        child: BarrasHorizontales(
          items: d.topBarrios,
          colorUnico: ColoresPanel.teal,
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Servicios registrados',
        subtitulo: 'Servicios del hogar que los usuarios agregaron',
        icono: Icons.home_repair_service_outlined,
        color: AppColors.orange,
        child: BarrasHorizontales(items: d.serviciosRegistrados),
      ),
    ];
  }

  // ---------------------------------------------------------- Consumo

  List<Widget> _seccionConsumo(Estadisticas d) {
    return [
      _titulo(
        _Seccion.consumo,
        'Análisis de consumo y predicciones de los usuarios.',
      ),
      TarjetaPanel(
        titulo: 'Nivel de consumo analizado',
        subtitulo: 'Comparado con el promedio de su estrato',
        icono: Icons.speed_rounded,
        color: const Color(0xFFE08A00),
        child: Column(
          children: [
            DonaChart(
              items: d.analisisPorCategoria,
              etiquetaCentro: 'análisis',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              children: [
                AnilloPorcentaje(
                  porcentaje: d.porcentajeIrregular,
                  color: AppColors.red,
                  etiqueta: 'Irregulares',
                  tamano: 78,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    '${d.analisisIrregulares} análisis detectaron un consumo '
                    'irregular (muy por encima o por debajo de lo esperado).',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Análisis por servicio',
        icono: Icons.analytics_outlined,
        child: BarrasHorizontales(items: d.analisisPorServicio),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Predicciones por servicio',
        subtitulo: d.confianzaPromedio == null
            ? 'Consumo estimado con los modelos por estrato'
            : 'Confianza promedio: ${_porcentajeConfianza(d.confianzaPromedio!)}',
        icono: Icons.auto_graph_rounded,
        color: ColoresPanel.violeta,
        child: BarrasHorizontales(items: d.prediccionesPorServicio),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Nivel previsto en las predicciones',
        icono: Icons.donut_large_rounded,
        color: ColoresPanel.violeta,
        child: DonaChart(
          items: d.prediccionesPorNivel,
          etiquetaCentro: 'predicciones',
        ),
      ),
    ];
  }

  // ---------------------------------------------------------- Recibos

  List<Widget> _seccionRecibos(Estadisticas d) {
    final alDia = math.max(0, d.recibosPendientes - d.recibosVencidos);

    return [
      _titulo(_Seccion.recibos, 'Recibos escaneados con la cámara de la app.'),
      TarjetaPanel(
        titulo: 'Estado de pago',
        icono: Icons.payments_outlined,
        color: AppColors.green,
        child: DonaChart(
          etiquetaCentro: 'recibos',
          items: [
            ItemConteo('Pagados', d.recibosPagados.toDouble()),
            ItemConteo('Pendientes', alDia.toDouble()),
            ItemConteo('Vencidos', d.recibosVencidos.toDouble()),
          ],
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Valor total facturado',
        subtitulo: 'Suma de todos los recibos escaneados',
        icono: Icons.account_balance_wallet_outlined,
        color: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: NumeroAnimado(
                valor: d.valorFacturado.toDouble(),
                estilo: estiloTitulo(30, color: AppColors.primary),
                formato: (v) => formatearPesos(v.round()),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Valor promedio por recibo',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            BarrasHorizontales(
              items: d.valorPromedioPorServicio,
              formatoValor: (i) => formatearPesos(i.valor.round()),
            ),
          ],
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Recibos por servicio',
        icono: Icons.receipt_long_rounded,
        child: BarrasHorizontales(items: d.recibosPorServicio),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Consumo promedio por recibo',
        subtitulo: 'Cada servicio en su propia unidad',
        icono: Icons.water_drop_outlined,
        color: AppColors.sky,
        child: d.consumoPromedioPorServicio.isEmpty
            ? const SinDatos()
            : Row(
                children: [
                  for (
                    var i = 0;
                    i < d.consumoPromedioPorServicio.length;
                    i++
                  ) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _ConsumoServicio(
                        item: d.consumoPromedioPorServicio[i],
                        indice: i,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ];
  }

  // --------------------------------------------------------- Reportes

  List<Widget> _seccionReportes(Estadisticas d) {
    return [
      _titulo(
        _Seccion.reportes,
        'Fallas reportadas por los usuarios y cortes programados.',
      ),
      TarjetaPanel(
        titulo: 'Fallas por estado',
        icono: Icons.report_gmailerrorred_rounded,
        color: AppColors.red,
        child: BarrasHorizontales(items: d.fallasPorEstado),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Fallas por servicio',
        icono: Icons.build_circle_outlined,
        color: AppColors.orange,
        child: DonaChart(
          items: d.fallasPorServicio,
          etiquetaCentro: 'reportes',
        ),
      ),
      _espacio,
      TarjetaPanel(
        titulo: 'Cortes programados',
        icono: Icons.power_off_outlined,
        color: AppColors.textSecondary,
        child: Row(
          children: [
            Expanded(
              child: _MiniCifra(
                valor: d.cortesActivos,
                etiqueta: 'Vigentes ahora',
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniCifra(
                valor: d.cortesTotal,
                etiqueta: 'Registrados en total',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Spring guarda la confianza como 0–1 o como porcentaje.
  static String _porcentajeConfianza(double valor) {
    final porcentaje = valor <= 1 ? valor * 100 : valor;
    return '${porcentaje.round()}%';
  }
}

// =====================================================================
// Piezas del panel
// =====================================================================

/// KPIs en dos columnas, cada fila con la altura de su tarjeta más alta.
class _CuadriculaKpi extends StatelessWidget {
  final List<Widget> tarjetas;

  const _CuadriculaKpi({required this.tarjetas});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tarjetas.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tarjetas[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < tarjetas.length
                      ? tarjetas[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "En vivo · hace 4 s" con un punto que late. Naranja si no hay conexión.
class _IndicadorEnVivo extends StatelessWidget {
  final ValueNotifier<double> tiempo;
  final DateTime? actualizado;
  final bool sinConexion;

  const _IndicadorEnVivo({
    required this.tiempo,
    required this.actualizado,
    required this.sinConexion,
  });

  String _hace() {
    final fecha = actualizado;
    if (fecha == null) return 'conectando…';
    final segundos = DateTime.now().difference(fecha).inSeconds;
    if (segundos < 5) return 'actualizado ahora';
    if (segundos < 60) return 'hace $segundos s';
    return 'hace ${segundos ~/ 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final color = sinConexion ? AppColors.orange : const Color(0xFF7CF29C);
    return ValueListenableBuilder<double>(
      valueListenable: tiempo,
      builder: (context, t, _) {
        final latido = (math.sin(t * 4) + 1) / 2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35 + 0.45 * latido),
                      blurRadius: 4 + 6 * latido,
                      spreadRadius: 1 + 2 * latido,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sinConexion
                      ? 'Reconectando · ${_hace()}'
                      : 'En vivo · ${_hace()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      },
    );
  }
}

/// Píldora translúcida sobre el encabezado (insignia o botón).
class _PildoraBlanca extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? tooltip;
  final VoidCallback? onTap;

  const _PildoraBlanca({
    required this.icono,
    required this.texto,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? contenido
          : Tooltip(
              message: tooltip ?? texto,
              child: InkWell(onTap: onTap, child: contenido),
            ),
    );
  }
}

/// Consumo promedio de un servicio, con su icono y unidad.
/// 245.37 -> "245,4"; 15.0 -> "15".
String _unDecimal(double v) {
  final redondeado = (v * 10).round() / 10;
  return redondeado == redondeado.roundToDouble()
      ? formatearNumero(redondeado)
      : redondeado.toStringAsFixed(1).replaceAll('.', ',');
}

class _ConsumoServicio extends StatelessWidget {
  final ItemConteo item;
  final int indice;

  const _ConsumoServicio({required this.item, required this.indice});

  @override
  Widget build(BuildContext context) {
    final color = ColoresPanel.de(item.etiqueta, indice);
    final empresa = Empresa.values
        .where((e) => e.servicio == item.etiqueta)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(
            empresa?.icono ?? Icons.bubble_chart_outlined,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: NumeroAnimado(
              valor: item.valor,
              estilo: estiloTitulo(18, color: color),
              formato: _unDecimal,
            ),
          ),
          Text(
            item.unidad ?? empresa?.unidad ?? '',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.etiqueta,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniCifra extends StatelessWidget {
  final int valor;
  final String etiqueta;
  final Color color;

  const _MiniCifra({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NumeroAnimado(
            valor: valor.toDouble(),
            estilo: estiloTitulo(24, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 46,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}
