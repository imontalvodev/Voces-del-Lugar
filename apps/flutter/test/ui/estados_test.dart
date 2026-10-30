import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/placa.dart';

import 'ayuda.dart';

void main() {
  testWidgets('cargando: texto con reloj de arena y bloques fijos, sin animación', (tester) async {
    await montar(tester, const SizedBox(width: 400, child: Cargando()));
    expect(find.text('Cargando historias…'), findsOneWidget);
    expect(find.byIcon(LucideIcons.hourglass), findsOneWidget);
    expect(find.byKey(const Key('bloque-carga')), findsNWidgets(3));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('cargando dice lo que carga y cuántos bloques', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, const SizedBox(width: 400, child: Cargando(texto: 'Buscando lugares…', bloques: 1)));
    expect(find.text('Buscando lugares…'), findsOneWidget);
    expect(find.byKey(const Key('bloque-carga')), findsOneWidget);
    expect(tester.getSemantics(find.text('Buscando lugares…')), isSemantics(isLiveRegion: true));
    semantica.dispose();
  });

  testWidgets('el vacío siempre ofrece algo que hacer', (tester) async {
    var contar = 0;
    await montar(
      tester,
      SizedBox(
        width: 400,
        child: Vacio(
          titulo: 'Aquí todavía no hay historias',
          texto: '¿Pasó algo aquí que merezca recordarse?',
          accion: BotonPlaca(
            etiqueta: 'Contar la historia de este sitio',
            tamano: TamanoBoton.medio,
            icono: LucideIcons.mic,
            onPressed: () => contar++,
          ),
        ),
      ),
    );
    expect(find.text('Aquí todavía no hay historias'), findsOneWidget);
    expect(find.text('¿Pasó algo aquí que merezca recordarse?'), findsOneWidget);
    await tester.tap(find.text('Contar la historia de este sitio'));
    expect(contar, 1);
  });
}
