import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/ui/blur_gate.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/recent_activity.dart';

void main() {
  group('RecentActivity', () {
    test('está quieta hasta que llega actividad', () {
      final activity = RecentActivity(const Duration(milliseconds: 180));
      expect(activity.value, isFalse);
      activity.dispose();
    });

    testWidgets('se activa con cada aviso y se apaga tras la última pausa', (tester) async {
      final activity = RecentActivity(const Duration(milliseconds: 180));
      addTearDown(activity.dispose);
      activity.ping();
      expect(activity.value, isTrue);
      await tester.pump(const Duration(milliseconds: 150));
      activity.ping(); // otro movimiento antes de que acabe la pausa
      await tester.pump(const Duration(milliseconds: 150));
      expect(activity.value, isTrue);
      await tester.pump(const Duration(milliseconds: 40));
      expect(activity.value, isFalse);
    });
  });

  group('Glass', () {
    testWidgets('desenfoca el fondo cuando blur es mayor que cero', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Glass(child: SizedBox(width: 10, height: 10))));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('con blur cero no pide al motor que desenfoque nada', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Glass(blur: 0, child: SizedBox(width: 10, height: 10))));
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('BlurGate', () {
    testWidgets('los cristales dejan de desenfocar mientras algo se mueve y lo recuperan después', (tester) async {
      late BuildContext inside;
      await tester.pumpWidget(
        MaterialApp(
          home: BlurGate(
            child: Builder(
              builder: (context) {
                inside = context;
                return const Glass(child: SizedBox(width: 10, height: 10));
              },
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);

      BlurGate.of(inside).ping();
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('sin BlurGate arriba el cristal desenfoca como siempre', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Glass(child: SizedBox(width: 10, height: 10))));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
