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
