import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

class Plot {
  String? cropId;
  double progress = 0; // 0..1
  bool watered = false;

  bool get isEmpty => cropId == null;
  bool get isReady => cropId != null && progress >= 1;
  bool get isGrowing => cropId != null && progress < 1;
  CropDef? get crop => cropId == null ? null : GameData.crop(cropId!);

  double get secondsLeft {
    final c = crop;
    if (c == null) return 0;
    final rate = watered ? GameData.waterBoost : 1.0;
    return (1 - progress) * c.growSeconds / rate;
  }

  Map<String, dynamic> toJson() => {'c': cropId, 'p': progress, 'w': watered};

  static Plot fromJson(Map<String, dynamic> j) => Plot()
    ..cropId = j['c'] as String?
    ..progress = (j['p'] as num).toDouble()
    ..watered = j['w'] as bool;
}

class Animal {
  final int id;
  final String typeId;
  double growth; // 0..1, 1 = yetişkin
  double fullness; // 0..1
  double production; // 0..1

  // Merada dolaşma (kaydedilmez).
  double x;
  double y;
  bool facingRight = false;
  int moveMs = 0;
  double moveUntil = 0; // Yürüyüşün bittiği oyun zamanı (sn).
  double wanderTimer;

  Animal({
    required this.id,
    required this.typeId,
    this.growth = 0,
    this.fullness = 1,
    this.production = 0,
    required this.x,
    required this.y,
    this.wanderTimer = 1,
  });

  AnimalDef get def => GameData.animal(typeId);
  bool get isAdult => growth >= 1;
  bool get productReady => isAdult && production >= 1;
  bool get hungry => fullness < 0.25;
  bool get starving => fullness <= 0;
  bool isWalking(double now) => now < moveUntil;
  String get emoji => isAdult ? def.emoji : def.babyEmoji;
  String get displayName => isAdult ? def.name : def.babyName;

  Map<String, dynamic> toJson() => {
    'id': id,
    't': typeId,
    'g': growth,
    'f': fullness,
    'p': production,
  };

  static Animal fromJson(Map<String, dynamic> j, Random rng) => Animal(
    id: j['id'] as int,
    typeId: j['t'] as String,
    growth: (j['g'] as num).toDouble(),
    fullness: (j['f'] as num).toDouble(),
    production: (j['p'] as num).toDouble(),
    x: 0.1 + rng.nextDouble() * 0.8,
    y: 0.15 + rng.nextDouble() * 0.7,
    wanderTimer: rng.nextDouble() * 3,
  );
}

sealed class GameEvent {}

class LevelUpEvent extends GameEvent {
  final int level;
  final List<String> unlocked;
  LevelUpEvent(this.level, this.unlocked);
}

class ToastEvent extends GameEvent {
  final String message;
  ToastEvent(this.message);
}

class GameState extends ChangeNotifier {
  static const _saveKey = 'farmelo_save_v1';
  static const _tickMs = 100;

  final SharedPreferences? _prefs;
  final Random _rng = Random();
  final _events = StreamController<GameEvent>.broadcast();

  int money = 100;
  int xp = 0;
  int level = 1;
  double elapsed = 0; // Toplam oyun süresi (sn), gün döngüsü için.
  List<Plot> plots = List.generate(GameData.startPlots, (_) => Plot());
  List<Animal> animals = [];
  int capacity = GameData.startCapacity;
  Map<String, int> inventory = {'yem': 5};
  Map<String, double> priceFactors = {};
  Map<String, double> lastPriceFactors = {};
  double priceTimer = GameData.priceInterval;
  String lastSeed = 'bugday';
  int _nextAnimalId = 1;

  Timer? _timer;
  DateTime _lastTick = DateTime.now();
  double _saveTimer = 0;

  GameState([this._prefs]) {
    _resetPrices();
  }

  Stream<GameEvent> get events => _events.stream;

  // ---------------------------------------------------------------- Döngü

  void start() {
    _lastTick = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      final now = DateTime.now();
      final dt = now.difference(_lastTick).inMicroseconds / 1e6;
      _lastTick = now;
      // Uzun bir duraklamadan dönülürse (ör. uygulama arka plandaydı) çevrimdışı ilerlet.
      if (dt > 2) {
        simulate(dt);
      } else {
        _step(dt, wander: true);
      }
      _saveTimer += dt;
      if (_saveTimer > 5) {
        _saveTimer = 0;
        save();
      }
      notifyListeners();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Büyük zaman aralıklarını 1 saniyelik adımlarla ilerletir.
  void simulate(double seconds) {
    var left = min(seconds, 3 * 3600.0);
    while (left > 0) {
      final step = min(1.0, left);
      _step(step, wander: false);
      left -= step;
    }
  }

  void _step(double dt, {required bool wander}) {
    elapsed += dt;

    for (final p in plots) {
      final c = p.crop;
      if (c == null || p.progress >= 1) continue;
      final rate = p.watered ? GameData.waterBoost : 1.0;
      p.progress = min(1, p.progress + dt * rate / c.growSeconds);
    }

    for (final a in animals) {
      if (a.fullness > 0) {
        a.fullness = max(0, a.fullness - dt / GameData.fullnessSeconds);
        if (!a.isAdult) {
          a.growth = min(1, a.growth + dt / a.def.growSeconds);
        } else {
          a.production = min(1, a.production + dt / a.def.produceSeconds);
        }
      }
      if (wander) {
        a.wanderTimer -= dt;
        if (a.wanderTimer <= 0) _wander(a);
      }
    }

    priceTimer -= dt;
    if (priceTimer <= 0) {
      priceTimer = GameData.priceInterval;
      _shiftPrices();
    }
  }

  void _wander(Animal a) {
    // Aç hayvanlar daha az hareket eder.
    final range = a.starving ? 0.08 : 0.35;
    final nx = (a.x + (_rng.nextDouble() * 2 - 1) * range).clamp(0.05, 0.95);
    final ny = (a.y + (_rng.nextDouble() * 2 - 1) * range).clamp(0.12, 0.9);
    final dist = sqrt(pow(nx - a.x, 2) + pow(ny - a.y, 2));
    if ((nx - a.x).abs() > 0.02) a.facingRight = nx > a.x;
    a.moveMs = (dist * (a.isAdult ? 9000 : 6000)).round().clamp(400, 4000);
    a.moveUntil = elapsed + a.moveMs / 1000;
    a.x = nx;
    a.y = ny;
    a.wanderTimer = a.moveMs / 1000 + 1.5 + _rng.nextDouble() * 4;
  }

  // ---------------------------------------------------------------- Seviye

  int get xpForNext => 20 + (level - 1) * 30;
  double get levelProgress => (xp / xpForNext).clamp(0, 1);

  void _gainXp(int amount) {
    xp += amount;
    while (xp >= xpForNext) {
      xp -= xpForNext;
      level++;
      final unlocked = [
        for (final c in GameData.crops)
          if (c.unlockLevel == level) '${c.emoji} ${c.name}',
        for (final a in GameData.animals)
          if (a.unlockLevel == level) '${a.emoji} ${a.name}',
      ];
      _events.add(LevelUpEvent(level, unlocked));
    }
  }

  void toast(String message) => _events.add(ToastEvent(message));

  // ---------------------------------------------------------------- Tarla

  bool plant(int index, String cropId) {
    final plot = plots[index];
    final crop = GameData.crop(cropId);
    if (!plot.isEmpty) return false;
    if (crop.unlockLevel > level) {
      toast('${crop.name} için seviye ${crop.unlockLevel} gerekli');
      return false;
    }
    if (money < crop.seedCost) {
      toast('Tohum için yeterli paran yok');
      return false;
    }
    money -= crop.seedCost;
    plot
      ..cropId = cropId
      ..progress = 0
      ..watered = false;
    lastSeed = cropId;
    notifyListeners();
    return true;
  }

  int plantAll(String cropId) {
    var count = 0;
    for (var i = 0; i < plots.length; i++) {
      if (!plots[i].isEmpty) continue;
      if (money < GameData.crop(cropId).seedCost) break;
      if (plant(i, cropId)) count++;
    }
    if (count == 0 && emptyPlotCount > 0) {
      toast('Tohum için yeterli paran yok');
    }
    return count;
  }

  bool water(int index) {
    final plot = plots[index];
    if (!plot.isGrowing || plot.watered) return false;
    plot.watered = true;
    notifyListeners();
    return true;
  }

  int waterAll() {
    var count = 0;
    for (var i = 0; i < plots.length; i++) {
      if (water(i)) count++;
    }
    return count;
  }

  /// Hasat edilen ürün miktarını döndürür.
  int harvest(int index) {
    final plot = plots[index];
    final crop = plot.crop;
    if (crop == null || !plot.isReady) return 0;
    _addItem(crop.id, crop.yieldAmount);
    plot
      ..cropId = null
      ..progress = 0
      ..watered = false;
    _gainXp(crop.xp);
    notifyListeners();
    return crop.yieldAmount;
  }

  int harvestAll() {
    var total = 0;
    for (var i = 0; i < plots.length; i++) {
      total += harvest(i);
    }
    return total;
  }

  int get readyPlotCount => plots.where((p) => p.isReady).length;
  int get emptyPlotCount => plots.where((p) => p.isEmpty).length;
  int get dryPlotCount => plots.where((p) => p.isGrowing && !p.watered).length;

  int get nextPlotPrice =>
      (40 * pow(1.55, plots.length - GameData.startPlots)).round();
  bool get canBuyPlot => plots.length < GameData.maxPlots;

  bool buyPlot() {
    if (!canBuyPlot) return false;
    final price = nextPlotPrice;
    if (money < price) {
      toast('Yeni tarla için $price 🪙 gerekli');
      return false;
    }
    money -= price;
    plots.add(Plot());
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------- Hayvanlar

  bool buyAnimal(String typeId) {
    final def = GameData.animal(typeId);
    if (def.unlockLevel > level) {
      toast('${def.name} için seviye ${def.unlockLevel} gerekli');
      return false;
    }
    if (animals.length >= capacity) {
      toast('Mera dolu, mağazadan genişlet');
      return false;
    }
    if (money < def.price) {
      toast('${def.babyName} için ${def.price} 🪙 gerekli');
      return false;
    }
    money -= def.price;
    animals.add(
      Animal(
        id: _nextAnimalId++,
        typeId: typeId,
        x: 0.2 + _rng.nextDouble() * 0.6,
        y: 0.3 + _rng.nextDouble() * 0.4,
        wanderTimer: 0.5,
      ),
    );
    notifyListeners();
    return true;
  }

  int get feedCount =>
      GameData.feedOrder.fold(0, (sum, id) => sum + (inventory[id] ?? 0));

  /// Beslenirse kullanılan yemin emojisini döndürür.
  String? feed(Animal a) {
    if (a.fullness > 0.9) return null;
    for (final id in GameData.feedOrder) {
      if ((inventory[id] ?? 0) > 0) {
        _addItem(id, -1);
        a.fullness = 1;
        notifyListeners();
        return GameData.item(id).emoji;
      }
    }
    toast('Yem kalmadı, mağazadan al');
    return null;
  }

  int feedAll() {
    var count = 0;
    final hungry = animals.where((a) => a.fullness <= 0.9).toList()
      ..sort((a, b) => a.fullness.compareTo(b.fullness));
    for (final a in hungry) {
      if (feedCount == 0) {
        toast('Yem kalmadı, mağazadan al');
        break;
      }
      if (feed(a) != null) count++;
    }
    return count;
  }

  bool collect(Animal a) {
    if (!a.productReady) return false;
    a.production = 0;
    _addItem(a.def.productId, 1);
    _gainXp(a.def.xpProduct);
    notifyListeners();
    return true;
  }

  int collectAll() {
    var count = 0;
    for (final a in animals) {
      if (collect(a)) count++;
    }
    return count;
  }

  int get readyAnimalCount => animals.where((a) => a.productReady).length;

  bool slaughter(Animal a) {
    if (!a.isAdult) return false;
    animals.remove(a);
    _addItem(a.def.meatId, a.def.meatAmount);
    _gainXp(a.def.xpMeat);
    notifyListeners();
    return true;
  }

  int get nextCapacityPrice =>
      (120 * pow(1.6, (capacity - GameData.startCapacity) / 2)).round();
  bool get canExpandPasture => capacity < GameData.maxCapacity;

  bool expandPasture() {
    if (!canExpandPasture) return false;
    final price = nextCapacityPrice;
    if (money < price) {
      toast('Mera genişletmek için $price 🪙 gerekli');
      return false;
    }
    money -= price;
    capacity += 2;
    notifyListeners();
    return true;
  }

  bool buyFeed(int amount) {
    final price = GameData.feedPrice * amount;
    if (money < price) {
      toast('Yem için $price 🪙 gerekli');
      return false;
    }
    money -= price;
    _addItem('yem', amount);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------- Pazar

  void _resetPrices() {
    for (final item in GameData.items.values) {
      if (!item.sellable) continue;
      priceFactors[item.id] = 1;
      lastPriceFactors[item.id] = 1;
    }
  }

  void _shiftPrices() {
    for (final id in priceFactors.keys) {
      final old = priceFactors[id]!;
      lastPriceFactors[id] = old;
      // Ortalamaya doğru çeken rastgele yürüyüş.
      final drift = (1 - old) * 0.3 + (_rng.nextDouble() * 2 - 1) * 0.12;
      priceFactors[id] = (old + drift).clamp(0.75, 1.35);
    }
  }

  int priceOf(String id) =>
      max(1, (GameData.item(id).basePrice * (priceFactors[id] ?? 1)).round());

  /// -1 düştü, 0 sabit, 1 yükseldi.
  int trendOf(String id) {
    final now = priceFactors[id] ?? 1;
    final before = lastPriceFactors[id] ?? 1;
    if ((now - before).abs() < 0.01) return 0;
    return now > before ? 1 : -1;
  }

  int sell(String id, int amount) {
    final have = inventory[id] ?? 0;
    final n = min(have, amount);
    if (n <= 0) return 0;
    final earned = priceOf(id) * n;
    _addItem(id, -n);
    money += earned;
    notifyListeners();
    return earned;
  }

  List<ItemDef> get sellableItems =>
      GameData.items.values.where((i) => i.sellable).toList();

  int get inventoryValue => sellableItems.fold(
    0,
    (sum, i) => sum + (inventory[i.id] ?? 0) * priceOf(i.id),
  );

  int sellAll() {
    var total = 0;
    for (final item in sellableItems) {
      total += sell(item.id, inventory[item.id] ?? 0);
    }
    return total;
  }

  void _addItem(String id, int amount) {
    inventory[id] = max(0, (inventory[id] ?? 0) + amount);
  }

  // ---------------------------------------------------------------- Gün döngüsü

  /// 0 = gece yarısı, 0.25 = gün doğumu, 0.5 = öğle, 0.75 = gün batımı.
  double get dayTime => ((elapsed / GameData.dayLength) + 0.3) % 1.0;
  int get dayNumber => ((elapsed / GameData.dayLength) + 0.3).floor() + 1;

  // ---------------------------------------------------------------- Kayıt

  Map<String, dynamic> toJson() => {
    'money': money,
    'xp': xp,
    'level': level,
    'elapsed': elapsed,
    'plots': plots.map((p) => p.toJson()).toList(),
    'animals': animals.map((a) => a.toJson()).toList(),
    'capacity': capacity,
    'inventory': inventory,
    'prices': priceFactors,
    'lastPrices': lastPriceFactors,
    'priceTimer': priceTimer,
    'lastSeed': lastSeed,
    'nextId': _nextAnimalId,
    'savedAt': DateTime.now().millisecondsSinceEpoch,
  };

  void save() {
    _prefs?.setString(_saveKey, jsonEncode(toJson()));
  }

  static GameState load(SharedPreferences? prefs) {
    final game = GameState(prefs);
    final raw = prefs?.getString(_saveKey);
    if (raw == null) return game;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      game
        ..money = j['money'] as int
        ..xp = j['xp'] as int
        ..level = j['level'] as int
        ..elapsed = (j['elapsed'] as num).toDouble()
        ..plots = (j['plots'] as List)
            .map((e) => Plot.fromJson(e as Map<String, dynamic>))
            .toList()
        ..animals = (j['animals'] as List)
            .map((e) => Animal.fromJson(e as Map<String, dynamic>, game._rng))
            .toList()
        ..capacity = j['capacity'] as int
        ..inventory = (j['inventory'] as Map).map(
          (k, v) => MapEntry(k as String, v as int),
        )
        ..priceTimer = (j['priceTimer'] as num).toDouble()
        ..lastSeed = j['lastSeed'] as String
        .._nextAnimalId = j['nextId'] as int;
      (j['prices'] as Map).forEach(
        (k, v) => game.priceFactors[k as String] = (v as num).toDouble(),
      );
      (j['lastPrices'] as Map).forEach(
        (k, v) => game.lastPriceFactors[k as String] = (v as num).toDouble(),
      );

      final savedAt = DateTime.fromMillisecondsSinceEpoch(j['savedAt'] as int);
      final away = DateTime.now().difference(savedAt).inSeconds.toDouble();
      if (away > 1) game.simulate(away);
    } catch (e) {
      debugPrint('Kayıt okunamadı, yeni oyun başlıyor: $e');
      return GameState(prefs);
    }
    return game;
  }

  void reset() {
    stop();
    _prefs?.remove(_saveKey);
    money = 100;
    xp = 0;
    level = 1;
    elapsed = 0;
    plots = List.generate(GameData.startPlots, (_) => Plot());
    animals = [];
    capacity = GameData.startCapacity;
    inventory = {'yem': 5};
    priceTimer = GameData.priceInterval;
    lastSeed = 'bugday';
    _nextAnimalId = 1;
    _resetPrices();
    start();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _events.close();
    super.dispose();
  }
}

/// Oyun durumunu ağaca taşır; `GameScope.of(context)` dinleyen widget'ı yeniden çizer.
class GameScope extends InheritedNotifier<GameState> {
  const GameScope({super.key, required GameState game, required super.child})
    : super(notifier: game);

  static GameState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameScope>()!.notifier!;

  static GameState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameScope>()!.notifier!;
}
