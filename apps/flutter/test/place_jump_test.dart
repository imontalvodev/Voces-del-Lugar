import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/api.dart';
import 'package:voces/widgets/place_jump.dart';

void main() {
  testWidgets('elegir un resultado avisa con ese lugar', (tester) async {
    PlaceHit? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceJump(
            search: (_) async => [PlaceHit(label: 'Cáceres, España', latitude: 39.475, longitude: -6.372)],
            onPick: (hit) => picked = hit,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Cáceres');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('Cáceres, España'));
    await tester.pump();
    expect(picked?.latitude, 39.475);
    expect(picked?.longitude, -6.372);
    expect(find.text('Cáceres, España'), findsNothing);
  });

  testWidgets('con una letra no busca', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceJump(
            search: (_) async {
              calls += 1;
              return [];
            },
            onPick: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'C');
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 0);
  });
}
