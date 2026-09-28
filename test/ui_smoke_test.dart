import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmelo/game/game_state.dart';
import 'package:farmelo/main.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final size in const [Size(390, 844), Size(1200, 800)]) {
    testWidgets('tüm sayfalar hatasız açılır ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final game = GameState()
        ..money = 2000
        ..level = 5
        ..inventory.addAll({'bugday': 4, 'sut': 2, 'dana_eti': 3, 'yumurta': 5});
      game.buyAnimal('tavuk');
      game.buyAnimal('inek');
      game.buyAnimal('koyun');
      game.plant(0, 'bugday');
      game.plant(1, 'cilek');
      game.water(1);
      game.simulate(25);
      game.start();

      await tester.pumpWidget(FarmeloApp(game: game));
      await settle(tester);

      // Hasat et
      await tester.tap(find.text('HASAT ET').first);
      await settle(tester);

      // Boş tarlaya dokun, tohum paneli
      await tester.tap(find.text('Ek').first);
      await settle(tester);
      expect(find.text('Ne ekelim?'), findsOneWidget);
      await tester.tap(find.text('Havuç'));
      await settle(tester);

      for (final tab in ['Mera', 'Pazar', 'Mağaza']) {
        await tester.tap(find.text(tab));
        await settle(tester);
      }
      await tester.tap(find.text('Mera'));
      await settle(tester);
      // Hayvan detayı
      await tester.longPress(find.text('🐥'));
      await settle(tester);
      // Hayvanlar rastgele dolaştığı için üstteki hangisiyse onun paneli açılır.
      expect(find.textContaining(RegExp(r' #\d+$')), findsOneWidget);

      game.stop();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
