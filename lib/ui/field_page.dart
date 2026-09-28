import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/data.dart';
import '../game/game_state.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/fx.dart';

class FieldPage extends StatelessWidget {
  const FieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final seed = GameData.crop(game.lastSeed);
    final itemCount = game.plots.length + (game.canBuyPlot ? 1 : 0);

    return Column(
      children: [
        _Toolbar(
          children: [
            FarmButton(
              compact: true,
              emoji: '🧺',
              label: 'Hasat (${game.readyPlotCount})',
              onTap: game.readyPlotCount == 0
                  ? null
                  : (pos) => _harvestAll(context, pos),
            ),
            FarmButton(
              compact: true,
              emoji: '💧',
              label: 'Sula (${game.dryPlotCount})',
              color: FarmColors.water,
              onTap: game.dryPlotCount == 0
                  ? null
                  : (pos) {
                      final n = game.waterAll();
                      Sfx.play(Sound.water);
                      Fx.floatText(context, pos, '💧 ×$n', color: Colors.white);
                    },
            ),
            FarmButton(
              compact: true,
              emoji: seed.emoji,
              label: 'Hepsine ek',
              color: FarmColors.wood,
              onTap: game.emptyPlotCount == 0
                  ? null
                  : (pos) {
                      final before = game.money;
                      final n = game.plantAll(seed.id);
                      if (n > 0) Sfx.play(Sound.plant);
                      if (n > 0) {
                        Fx.floatText(
                          context,
                          pos,
                          '-${before - game.money} 🪙',
                          color: const Color(0xFFFFD0C0),
                        );
                      }
                    },
            ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
            ),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (i == game.plots.length) {
                return _BuyPlotTile(key: ValueKey('buy-$i'));
              }
              return _AppearIn(
                key: ValueKey('plot-$i'),
                child: PlotTile(index: i),
              );
            },
          ),
        ),
      ],
    );
  }

  void _harvestAll(BuildContext context, Offset pos) {
    final game = GameScope.read(context);
    final crops = <String>{
      for (final p in game.plots)
        if (p.isReady) p.crop!.emoji,
    };
    final n = game.harvestAll();
    Sfx.play(Sound.harvest);
    if (n == 0) return;
    Fx.floatText(context, pos, '+$n ürün', color: Colors.white);
    for (final e in crops) {
      Fx.flyTo(context, pos, barnTargetKey, e, count: 3, pulse: barnPulse);
    }
    Fx.flyTo(context, pos, xpTargetKey, '⭐', count: 2, pulse: xpPulse);
  }
}

class _Toolbar extends StatelessWidget {
  final List<Widget> children;
  const _Toolbar({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          for (final c in children) ...[c, const SizedBox(width: 10)],
        ],
      ),
    );
  }
}

/// Yeni eklenen karoların büyüyerek belirmesi için.
class _AppearIn extends StatelessWidget {
  final Widget child;
  const _AppearIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
      ),
      child: child,
    );
  }
}

class PlotTile extends StatelessWidget {
  final int index;
  const PlotTile({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final plot = game.plots[index];

    final soilTop = plot.watered ? FarmColors.soilWet : FarmColors.soil;
    final soilBottom = plot.watered
        ? const Color(0xFF3E2418)
        : FarmColors.soilDark;

    return Pressable(
      onTap: (pos) => _onTap(context, pos),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [soilTop, soilBottom],
          ),
          border: Border.all(
            color: plot.isReady ? FarmColors.straw : FarmColors.woodDark,
            width: plot.isReady ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: plot.isReady
                  ? FarmColors.straw.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.18),
              blurRadius: plot.isReady ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _FurrowPainter(plot.watered)),
                ),
                Positioned.fill(
                  bottom: 26,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: a,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                    child: _PlotContent(
                      key: ValueKey(_stageKey(plot)),
                      plot: plot,
                      index: index,
                      size: box.biggest,
                    ),
                  ),
                ),
                // Sulandı rozeti
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedScale(
                    scale: plot.watered && plot.isGrowing ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    child: const Text('💧', style: TextStyle(fontSize: 16)),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: _PlotFooter(plot: plot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stageKey(Plot p) {
    if (p.isEmpty) return 'empty';
    if (p.isReady) return '${p.cropId}-ready';
    return '${p.cropId}-${_stage(p.progress)}';
  }

  void _onTap(BuildContext context, Offset pos) {
    final game = GameScope.read(context);
    final plot = game.plots[index];
    if (plot.isEmpty) {
      showSeedSheet(context, index, pos);
    } else if (plot.isReady) {
      final crop = plot.crop!;
      final n = game.harvest(index);
      Sfx.play(Sound.harvest);
      Fx.floatText(context, pos, '+$n ${crop.emoji}');
      Fx.flyTo(
        context,
        pos,
        barnTargetKey,
        crop.emoji,
        count: n,
        pulse: barnPulse,
      );
      Fx.flyTo(context, pos, xpTargetKey, '⭐', count: 1, pulse: xpPulse);
    } else if (!plot.watered) {
      game.water(index);
      Sfx.play(Sound.water);
      Fx.floatText(context, pos, '💧 Sulandı', color: const Color(0xFFD6F0FF));
    } else {
      Fx.floatText(
        context,
        pos,
        '⏳ ${formatSeconds(plot.secondsLeft)}',
        fontSize: 16,
      );
    }
  }
}

int _stage(double progress) => progress < 0.34 ? 0 : (progress < 0.7 ? 1 : 2);

class _PlotContent extends StatelessWidget {
  final Plot plot;
  final int index;
  final Size size;

  const _PlotContent({
    super.key,
    required this.plot,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (plot.isEmpty) {
      return Center(
        child: LoopBuilder(
          period: const Duration(milliseconds: 2200),
          phase: index * 0.13,
          builder: (context, t, child) =>
              Opacity(opacity: 0.45 + 0.25 * sin(t * 2 * pi), child: child),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: FarmColors.cream, size: 30),
              Text(
                'Ek',
                style: TextStyle(
                  color: FarmColors.cream,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final crop = plot.crop!;
    final ready = plot.isReady;
    final stage = ready ? 3 : _stage(plot.progress);
    final emoji = switch (stage) {
      0 => '🌱',
      1 => '🌿',
      _ => crop.emoji,
    };
    final base =
        size.width *
        (switch (stage) {
          0 => 0.18,
          1 => 0.22,
          2 => 0.2,
          _ => 0.26,
        });

    // Üç bitki üçgen düzende; her biri farklı fazda rüzgârda sallanır.
    const spots = [Offset(0.28, 0.36), Offset(0.72, 0.36), Offset(0.5, 0.68)];
    final h = size.height - 26;
    return Stack(
      children: [
        for (var i = 0; i < spots.length; i++)
          Positioned(
            left: spots[i].dx * size.width - base,
            top: spots[i].dy * h - base * 1.2,
            width: base * 2,
            height: base * 2,
            child: _SwayingPlant(
              emoji: emoji,
              fontSize: base * 1.25,
              phase: index * 0.21 + i * 0.33,
              ready: ready,
            ),
          ),
        if (ready)
          Positioned.fill(
            child: IgnorePointer(child: _Sparkles(phase: index * 0.17)),
          ),
      ],
    );
  }
}

class _SwayingPlant extends StatelessWidget {
  final String emoji;
  final double fontSize;
  final double phase;
  final bool ready;

  const _SwayingPlant({
    required this.emoji,
    required this.fontSize,
    required this.phase,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    return LoopBuilder(
      period: Duration(milliseconds: ready ? 1100 : 2600),
      phase: phase,
      child: FittedBox(
        child: Text(emoji, style: TextStyle(fontSize: fontSize)),
      ),
      builder: (context, t, child) {
        final wave = sin(t * 2 * pi);
        final hop = ready ? max(0.0, sin(t * 2 * pi)) * 5 : 0.0;
        return Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.rotate(
            angle: wave * (ready ? 0.1 : 0.07),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );
  }
}

class _Sparkles extends StatelessWidget {
  final double phase;
  const _Sparkles({required this.phase});

  @override
  Widget build(BuildContext context) {
    return LoopBuilder(
      period: const Duration(milliseconds: 1800),
      phase: phase,
      builder: (context, t, _) => CustomPaint(painter: _SparklePainter(t)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double t;
  _SparklePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const spots = [
      Offset(0.15, 0.2),
      Offset(0.85, 0.28),
      Offset(0.5, 0.12),
      Offset(0.2, 0.7),
      Offset(0.82, 0.66),
    ];
    for (var i = 0; i < spots.length; i++) {
      final local = (t + i / spots.length) % 1.0;
      final a = sin(local * pi);
      final r = 2.5 + 3.5 * a;
      final c = Offset(spots[i].dx * size.width, spots[i].dy * size.height);
      final paint = Paint()
        ..color = const Color(0xFFFFF3B0).withValues(alpha: a);
      // Dört köşeli yıldız
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

class _PlotFooter extends StatelessWidget {
  final Plot plot;
  const _PlotFooter({required this.plot});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (plot.isEmpty) {
      child = const SizedBox(key: ValueKey('none'), height: 14);
    } else if (plot.isReady) {
      child = LoopBuilder(
        key: const ValueKey('ready'),
        period: const Duration(milliseconds: 900),
        builder: (context, t, child) =>
            Transform.scale(scale: 1 + 0.06 * sin(t * 2 * pi), child: child),
        child: Container(
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FarmColors.straw,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'HASAT ET',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
              color: FarmColors.ink,
            ),
          ),
        ),
      );
    } else {
      child = Column(
        key: const ValueKey('grow'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothBar(
            value: plot.progress,
            height: 6,
            color: plot.watered ? const Color(0xFF7FD3FF) : FarmColors.meadow,
            background: Colors.black.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 2),
          Text(
            formatSeconds(plot.secondsLeft),
            style: const TextStyle(
              fontSize: 10,
              color: FarmColors.cream,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
    );
  }
}

class _FurrowPainter extends CustomPainter {
  final bool wet;
  _FurrowPainter(this.wet);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: wet ? 0.22 : 0.14)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), paint);
    }
    // Birkaç küçük taş
    final rng = Random(3);
    final stone = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        1.5 + rng.nextDouble() * 1.5,
        stone,
      );
    }
  }

  @override
  bool shouldRepaint(_FurrowPainter old) => old.wet != wet;
}

class _BuyPlotTile extends StatelessWidget {
  const _BuyPlotTile({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final price = game.nextPlotPrice;
    final affordable = game.money >= price;
    return Pressable(
      onTap: (pos) {
        if (game.buyPlot()) {
          Sfx.play(Sound.buy);
          Fx.floatText(
            context,
            pos,
            '-$price 🪙',
            color: const Color(0xFFFFD0C0),
          );
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: affordable ? 1 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            color: FarmColors.paper.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FarmColors.wood, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚜', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              const Text(
                'Yeni tarla',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$price 🪙',
                style: const TextStyle(
                  color: FarmColors.inkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Tohum seçimi

void showSeedSheet(BuildContext context, int plotIndex, Offset plotPos) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SeedSheet(
      plotIndex: plotIndex,
      plotPos: plotPos,
      hostContext: context,
    ),
  );
}

class _SeedSheet extends StatelessWidget {
  final int plotIndex;
  final Offset plotPos;
  final BuildContext hostContext;

  const _SeedSheet({
    required this.plotIndex,
    required this.plotPos,
    required this.hostContext,
  });

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return SheetFrame(
      title: 'Ne ekelim?',
      subtitle: 'Sulanan tarlalar ${GameData.waterBoost}× hızlı büyür',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 190,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 170,
        ),
        itemCount: GameData.crops.length,
        itemBuilder: (context, i) {
          final crop = GameData.crops[i];
          final locked = crop.unlockLevel > game.level;
          final affordable = game.money >= crop.seedCost;
          final price = game.priceOf(crop.id);
          return StaggerIn(
            index: i,
            child: Pressable(
              onTap: locked
                  ? null
                  : (_) {
                      if (game.plant(plotIndex, crop.id)) {
                        Sfx.play(Sound.plant);
                        Navigator.pop(context);
                        Fx.floatText(
                          hostContext,
                          plotPos,
                          '-${crop.seedCost} 🪙',
                          color: const Color(0xFFFFD0C0),
                        );
                      }
                    },
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: locked ? 0.45 : (affordable ? 1 : 0.7),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: crop.id == game.lastSeed && !locked
                          ? FarmColors.grassDark
                          : FarmColors.cream,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        locked ? '🔒' : crop.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        crop.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      if (locked)
                        Text(
                          'Seviye ${crop.unlockLevel}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: FarmColors.inkSoft,
                          ),
                        )
                      else ...[
                        _Info('Tohum', '${crop.seedCost} 🪙'),
                        _Info('Süre', formatSeconds(crop.growSeconds)),
                        _Info('Hasat', '${crop.yieldAmount} × $price 🪙'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: FarmColors.inkSoft),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
