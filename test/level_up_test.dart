import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmelo/game/game_state.dart';
import 'package:farmelo/main.dart';

Future<void> _run(WidgetTester tester, {required bool tapBanner}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final game = GameState()..xp = 19; // Bir hasat seviye atlatır.
  game.plant(0, 'bugday');
  game.simulate(30);
  game.start();

  await tester.pumpWidget(FarmeloApp(game: game));
  await tester.pump(const Duration(seconds: 1));
  game.harvest(0);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text('Seviye 2!'), findsOneWidget);

  if (tapBanner) {
    await tester.tap(find.text('Seviye 2!'));
  }
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.text('Seviye 2!'), findsNothing);

  // Oyun dokunuşlara yanıt veriyor: tarla sayfasından Mağaza'ya geçilebiliyor.
  await tester.tap(find.text('Mağaza'));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.text('Hayvanlar'), findsOneWidget);

  game.stop();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('seviye kutlaması kendiliğinden kapanır', (tester) async {
    await _run(tester, tapBanner: false);
  });

  testWidgets('seviye kutlamasına dokununca kapanır', (tester) async {
    await _run(tester, tapBanner: true);
  });
}
