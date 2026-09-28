import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/data.dart';
import '../game/game_state.dart';
import 'theme.dart';
import 'widgets/animal_figure.dart';
import 'widgets/common.dart';
import 'widgets/fx.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _SectionTitle(
          'Hayvanlar',
          'Mera ${game.animals.length}/${game.capacity}',
        ),
        for (final def in GameData.animals)
          StaggerIn(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AnimalCard(def: def),
            ),
          ),
        const SizedBox(height: 8),
        _SectionTitle('Yem', 'Stok: ${game.inventory['yem'] ?? 0}'),
        StaggerIn(index: i++, child: const _FeedCard()),
        const SizedBox(height: 18),
        const _SectionTitle('Çiftliği büyüt', null),
        StaggerIn(
          index: i++,
          child: _UpgradeCard(
            emoji: '🚜',
            title: 'Yeni tarla',
            detail: '${game.plots.length}/${GameData.maxPlots} tarla',
            price: game.canBuyPlot ? game.nextPlotPrice : null,
            onBuy: game.buyPlot,
          ),
        ),
        const SizedBox(height: 10),
        StaggerIn(
          index: i++,
          child: _UpgradeCard(
            emoji: '🪵',
            title: 'Merayı genişlet',
            detail: '+2 hayvan yeri · şu an ${game.capacity}',
            price: game.canExpandPasture ? game.nextCapacityPrice : null,
            onBuy: game.expandPasture,
          ),
        ),
        const SizedBox(height: 24),
        const _HowToPlay(),
        const SizedBox(height: 16),
        const Center(child: _ResetButton()),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle(this.title, this.trailing);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: FarmColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final AnimalDef def;
  const _AnimalCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final locked = def.unlockLevel > game.level;
    final product = GameData.item(def.productId);
    final meat = GameData.item(def.meatId);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: locked ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FarmColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBDDC2)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [FarmColors.meadow, FarmColors.grass],
                ),
              ),
              child: locked
                  ? const Text('🔒', style: TextStyle(fontSize: 30))
                  : AnimalFigure(typeId: def.id, baby: true, size: 54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${def.babyName} → ${def.name} ${def.emoji}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked
                        ? 'Seviye ${def.unlockLevel}\'te açılır'
                        : 'Büyüme: ${formatSeconds(def.growSeconds)} · '
                              '${product.emoji} ${product.name}: ${formatSeconds(def.produceSeconds)}\n'
                              'Et: ${meat.emoji} ${def.meatAmount} × ${meat.name}',
                    style: const TextStyle(
                      color: FarmColors.inkSoft,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FarmButton(
              compact: true,
              label: '${def.price} 🪙',
              onTap: locked
                  ? null
                  : (pos) {
                      if (game.buyAnimal(def.id)) {
                        Sfx.play(Sound.buy, volume: 0.7);
                        Sfx.voice(def.id, adult: false);
                        Fx.floatText(context, pos, '${def.babyEmoji} Meraya!');
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    void buy(Offset pos, int n) {
      if (game.buyFeed(n)) {
        Sfx.play(Sound.buy);
        Fx.floatText(context, pos, '+$n 🌿');
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FarmColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBDDC2)),
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Bir öğün, hayvanı tamamen doyurur. Aç hayvan büyümez ve ürün vermez.',
              style: TextStyle(color: FarmColors.inkSoft, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              FarmButton(
                compact: true,
                label: '×1 · ${GameData.feedPrice} 🪙',
                color: FarmColors.wood,
                onTap: (pos) => buy(pos, 1),
              ),
              const SizedBox(height: 8),
              FarmButton(
                compact: true,
                label: '×10 · ${GameData.feedPrice * 10} 🪙',
                onTap: (pos) => buy(pos, 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String detail;
  final int? price; // null = en üst seviyede
  final bool Function() onBuy;

  const _UpgradeCard({
    required this.emoji,
    required this.title,
    required this.detail,
    required this.price,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FarmColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBDDC2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: FarmColors.inkSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          price == null
              ? const Text(
                  'Tamamlandı',
                  style: TextStyle(
                    color: FarmColors.up,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : FarmButton(
                  compact: true,
                  label: '$price 🪙',
                  color: FarmColors.wood,
                  onTap: (pos) {
                    if (onBuy()) {
                      Sfx.play(Sound.buy);
                      Fx.floatText(
                        context,
                        pos,
                        '-$price 🪙',
                        color: const Color(0xFFFFD0C0),
                      );
                    }
                  },
                ),
        ],
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  static const _tips = [
    ('🌱', 'Boş tarlaya dokun, tohum seç. Sulanan tarla daha hızlı büyür.'),
    (
      '🐣',
      'Yavru hayvan al; tok kaldıkça büyür, yetişince süt, yumurta ya da yün verir.',
    ),
    (
      '🥩',
      'Yetişkin bir hayvana uzun bas ya da dokunup detayını aç; et olarak satabilirsin.',
    ),
    (
      '⚖️',
      'Pazar fiyatları 30 saniyede bir değişir. ▲ gördüğünde satmak kârlı.',
    ),
    (
      '⭐',
      'Hasat ve toplama deneyim kazandırır; yeni seviyeler yeni ürünler açar.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text(
          'Nasıl oynanır?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: [
          for (final (e, t) in _tips)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t, style: const TextStyle(height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResetButton extends StatefulWidget {
  const _ResetButton();

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _confirming = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        if (_confirming) {
          _timer?.cancel();
          setState(() => _confirming = false);
          GameScope.read(context).reset();
        } else {
          setState(() => _confirming = true);
          _timer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _confirming = false);
          });
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          _confirming ? 'Tüm ilerleme silinecek. Emin misin?' : 'Oyunu sıfırla',
          key: ValueKey(_confirming),
          style: TextStyle(
            color: _confirming ? FarmColors.down : FarmColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
