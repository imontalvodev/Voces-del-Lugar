import 'dart:async';

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

  testWidgets('vuelve a escuchar cuando termina solo', (tester) async {
    final done = StreamController<void>();
    addTearDown(done.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingControl(
            url: 'http://localhost:8001/api/v1/media/abc',
            play: (_) async {},
            stop: () async {},
            completed: done.stream,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Escuchar'));
    await tester.pump();
    expect(find.text('Parar'), findsOneWidget);
    done.add(null);
    await tester.pump();
    expect(find.text('Escuchar'), findsOneWidget);
  });
}
