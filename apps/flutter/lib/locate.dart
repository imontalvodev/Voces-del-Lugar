import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Decide si se puede leer la posición sin molestar: con [ask] a false no se
/// pide permiso, solo se usa si ya estaba concedido.
Future<LatLng?> resolveLocation({
  required Future<String> Function() permission,
  required Future<String> Function() request,
  required Future<LatLng?> Function() read,
  bool ask = true,
}) async {
  var status = await permission();
  if (status == 'denied' && ask) status = await request();
  if (status == 'denied' || status == 'deniedForever' || status == 'unableToDetermine') return null;
  return read();
}

/// Dónde está el dispositivo, o null si no se puede saber. En web fuera de
/// HTTPS el navegador no la da: entonces también es null.
Future<LatLng?> deviceLocation({bool ask = true}) async {
  try {
    return await resolveLocation(
      ask: ask,
      permission: () async => (await Geolocator.checkPermission()).name,
      request: () async => (await Geolocator.requestPermission()).name,
      read: () async {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)),
        );
        return LatLng(position.latitude, position.longitude);
      },
    );
  } catch (_) {
    return null;
  }
}
