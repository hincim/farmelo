import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/data.dart';
import '../game/game_state.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/fx.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  static const _sections = [
    (ItemKind.crop, 'Tarla ürünleri'),
    (ItemKind.product, 'Süt, yumurta, yün'),
    (ItemKind.meat, 'Et'),
  ];

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final items = game.sellableItems;
    final hasAny = items.any((i) => (game.inventory[i.id] ?? 0) > 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _MarketHeader(game: game),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 400),
          sizeCurve: Curves.easeInOutCubic,
          crossFadeState: hasAny
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const _EmptyBarn(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (kind, title) in _sections)
                _Collapsible(
                  visible: items.any(
                    (i) => i.kind == kind && (game.inventory[i.id] ?? 0) > 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: FarmColors.inkSoft,
                          ),
                        ),
                      ),
                      for (final item in items.where((i) => i.kind == kind))
                        _Collapsible(
                          visible: (game.inventory[item.id] ?? 0) > 0,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ItemRow(item: item),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _FeedRow(count: game.inventory['yem'] ?? 0),
      ],
    );
  }
}

class _MarketHeader extends StatelessWidget {
  final GameState game;
  const _MarketHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    final value = game.inventoryValue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FarmColors.barnRed,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0xFF8E3524), offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SmoothCircle(
                  value: 1 - game.priceTimer / GameData.priceInterval,
                ),
                const Text('⚖️', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Köy Pazarı',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Fiyatlar ${game.priceTimer.ceil()} sn sonra değişir',
                  style: const TextStyle(
                    color: Color(0xFFFFE3DA),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          FarmButton(
            label: 'Hepsini sat',
            emoji: '💰',
            color: FarmColors.straw,
            textColor: FarmColors.ink,
            compact: true,
            onTap: value == 0
                ? null
                : (pos) {
                    final earned = game.sellAll();
                    coinBurst(context, pos, earned);
                  },
          ),
        ],
      ),
    );
  }
}

class SmoothCircle extends StatelessWidget {
  final double value;
  const SmoothCircle({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 150),
      builder: (context, v, _) => SizedBox.expand(
        child: CircularProgressIndicator(
          value: v,
          strokeWidth: 3,
          color: FarmColors.straw,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

void coinBurst(BuildContext context, Offset pos, int earned) {
  if (earned <= 0) return;
  Sfx.play(Sound.coin);
  Fx.floatText(context, pos, '+$earned 🪙', color: const Color(0xFFFFE27A));
  Fx.flyTo(
    context,
    pos,
    coinTargetKey,
    '🪙',
    count: min(10, 2 + earned ~/ 25),
    pulse: coinPulse,
  );
}

class _ItemRow extends StatelessWidget {
  final ItemDef item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final count = game.inventory[item.id] ?? 0;
    final price = game.priceOf(item.id);
    final trend = game.trendOf(item.id);
    final trendColor = switch (trend) {
      1 => FarmColors.up,
      -1 => FarmColors.down,
      _ => FarmColors.inkSoft,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: FarmColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEBDDC2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: FarmColors.cream,
              shape: BoxShape.circle,
            ),
            child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 10,
                  children: [
                    AnimatedCount(
                      count,
                      prefix: '×',
                      style: const TextStyle(color: FarmColors.inkSoft),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: Offset(0, trend >= 0 ? 0.6 : -0.6),
                            end: Offset.zero,
                          ).animate(a),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '${switch (trend) {
                          1 => '▲',
                          -1 => '▼',
                          _ => '•',
                        }} $price 🪙',
                        key: ValueKey(price),
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FarmButton(
            compact: true,
            label: '1 sat',
            color: FarmColors.wood,
            onTap: count == 0
                ? null
                : (pos) => coinBurst(context, pos, game.sell(item.id, 1)),
          ),
          const SizedBox(width: 8),
          FarmButton(
            compact: true,
            label: 'Hepsi',
            onTap: count == 0
                ? null
                : (pos) => coinBurst(context, pos, game.sell(item.id, count)),
          ),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  final int count;
  const _FeedRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2D2B4), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hayvan yemi: $count. Yem bitince buğday ve mısır da yem olarak kullanılır.',
              style: const TextStyle(color: FarmColors.inkSoft, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBarn extends StatelessWidget {
  const _EmptyBarn();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: FarmColors.paper,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Text('🧺', style: TextStyle(fontSize: 44)),
          SizedBox(height: 10),
          Text(
            'Ambar boş',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Tarlada hasat yap ya da hayvanlardan ürün topla, sonra burada sat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FarmColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Görünürlük değiştiğinde yüksekliği yumuşakça açılıp kapanan kutu.
class _Collapsible extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _Collapsible({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 350),
      sizeCurve: Curves.easeInOutCubic,
      crossFadeState: visible
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: child,
      secondChild: const SizedBox(width: double.infinity),
    );
  }
}
