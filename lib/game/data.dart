/// Oyundaki tüm sabit tanımlar: ürünler, bitkiler ve hayvanlar.
library;

enum ItemKind { crop, product, meat, feed }

class ItemDef {
  final String id;
  final String name;
  final String emoji;
  final int basePrice; // Pazardaki taban satış fiyatı. 0 ise satılamaz.
  final ItemKind kind;

  const ItemDef(this.id, this.name, this.emoji, this.basePrice, this.kind);

  bool get sellable => basePrice > 0;
}

class CropDef {
  final String id;
  final String name;
  final String emoji;
  final int seedCost;
  final double growSeconds;
  final int yieldAmount;
  final int unlockLevel;
  final int xp;

  const CropDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.seedCost,
    required this.growSeconds,
    required this.yieldAmount,
    required this.unlockLevel,
    required this.xp,
  });
}

class AnimalDef {
  final String id;
  final String name;
  final String emoji;
  final String babyEmoji;
  final String babyName;
  final int price;
  final double growSeconds;
  final String productId;
  final double produceSeconds;
  final String meatId;
  final int meatAmount;
  final int unlockLevel;
  final int xpProduct;
  final int xpMeat;

  const AnimalDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.babyEmoji,
    required this.babyName,
    required this.price,
    required this.growSeconds,
    required this.productId,
    required this.produceSeconds,
    required this.meatId,
    required this.meatAmount,
    required this.unlockLevel,
    required this.xpProduct,
    required this.xpMeat,
  });
}

class GameData {
  /// Tok bir hayvanın tamamen acıkması için geçen süre (sn).
  static const double fullnessSeconds = 90;

  /// Sulanan tarla bu kadar hızlı büyür.
  static const double waterBoost = 1.5;

  /// Pazar fiyatlarının yenilenme aralığı (sn).
  static const double priceInterval = 30;

  /// Bir oyun gününün uzunluğu (sn).
  static const double dayLength = 240;

  static const int feedPrice = 3;
  static const int maxPlots = 15;
  static const int startPlots = 6;
  static const int maxCapacity = 14;
  static const int startCapacity = 4;

  /// Hayvanları beslerken sırayla denenecek ambar ürünleri.
  static const feedOrder = ['yem', 'bugday', 'misir'];

  static const items = <String, ItemDef>{
    'bugday': ItemDef('bugday', 'Buğday', '🌾', 5, ItemKind.crop),
    'havuc': ItemDef('havuc', 'Havuç', '🥕', 12, ItemKind.crop),
    'misir': ItemDef('misir', 'Mısır', '🌽', 12, ItemKind.crop),
    'domates': ItemDef('domates', 'Domates', '🍅', 20, ItemKind.crop),
    'cilek': ItemDef('cilek', 'Çilek', '🍓', 25, ItemKind.crop),
    'balkabagi': ItemDef('balkabagi', 'Balkabağı', '🎃', 80, ItemKind.crop),
    'yumurta': ItemDef('yumurta', 'Yumurta', '🥚', 9, ItemKind.product),
    'yun': ItemDef('yun', 'Yün', '🧶', 22, ItemKind.product),
    'sut': ItemDef('sut', 'Süt', '🥛', 26, ItemKind.product),
    'tavuk_eti': ItemDef('tavuk_eti', 'Tavuk Eti', '🍗', 22, ItemKind.meat),
    'kuzu_eti': ItemDef('kuzu_eti', 'Kuzu Eti', '🍖', 38, ItemKind.meat),
    'dana_eti': ItemDef('dana_eti', 'Dana Eti', '🥩', 62, ItemKind.meat),
    'yem': ItemDef('yem', 'Yem', '🌿', 0, ItemKind.feed),
  };

  static const crops = <CropDef>[
    CropDef(
      id: 'bugday',
      name: 'Buğday',
      emoji: '🌾',
      seedCost: 4,
      growSeconds: 20,
      yieldAmount: 2,
      unlockLevel: 1,
      xp: 1,
    ),
    CropDef(
      id: 'havuc',
      name: 'Havuç',
      emoji: '🥕',
      seedCost: 10,
      growSeconds: 40,
      yieldAmount: 2,
      unlockLevel: 1,
      xp: 2,
    ),
    CropDef(
      id: 'misir',
      name: 'Mısır',
      emoji: '🌽',
      seedCost: 15,
      growSeconds: 55,
      yieldAmount: 3,
      unlockLevel: 2,
      xp: 3,
    ),
    CropDef(
      id: 'domates',
      name: 'Domates',
      emoji: '🍅',
      seedCost: 25,
      growSeconds: 80,
      yieldAmount: 3,
      unlockLevel: 3,
      xp: 4,
    ),
    CropDef(
      id: 'cilek',
      name: 'Çilek',
      emoji: '🍓',
      seedCost: 40,
      growSeconds: 120,
      yieldAmount: 4,
      unlockLevel: 4,
      xp: 6,
    ),
    CropDef(
      id: 'balkabagi',
      name: 'Balkabağı',
      emoji: '🎃',
      seedCost: 60,
      growSeconds: 180,
      yieldAmount: 2,
      unlockLevel: 5,
      xp: 9,
    ),
  ];

  static const animals = <AnimalDef>[
    AnimalDef(
      id: 'tavuk',
      name: 'Tavuk',
      emoji: '🐔',
      babyEmoji: '🐥',
      babyName: 'Civciv',
      price: 40,
      growSeconds: 45,
      productId: 'yumurta',
      produceSeconds: 20,
      meatId: 'tavuk_eti',
      meatAmount: 2,
      unlockLevel: 1,
      xpProduct: 1,
      xpMeat: 4,
    ),
    AnimalDef(
      id: 'koyun',
      name: 'Koyun',
      emoji: '🐑',
      babyEmoji: '🐑',
      babyName: 'Kuzu',
      price: 90,
      growSeconds: 80,
      productId: 'yun',
      produceSeconds: 40,
      meatId: 'kuzu_eti',
      meatAmount: 3,
      unlockLevel: 2,
      xpProduct: 2,
      xpMeat: 8,
    ),
    AnimalDef(
      id: 'inek',
      name: 'İnek',
      emoji: '🐄',
      babyEmoji: '🐮',
      babyName: 'Buzağı',
      price: 180,
      growSeconds: 120,
      productId: 'sut',
      produceSeconds: 30,
      meatId: 'dana_eti',
      meatAmount: 4,
      unlockLevel: 3,
      xpProduct: 3,
      xpMeat: 14,
    ),
  ];

  static CropDef crop(String id) => crops.firstWhere((c) => c.id == id);
  static AnimalDef animal(String id) => animals.firstWhere((a) => a.id == id);
  static ItemDef item(String id) => items[id]!;
}
