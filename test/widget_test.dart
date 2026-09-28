import 'package:flutter_test/flutter_test.dart';

import 'package:farmelo/game/data.dart';
import 'package:farmelo/game/game_state.dart';

void main() {
  test('ekim, büyüme ve hasat', () {
    final game = GameState();
    expect(game.plant(0, 'bugday'), isTrue);
    expect(game.money, 100 - GameData.crop('bugday').seedCost);

    game.simulate(GameData.crop('bugday').growSeconds + 1);
    expect(game.plots[0].isReady, isTrue);

    expect(game.harvest(0), GameData.crop('bugday').yieldAmount);
    expect(game.inventory['bugday'], GameData.crop('bugday').yieldAmount);
    expect(game.plots[0].isEmpty, isTrue);
  });

  test('sulanan tarla daha hızlı büyür', () {
    final game = GameState()
      ..plant(0, 'havuc')
      ..plant(1, 'havuc')
      ..water(0);
    game.simulate(GameData.crop('havuc').growSeconds / GameData.waterBoost + 1);
    expect(game.plots[0].isReady, isTrue);
    expect(game.plots[1].isReady, isFalse);
  });

  test('hayvan beslenirse büyür, süt verir ve et olarak satılır', () {
    final game = GameState()..money = 1000;
    game.level = 3;
    expect(game.buyAnimal('inek'), isTrue);
    final cow = game.animals.single;

    // Aç kalmasın diye her dakika besle.
    for (var i = 0; i < 4; i++) {
      game.simulate(60);
      game.buyFeed(1);
      game.feed(cow);
    }
    expect(cow.isAdult, isTrue);
    expect(cow.productReady, isTrue);
    expect(game.collect(cow), isTrue);
    expect(game.inventory['sut'], 1);

    expect(game.slaughter(cow), isTrue);
    expect(game.animals, isEmpty);
    expect(game.inventory['dana_eti'], GameData.animal('inek').meatAmount);
  });

  test('aç hayvan büyümez', () {
    final game = GameState()..buyAnimal('tavuk');
    final chick = game.animals.single;
    game.simulate(GameData.fullnessSeconds + 5);
    final grown = chick.growth;
    game.simulate(30);
    expect(chick.growth, grown);
  });

  test('satış parayı artırır', () {
    final game = GameState();
    game.inventory['sut'] = 3;
    final before = game.money;
    final earned = game.sell('sut', 3);
    expect(earned, greaterThan(0));
    expect(game.money, before + earned);
    expect(game.inventory['sut'], 0);
  });
}
