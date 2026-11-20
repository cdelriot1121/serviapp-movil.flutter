import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import 'pronostico.dart';

/// Clima de Cartagena desde Open-Meteo.
///
/// La respuesta se guarda 30 minutos en el celular: el pronóstico no cambia
/// más rápido y así cada apertura de la app no gasta una llamada.
class ClimaService {
  ClimaService._();

  static final _prefs = SharedPreferencesAsync();
  static const _claveRespuesta = 'clima_respuesta';
  static const _claveGuardado = 'clima_guardado';
  static const _claveAlerta = 'clima_alerta_fecha';
  static const _vigencia = Duration(minutes: 30);

  /// Último pronóstico conocido (null mientras carga o si no hay internet).
  static final pronostico = ValueNotifier<Pronostico?>(null);

  static const _parametros = {
    'latitude': 10.391,
    'longitude': -75.4794,
    'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
        'weather_code,is_day',
    'hourly': 'temperature_2m,precipitation_probability,weather_code,is_day',
    'daily': 'temperature_2m_max,temperature_2m_min,apparent_temperature_max,'
        'precipitation_probability_max,precipitation_sum',
    'timezone': 'America/Bogota',
    // Dos días para tener siempre 24 horas por delante
    'forecast_days': 2,
  };

  static Future<Pronostico?> cargar() async {
    final guardado = await _leerGuardado();
    // El de anoche no sirve para hoy aunque tenga menos de 30 minutos
    if (guardado != null &&
        !guardado.vencido &&
        _esHoy(guardado.pronostico.hoy.fecha)) {
      return pronostico.value = guardado.pronostico;
    }

    try {
      final res = await ApiClient.clima.get<Map<String, dynamic>>(
        '/forecast',
        queryParameters: _parametros,
      );
      final json = res.data!;
      final nuevo = Pronostico.fromJson(json);
      await _prefs.setString(_claveRespuesta, jsonEncode(json));
      await _prefs.setInt(_claveGuardado, DateTime.now().millisecondsSinceEpoch);
      return pronostico.value = nuevo;
    } catch (_) {
      // Sin internet: sirve el guardado mientras sea de hoy
      final deHoy = guardado != null && _esHoy(guardado.pronostico.hoy.fecha);
      return pronostico.value = deHoy ? guardado.pronostico : null;
    }
  }

  /// La alerta del clima sale solo la primera vez que se abre la app en el día.
  static Future<bool> tocaAlertaHoy() async =>
      await _prefs.getString(_claveAlerta) != _hoy();

  static Future<void> marcarAlertaVista() => _prefs.setString(_claveAlerta, _hoy());

  static Future<({Pronostico pronostico, bool vencido})?> _leerGuardado() async {
    try {
      final texto = await _prefs.getString(_claveRespuesta);
      final guardado = await _prefs.getInt(_claveGuardado);
      if (texto == null || guardado == null) return null;
      final edad = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(guardado),
      );
      return (
        pronostico: Pronostico.fromJson(jsonDecode(texto) as Map<String, dynamic>),
        vencido: edad > _vigencia,
      );
    } catch (_) {
      return null;
    }
  }

  static String _hoy() {
    final h = DateTime.now();
    return '${h.year}-${h.month}-${h.day}';
  }

  static bool _esHoy(DateTime fecha) {
    final h = DateTime.now();
    return fecha.year == h.year && fecha.month == h.month && fecha.day == h.day;
  }
}
