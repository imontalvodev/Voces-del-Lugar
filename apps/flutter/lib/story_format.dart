import 'package:latlong2/latlong.dart';

String coordinateLabel(LatLng point) {
  final lat = point.latitude.abs().toStringAsFixed(4);
  final lon = point.longitude.abs().toStringAsFixed(4);
  final ns = point.latitude >= 0 ? 'N' : 'S';
  final ew = point.longitude >= 0 ? 'E' : 'O';
  return '$lat° $ns, $lon° $ew';
}

String storyStatusLabel(String status) {
  return switch (status) {
    'published' => 'Publicada',
    'pending_review' => 'En revisión',
    'rejected' => 'Rechazada',
    'draft' => 'Borrador',
    _ => status,
  };
}

String roleLabel(String role) {
  return switch (role) {
    'admin' => 'Administra el archivo y puede publicar.',
    'curator' => 'Modera las historias antes de publicarlas.',
    'contributor' => 'Puede dejar historias. Alguien las publica.',
    _ => role,
  };
}

/// Las categorías que acepta la API, en el orden en que se ofrecen.
const storyCategories = ['anecdota', 'leyenda', 'oficio', 'tradicion', 'evento', 'otro'];

String categoryLabel(String category) {
  return switch (category) {
    'anecdota' => 'Anécdota',
    'leyenda' => 'Leyenda',
    'oficio' => 'Oficio',
    'tradicion' => 'Tradición',
    'evento' => 'Evento',
    'otro' => 'Otro',
    _ => category,
  };
}

String licenseLabel(String license) {
  return switch (license) {
    'CC-BY-SA-4.0' => 'CC BY-SA 4.0',
    'CC-BY-4.0' => 'CC BY 4.0',
    'CC0-1.0' => 'CC0',
    _ => license,
  };
}

String excerpt(String? body, {int max = 180}) {
  if (body == null) return '';
  final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';
  if (flat.length <= max) return flat;
  return '${flat.substring(0, max - 1)}…';
}

/// Cuándo pasó, como lo diría quien lo cuenta: «Años 50». Fuera de los años 20
/// a 90 la forma corta confunde, así que se nombra la década entera.
String? decadeLabel(int? year) {
  if (year == null) return null;
  final decade = year - year % 10;
  if (decade >= 1920 && decade <= 1990) return 'Años ${decade % 100}';
  return 'Década de $decade';
}

/// «Nº 0142»: el número de ficha con al menos cuatro cifras.
String numeroFicha(int numero) => 'Nº ${numero.toString().padLeft(4, '0')}';

/// Quién la cuenta, como lo escribe la ficha: «Carmen Ruiz, abuela»,
/// «Un vecino (sin nombre)» o «una persona anónima», más «(fallecido)».
String contadaPor(String? name, String? relation, {required bool deceased}) {
  final nombre = name?.trim() ?? '';
  final parentesco = relation?.trim() ?? '';
  final base = nombre.isNotEmpty
      ? (parentesco.isEmpty ? nombre : '$nombre, $parentesco')
      : parentesco.isNotEmpty
      ? '${parentesco[0].toUpperCase()}${parentesco.substring(1)} (sin nombre)'
      : 'una persona anónima';
  return deceased ? '$base (fallecido)' : base;
}

/// Duración de un audio como «4:12».
String? duracionCorta(int? segundos) {
  if (segundos == null) return null;
  return '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
}

/// La licencia explicada en lenguaje llano, como en el paso «Permiso».
({String nombre, String detalle}) licenciaLlana(String license) {
  return switch (license) {
    'CC-BY-4.0' => (
      nombre: 'Citando la fuente',
      detalle: 'Cualquiera puede usarla para lo que quiera, siempre que diga de dónde la sacó.',
    ),
    'CC0-1.0' => (
      nombre: 'Dominio público',
      detalle: 'Cualquiera puede usarla sin pedir permiso ni citar. Es como regalarla a todos.',
    ),
    _ => (
      nombre: 'Compartir igual',
      detalle: 'Cualquiera puede usarla y adaptarla si cita la fuente y la comparte con esta misma licencia.',
    ),
  };
}
