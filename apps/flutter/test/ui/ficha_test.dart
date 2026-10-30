import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/ficha.dart';
import 'package:voces/ui/sello.dart';

import 'ayuda.dart';

FichaHistoria _ficha({
  int? numero = 142,
  String? audio = '4:12',
  EstadoSello? sello,
  bool compacta = false,
  VoidCallback? onTap,
}) {
  return FichaHistoria(
    numero: numero,
    titulo: 'La noche que se heló la fuente',
    lugar: 'Plaza Mayor',
    categoria: 'anecdota',
    epoca: 'Años 50',
    contadaPor: 'Carmen Ruiz, abuela',
    duracionAudio: audio,
    sello: sello,
    compacta: compacta,
    onTap: onTap ?? () {},
  );
}

void main() {
  group('textos de la ficha', () {
    test('el número va con cuatro cifras', () {
      expect(numeroFicha(142), 'Nº 0142');
      expect(numeroFicha(7), 'Nº 0007');
      expect(numeroFicha(12345), 'Nº 12345');
    });

    test('quién la cuenta, como en el diseño', () {
      expect(contadaPor('Carmen Ruiz', 'abuela', deceased: false), 'Carmen Ruiz, abuela');
      expect(contadaPor('Julián Ortega', 'bisabuelo', deceased: true), 'Julián Ortega, bisabuelo (fallecido)');
      expect(contadaPor(null, 'un vecino', deceased: false), 'Un vecino (sin nombre)');
      expect(contadaPor('Carmen', null, deceased: false), 'Carmen');
      expect(contadaPor('  ', '', deceased: false), 'una persona anónima');
    });

    test('la duración del audio como 4:12', () {
      expect(duracionCorta(252), '4:12');
      expect(duracionCorta(65), '1:05');
      expect(duracionCorta(null), isNull);
    });
  });

  testWidgets('pestaña Nº a máquina, título, lugar, tipo, época, quién la cuenta y audio', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha()));
    final numero = tester.widget<Text>(find.text('Nº 0142'));
    expect(numero.style!.fontFamily, 'CourierPrime');
    expect(find.text('La noche que se heló la fuente'), findsOneWidget);
    expect(find.text('Plaza Mayor'), findsOneWidget);
    expect(find.text('Anécdota'), findsOneWidget);
    expect(find.text('· Años 50'), findsOneWidget);
    expect(find.text('Contada por Carmen Ruiz, abuela'), findsOneWidget);
    expect(find.text('Audio · 4:12'), findsOneWidget);
    expect(find.byIcon(LucideIcons.audioLines), findsOneWidget);
  });

  testWidgets('sin audio dice «Texto»', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha(audio: null)));
    expect(find.text('Texto'), findsOneWidget);
    expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
  });

  testWidgets('borde 1,5 de tinta, radio 2 y sombra sólida 3,3', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha()));
    final d = decoracion(tester, find.byType(FichaHistoria));
    expect((d.border as Border).top, BorderSide(color: claro.tinta, width: 1.5));
    expect(d.borderRadius, BorderRadius.circular(2));
    expect(d.boxShadow, [BoxShadow(color: claro.sombra, offset: const Offset(3, 3))]);
    expect(d.color, claro.azulejo);
  });

  testWidgets('la pestaña asoma por encima del borde', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha()));
    final caja = tester.getRect(find.byKey(const Key('ficha-caja')));
    final pestana = tester.getRect(find.byKey(const Key('ficha-pestana')));
    expect(pestana.top, lessThan(caja.top));
    expect(pestana.bottom, greaterThan(caja.top));
  });

  testWidgets('toda la ficha es un solo botón que se lee entero', (tester) async {
    final semantica = tester.ensureSemantics();
    var abierta = 0;
    await montar(tester, SizedBox(width: 760, child: _ficha(onTap: () => abierta++)));
    await tester.tap(find.text('Contada por Carmen Ruiz, abuela'));
    expect(abierta, 1);
    final nodo = tester.getSemantics(find.text('La noche que se heló la fuente'));
    expect(nodo.label, contains('Nº 0142'));
    expect(nodo.label, contains('La noche que se heló la fuente'));
    expect(nodo.label, contains('Audio, 4:12'));
    expect(nodo.flagsCollection.isButton, isTrue);
    semantica.dispose();
  });

  testWidgets('con sello lo enseña junto al título', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha(sello: EstadoSello.enRevision)));
    expect(find.text('EN REVISIÓN'), findsOneWidget);
  });

  testWidgets('sin número no hay pestaña', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha(numero: null)));
    expect(find.textContaining('Nº'), findsNothing);
  });

  testWidgets('compacta, el título baja a 19', (tester) async {
    await montar(tester, SizedBox(width: 760, child: _ficha(compacta: true)));
    expect(tester.widget<Text>(find.text('La noche que se heló la fuente')).style!.fontSize, 19);
  });

  testWidgets('en un móvil estrecho y con la letra muy grande no se desborda', (tester) async {
    await montar(tester, SizedBox(width: 300, child: _ficha(sello: EstadoSello.enRevision)), escala: 1.4);
    expect(tester.takeException(), isNull);
  });
}
