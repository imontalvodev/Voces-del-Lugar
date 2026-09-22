import 'package:flutter_test/flutter_test.dart';
import 'package:voces/api.dart';

void main() {
  test('la API local es el valor por defecto', () {
    expect(apiBase, 'http://localhost:8001');
  });
}
