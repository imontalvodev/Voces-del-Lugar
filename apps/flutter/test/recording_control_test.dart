import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/widgets/recording_control.dart';

void main() {
  testWidgets('escuchar pasa la url y luego se puede parar', (tester) async {
    String? played;
    var stopped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingControl(
            url: 'http://localhost:8001/api/v1/media/abc',
            play: (url) async => played = url,
            stop: () async => stopped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Escuchar'));
    await tester.pump();
    expect(played, 'http://localhost:8001/api/v1/media/abc');
    await tester.tap(find.text('Parar'));
    await tester.pump();
    expect(stopped, isTrue);
    expect(find.text('Escuchar'), findsOneWidget);
  });
}
