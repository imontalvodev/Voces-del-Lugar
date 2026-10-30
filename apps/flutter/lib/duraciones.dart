import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lo que dura cada audio, medido en este dispositivo: al grabarlo o al
/// abrirlo en el reproductor. La API no lo calcula; con esto las fichas
/// dicen «Audio · 3:12» en vez de solo «Audio» una vez escuchado aquí.
class Duraciones {
  Duraciones._();

  static const _clave = 'duraciones_audio';
  static const _maximo = 500;

  static final Map<String, int> _segundos = {};

  static int? de(String url) => _segundos[url];

  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardadas = prefs.getString(_clave);
      if (guardadas == null) return;
      _segundos.addAll((jsonDecode(guardadas) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)));
    } catch (_) {}
  }

  static Future<void> guardar(String url, Duration duracion) async {
    final segundos = (duracion.inMilliseconds / 1000).round();
    if (segundos <= 0 || _segundos[url] == segundos) return;
    _segundos.remove(url);
    _segundos[url] = segundos;
    // Las más viejas salen primero: el mapa conserva el orden de entrada.
    while (_segundos.length > _maximo) {
      _segundos.remove(_segundos.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode(_segundos));
    } catch (_) {}
  }

  /// Solo para pruebas: vacía lo cargado en memoria.
  static void olvidar() => _segundos.clear();
}
