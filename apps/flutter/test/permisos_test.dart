import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/permisos.dart';

const _canal = MethodChannel('flutter.baseflow.com/permissions/methods');
const _micro = 7;
const _avisos = 17;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> pedidos;

  setUp(() {
    pedidos = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_canal, (llamada) async {
      if (llamada.method == 'requestPermissions') {
        final lista = (llamada.arguments as List).cast<int>();
        pedidos.addAll(lista);
        return {for (final p in lista) p: 1}; // 1 = concedido
      }
      if (llamada.method == 'checkPermissionStatus') return 0; // 0 = sin decidir
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_canal, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('en Android, con el micrófono también pide los avisos para la notificación de grabar', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final estado = await pedirMicro();
    expect(estado, EstadoPermiso.concedido);
    expect(pedidos, [_micro, _avisos]);
  });

  test('en iOS solo pide el micrófono', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pedirMicro();
    expect(pedidos, [_micro]);
  });
}
