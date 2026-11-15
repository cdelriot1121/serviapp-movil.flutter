/// Estadísticas globales de ServiApp que Spring Boot calcula para el panel
/// de administradores. Solo cifras agregadas: ningún dato personal.
class Estadisticas {
  final DateTime generadoEn;
  final Resumen resumen;

  // Usuarios
  final List<ItemConteo> usuariosPorEstrato;
  final List<ItemConteo> usuariosPorTipoPredio;
  final List<ItemConteo> topBarrios;
  final List<ItemConteo> serviciosRegistrados;

  /// Últimos 6 meses, del más antiguo al actual.
  final List<ActividadMes> actividadMensual;

  // Recibos escaneados
  final List<ItemConteo> recibosPorServicio;
  final int recibosPagados;
  final int recibosPendientes;
  final int recibosVencidos;
  final int valorFacturado;
  final List<ItemConteo> valorPromedioPorServicio;
  final List<ItemConteo> consumoPromedioPorServicio;

  // Análisis de consumo
  final List<ItemConteo> analisisPorCategoria;
  final List<ItemConteo> analisisPorServicio;
  final int analisisIrregulares;
  final double porcentajeIrregular;

  // Predicciones
  final List<ItemConteo> prediccionesPorServicio;
  final List<ItemConteo> prediccionesPorNivel;
  final double? confianzaPromedio;

  // Reportes de fallas y cortes
  final List<ItemConteo> fallasPorEstado;
  final List<ItemConteo> fallasPorServicio;
  final int cortesTotal;
  final int cortesActivos;

  const Estadisticas({
    required this.generadoEn,
    required this.resumen,
    required this.usuariosPorEstrato,
    required this.usuariosPorTipoPredio,
    required this.topBarrios,
    required this.serviciosRegistrados,
    required this.actividadMensual,
    required this.recibosPorServicio,
    required this.recibosPagados,
    required this.recibosPendientes,
    required this.recibosVencidos,
    required this.valorFacturado,
    required this.valorPromedioPorServicio,
    required this.consumoPromedioPorServicio,
    required this.analisisPorCategoria,
    required this.analisisPorServicio,
    required this.analisisIrregulares,
    required this.porcentajeIrregular,
    required this.prediccionesPorServicio,
    required this.prediccionesPorNivel,
    required this.confianzaPromedio,
    required this.fallasPorEstado,
    required this.fallasPorServicio,
    required this.cortesTotal,
    required this.cortesActivos,
  });

  factory Estadisticas.fromJson(Map<String, dynamic> json) {
    final usuarios = _mapa(json['usuarios']);
    final recibos = _mapa(json['recibos']);
    final analisis = _mapa(json['analisis']);
    final predicciones = _mapa(json['predicciones']);
    final fallas = _mapa(json['fallas']);
    final cortes = _mapa(json['cortes']);

    return Estadisticas(
      generadoEn:
          DateTime.tryParse(json['generadoEn']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      resumen: Resumen.fromJson(_mapa(json['resumen'])),
      usuariosPorEstrato: ItemConteo.lista(usuarios['porEstrato']),
      usuariosPorTipoPredio: ItemConteo.lista(usuarios['porTipoPredio']),
      topBarrios: ItemConteo.lista(usuarios['topBarrios']),
      serviciosRegistrados: ItemConteo.lista(usuarios['serviciosRegistrados']),
      actividadMensual: [
        for (final fila in (json['actividadMensual'] as List? ?? const []))
          if (fila is Map)
            ActividadMes.fromJson(Map<String, dynamic>.from(fila)),
      ],
      recibosPorServicio: ItemConteo.lista(recibos['porServicio']),
      recibosPagados: _entero(recibos['pagados']),
      recibosPendientes: _entero(recibos['pendientes']),
      recibosVencidos: _entero(recibos['vencidos']),
      valorFacturado: _entero(recibos['valorFacturado']),
      valorPromedioPorServicio: ItemConteo.lista(
        recibos['valorPromedioPorServicio'],
      ),
      consumoPromedioPorServicio: ItemConteo.lista(
        recibos['consumoPromedioPorServicio'],
      ),
      analisisPorCategoria: ItemConteo.lista(analisis['porCategoria']),
      analisisPorServicio: ItemConteo.lista(analisis['porServicio']),
      analisisIrregulares: _entero(analisis['irregulares']),
      porcentajeIrregular:
          (analisis['porcentajeIrregular'] as num?)?.toDouble() ?? 0,
      prediccionesPorServicio: ItemConteo.lista(predicciones['porServicio']),
      prediccionesPorNivel: ItemConteo.lista(predicciones['porNivel']),
      confianzaPromedio: (predicciones['confianzaPromedio'] as num?)
          ?.toDouble(),
      fallasPorEstado: ItemConteo.lista(fallas['porEstado']),
      fallasPorServicio: ItemConteo.lista(fallas['porServicio']),
      cortesTotal: _entero(cortes['total']),
      cortesActivos: _entero(cortes['activos']),
    );
  }
}

/// Cifras principales que van en las tarjetas del panel.
class Resumen {
  final int usuarios;
  final int administradores;
  final int usuariosActivos;
  final int usuariosInhabilitados;
  final int usuariosConPredio;
  final int nuevosEsteMes;
  final int recibos;
  final int analisis;
  final int predicciones;
  final int fallas;
  final int consejos;
  final int consumosRegistrados;

  const Resumen({
    required this.usuarios,
    required this.administradores,
    required this.usuariosActivos,
    required this.usuariosInhabilitados,
    required this.usuariosConPredio,
    required this.nuevosEsteMes,
    required this.recibos,
    required this.analisis,
    required this.predicciones,
    required this.fallas,
    required this.consejos,
    required this.consumosRegistrados,
  });

  factory Resumen.fromJson(Map<String, dynamic> json) => Resumen(
    usuarios: _entero(json['usuarios']),
    administradores: _entero(json['administradores']),
    usuariosActivos: _entero(json['usuariosActivos']),
    usuariosInhabilitados: _entero(json['usuariosInhabilitados']),
    usuariosConPredio: _entero(json['usuariosConPredio']),
    nuevosEsteMes: _entero(json['nuevosEsteMes']),
    recibos: _entero(json['recibos']),
    analisis: _entero(json['analisis']),
    predicciones: _entero(json['predicciones']),
    fallas: _entero(json['fallas']),
    consejos: _entero(json['consejos']),
    consumosRegistrados: _entero(json['consumosRegistrados']),
  );
}

/// Una barra o porción de gráfica: "Energía" -> 12.
class ItemConteo {
  final String etiqueta;
  final double valor;
  final String? unidad;

  const ItemConteo(this.etiqueta, this.valor, {this.unidad});

  static List<ItemConteo> lista(dynamic datos) => [
    for (final item in (datos as List? ?? const []))
      if (item is Map)
        ItemConteo(
          item['etiqueta']?.toString() ?? '—',
          (item['valor'] as num?)?.toDouble() ?? 0,
          unidad: item['unidad']?.toString(),
        ),
  ];
}

/// Actividad de un mes (periodo YYYY-MM).
class ActividadMes {
  final String periodo;
  final int registros;
  final int recibos;
  final int analisis;
  final int predicciones;

  const ActividadMes({
    required this.periodo,
    required this.registros,
    required this.recibos,
    required this.analisis,
    required this.predicciones,
  });

  factory ActividadMes.fromJson(Map<String, dynamic> json) => ActividadMes(
    periodo: json['periodo']?.toString() ?? '',
    registros: _entero(json['registros']),
    recibos: _entero(json['recibos']),
    analisis: _entero(json['analisis']),
    predicciones: _entero(json['predicciones']),
  );
}

Map<String, dynamic> _mapa(dynamic datos) =>
    datos is Map ? Map<String, dynamic>.from(datos) : const {};

int _entero(dynamic valor) => (valor as num?)?.toInt() ?? 0;
