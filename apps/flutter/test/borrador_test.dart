import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/borrador.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el borrador se guarda y vuelve como estaba', () async {
    final b = Borrador(lat: 41.8, lng: -2.4, sitio: 'La fuente', titulo: 'El hielo', tipo: 'anecdota', paso: 3);
    await b.guardar();
    final otra = await Borrador.cargar();
    expect(otra!.sitio, 'La fuente');
    expect(otra.titulo, 'El hielo');
    expect(otra.tipo, 'anecdota');
    expect(otra.paso, 3);
    expect(otra.lat, 41.8);
  });

  test('un borrador vacío o borrado no se recupera', () async {
    await Borrador().guardar();
    expect(await Borrador.cargar(), isNull);
    await Borrador(sitio: 'algo').guardar();
    await Borrador.borrar();
    expect(await Borrador.cargar(), isNull);
  });

  test('la época se entiende como la dice la gente', () {
    expect(decadaDeEpoca('Años 50'), 1950);
    expect(decadaDeEpoca('años 60'), 1960);
    expect(decadaDeEpoca('Década de 1920'), 1920);
    expect(decadaDeEpoca('en 1958, en invierno'), 1958);
    expect(decadaDeEpoca("en el 68"), 1968);
    expect(decadaDeEpoca('cuando la guerra'), isNull);
    expect(decadaDeEpoca(''), isNull);
  });
}
