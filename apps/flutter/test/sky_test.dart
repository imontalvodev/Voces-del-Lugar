import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/ui/sky.dart';

void main() {
  testWidgets('el cielo anima mientras está a la vista', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Sky()));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('el cielo para de repintar cuando algo lo tapa', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Sky(animating: false)));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('el cielo retoma la animación al volver a verse', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Sky(animating: false)));
    await tester.pumpWidget(const MaterialApp(home: Sky()));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });
}
