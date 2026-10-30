import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/ui/teselas.dart';

import 'ayuda.dart';

void main() {
  testWidgets('teselas de OpenStreetMap con la matriz clara o la oscura', (tester) async {
    late TileLayer clara;
    late TileLayer oscura;
    await montar(
      tester,
      Builder(
        builder: (context) {
          clara = teselasVdl(context);
          return const SizedBox();
        },
      ),
    );
    await montar(
      tester,
      Builder(
        builder: (context) {
          oscura = teselasVdl(context);
          return const SizedBox();
        },
      ),
      oscuro: true,
    );
    expect(clara.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(oscura.urlTemplate, clara.urlTemplate);
    expect(filtroTeselas(Brightness.light), filtroClaro);
    expect(filtroTeselas(Brightness.dark), filtroOscuro);
  });

  test('las matrices son las del handoff', () {
    expect(
      filtroClaro,
      const ColorFilter.matrix(<double>[
        0.170,
        0.572,
        0.058,
        0,
        43,
        0.174,
        0.587,
        0.059,
        0,
        41,
        0.166,
        0.558,
        0.056,
        0,
        56,
        0,
        0,
        0,
        1,
        0,
      ]),
    );
    expect(
      filtroOscuro,
      const ColorFilter.matrix(<double>[
        -0.149,
        -0.501,
        -0.051,
        0,
        204,
        -0.145,
        -0.486,
        -0.049,
        0,
        206,
        -0.132,
        -0.444,
        -0.045,
        0,
        222,
        0,
        0,
        0,
        1,
        0,
      ]),
    );
  });

  testWidgets('la atribución se ve siempre', (tester) async {
    await montar(tester, const SizedBox(width: 300, height: 200, child: Stack(children: [AtribucionOsm()])));
    expect(find.text('© colaboradores de OpenStreetMap'), findsOneWidget);
  });
}
