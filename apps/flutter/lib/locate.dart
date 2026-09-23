import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

Future<LatLng?> resolveLocation({
  required Future<String> Function() permission,
  required Future<String> Function() request,
  required Future<LatLng?> Function() read,
}) async {
  var status = await permission();
  if (status == 'denied') status = await request();
  if (status == 'denied' || status == 'deniedForever') return null;
  return read();
}

Future<LatLng?> deviceLocation() {
  return resolveLocation(
    permission: () async => (await Geolocator.checkPermission()).name,
    request: () async => (await Geolocator.requestPermission()).name,
    read: () async {
      try {
        final position = await Geolocator.getCurrentPosition();
        return LatLng(position.latitude, position.longitude);
      } on LocationServiceDisabledException {
        return null;
      }
    },
  );
}
