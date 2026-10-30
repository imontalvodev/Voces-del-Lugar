import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/ui/campos.dart';

import 'ayuda.dart';

void main() {
  group('campo', () {
    testWidgets('la etiqueta y la ayuda se ven siempre, aunque el campo esté lleno', (tester) async {
      await montar(
        tester,
        SizedBox(
          width: 360,
          child: CampoTexto(
            etiqueta: '¿Cómo lo llamáis allí?',
            ayuda: 'Por ejemplo: «el lavadero».',
            controller: TextEditingController(text: 'La fuente'),
          ),
        ),
      );
      expect(find.text('¿Cómo lo llamáis allí?'), findsOneWidget);
      expect(find.text('Por ejemplo: «el lavadero».'), findsOneWidget);
      expect(find.text('La fuente'), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(52));
    });

    testWidgets('el lector de pantalla oye la etiqueta en el campo', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const SizedBox(width: 360, child: CampoTexto(etiqueta: 'Título')));
      expect(find.bySemanticsLabel(RegExp('Título')), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('borde de 2 tinta, foco de 3 añil hondo y radio 2', (tester) async {
      await montar(tester, const SizedBox(width: 360, child: CampoTexto(etiqueta: 'Título')));
      final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
      final normal = deco.enabledBorder as OutlineInputBorder;
      final foco = deco.focusedBorder as OutlineInputBorder;
      expect(normal.borderSide, BorderSide(color: claro.tinta, width: 2));
      expect(normal.borderRadius, BorderRadius.circular(2));
      expect(foco.borderSide, BorderSide(color: claro.anilHondo, width: 3));
    });

    testWidgets('el error lleva icono y texto en carmín y tiñe el borde', (tester) async {
      await montar(
        tester,
        const SizedBox(
          width: 360,
          child: CampoTexto(etiqueta: 'Contraseña', error: 'Tiene 5 caracteres. Necesita al menos 8.'),
        ),
      );
      expect(find.text('Tiene 5 caracteres. Necesita al menos 8.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
      final normal = tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder as OutlineInputBorder;
      expect(normal.borderSide.color, claro.carmin);
    });

    testWidgets('lo opcional lo dice al lado de la etiqueta', (tester) async {
      await montar(tester, const SizedBox(width: 360, child: CampoTexto(etiqueta: 'Parentesco', opcional: true)));
      expect(find.textContaining('(opcional)', findRichText: true), findsOneWidget);
    });
  });

  group('casilla', () {
    testWidgets('28 px dentro de 48 de toque; toda la fila la marca', (tester) async {
      var marcada = false;
      await montar(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 360,
            child: Casilla(
              marcada: marcada,
              etiqueta: 'Quien la cuenta me ha dado permiso para publicarla',
              descripcion: 'Es obligatorio.',
              onChanged: (v) => setState(() => marcada = v),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('casilla-caja'))), const Size(28, 28));
      expect(tester.getSize(find.byType(Casilla)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Es obligatorio.'));
      await tester.pump();
      expect(marcada, isTrue);
      expect(decoracion(tester, find.byKey(const Key('casilla-caja'))).color, claro.anil);
    });

    testWidgets('el lector de pantalla la oye como casilla marcada', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, Casilla(marcada: true, etiqueta: 'Ya ha fallecido', onChanged: (_) {}));
      expect(
        tester.getSemantics(find.text('Ya ha fallecido')),
        matchesSemantics(
          label: 'Ya ha fallecido',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantica.dispose();
    });

    testWidgets('con error el borde y el aviso van en carmín', (tester) async {
      await montar(
        tester,
        Casilla(
          marcada: false,
          etiqueta: 'Quien la cuenta me ha dado permiso para publicarla',
          error: 'Sin permiso, la historia no se puede guardar.',
          onChanged: (_) {},
        ),
      );
      expect(find.text('Sin permiso, la historia no se puede guardar.'), findsOneWidget);
      final caja = decoracion(tester, find.byKey(const Key('casilla-caja')));
      expect((caja.border as Border).top.color, claro.carmin);
    });
  });

  group('licencia', () {
    testWidgets('la elegida va sobre velo añil con borde añil y punto', (tester) async {
      String? elegida = 'CC-BY-SA-4.0';
      await montar(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 380,
            child: Column(
              children: [
                for (final (id, titulo, sigla) in [
                  ('CC-BY-SA-4.0', 'Compartir igual', 'CC BY-SA 4.0'),
                  ('CC-BY-4.0', 'Citando la fuente', 'CC BY 4.0'),
                ])
                  OpcionLicencia(
                    key: Key(id),
                    elegida: elegida == id,
                    titulo: titulo,
                    sigla: sigla,
                    descripcion: 'Cualquiera puede usarla.',
                    onSelected: () => setState(() => elegida = id),
                  ),
              ],
            ),
          ),
        ),
      );
      final si = decoracion(tester, find.byKey(const Key('CC-BY-SA-4.0')));
      expect(si.color, claro.anilVelo);
      expect((si.border as Border).top.color, claro.anil);
      final no = decoracion(tester, find.byKey(const Key('CC-BY-4.0')));
      expect(no.color, claro.azulejo);
      expect((no.border as Border).top.color, claro.filete);

      await tester.tap(find.textContaining('Citando la fuente', findRichText: true));
      await tester.pump();
      expect(elegida, 'CC-BY-4.0');
    });
  });
}
