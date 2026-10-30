import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/theme/letra.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('los tres tamaños del diseño', () {
    expect(TamanoLetra.values.map((t) => t.escala), [1.0, 1.2, 1.4]);
    expect(TamanoLetra.values.map((t) => t.nombre), ['Normal', 'Grande', 'Muy grande']);
  });

  test('sin nada guardado la letra es normal', () async {
    final letra = await PreferenciaLetra.cargar();
    expect(letra.value, TamanoLetra.normal);
  });

  test('el tamaño elegido se guarda y se recupera al volver a abrir', () async {
    final letra = await PreferenciaLetra.cargar();
    await letra.elegir(TamanoLetra.muyGrande);
    expect(letra.value, TamanoLetra.muyGrande);

    final otraVez = await PreferenciaLetra.cargar();
    expect(otraVez.value, TamanoLetra.muyGrande);
  });

  test('un valor guardado que ya no existe vuelve a normal', () async {
    SharedPreferences.setMockInitialValues({'tamano_letra': 'gigante'});
    final letra = await PreferenciaLetra.cargar();
    expect(letra.value, TamanoLetra.normal);
  });

  testWidgets('el ajuste propio se multiplica por el tamaño del sistema', (tester) async {
    final letra = PreferenciaLetra(TamanoLetra.grande);
    late double escala;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: EscalaLetra(
          preferencia: letra,
          child: Builder(
            builder: (context) {
              escala = MediaQuery.textScalerOf(context).scale(10) / 10;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(escala, closeTo(1.8, 0.0001));

    await letra.elegir(TamanoLetra.muyGrande);
    await tester.pump();
    expect(escala, closeTo(2.1, 0.0001));
  });

  testWidgets('las pantallas leen y cambian el ajuste desde el árbol', (tester) async {
    final letra = PreferenciaLetra(TamanoLetra.normal);
    await tester.pumpWidget(
      EscalaLetra(
        preferencia: letra,
        child: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () => PreferenciaLetra.of(context).elegir(TamanoLetra.grande),
              child: Text(PreferenciaLetra.of(context).value.nombre, textDirection: TextDirection.ltr),
            );
          },
        ),
      ),
    );
    expect(find.text('Normal'), findsOneWidget);
    await tester.tap(find.text('Normal'));
    await tester.pump();
    expect(find.text('Grande'), findsOneWidget);
  });
}
