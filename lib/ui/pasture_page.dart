import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/data.dart';
import '../game/game_state.dart';
import 'theme.dart';
import 'widgets/animal_figure.dart';
import 'widgets/common.dart';
import 'widgets/fx.dart';

class PasturePage extends StatelessWidget {
  final VoidCallback onGoShop;
  const PasturePage({super.key, required this.onGoShop});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final hungry = game.animals.where((a) => a.fullness <= 0.9).length;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              FarmButton(
                compact: true,
                emoji: '🧺',
                label: 'Topla (${game.readyAnimalCount})',
                onTap: game.readyAnimalCount == 0
                    ? null
                    : (pos) => _collectAll(context, pos),
              ),
              const SizedBox(width: 10),
              FarmButton(
                compact: true,
                emoji: '🌿',
                label: 'Besle · yem ${game.feedCount}',
                color: FarmColors.wood,
                onTap: hungry == 0
                    ? null
                    : (pos) {
                        final n = game.feedAll();
                        if (n > 0) {
                          Sfx.play(Sound.eat);
                          Fx.floatText(context, pos, '😋 ×$n');
                        }
                      },
              ),
              const SizedBox(width: 10),
              _CapacityChip(used: game.animals.length, max: game.capacity),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _Meadow(onGoShop: onGoShop),
          ),
        ),
      ],
    );
  }

  void _collectAll(BuildContext context, Offset pos) {
    final game = GameScope.read(context);
    final products = <String>{
      for (final a in game.animals)
        if (a.productReady) GameData.item(a.def.productId).emoji,
    };
    final n = game.collectAll();
    Sfx.play(Sound.harvest);
    Fx.floatText(context, pos, '+$n ürün');
    for (final e in products) {
      Fx.flyTo(context, pos, barnTargetKey, e, count: 3, pulse: barnPulse);
    }
    Fx.flyTo(context, pos, xpTargetKey, '⭐', count: 2, pulse: xpPulse);
  }
}

class _CapacityChip extends StatelessWidget {
  final int used;
  final int max;
  const _CapacityChip({required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final full = used >= max;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: full ? const Color(0xFFFBE3DC) : FarmColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: full ? FarmColors.down : FarmColors.cream),
      ),
      child: Text(
        'Mera $used/$max',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: full ? FarmColors.down : FarmColors.ink,
        ),
      ),
    );
  }
}

class _Meadow extends StatelessWidget {
  final VoidCallback onGoShop;
  const _Meadow({required this.onGoShop});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    // Aşağıdaki hayvan öndeki gibi görünsün diye y'ye göre sırala.
    final sorted = [...game.animals]..sort((a, b) => a.y.compareTo(b.y));
    final night = game.dayTime < 0.23 || game.dayTime > 0.8;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: FarmColors.woodDark, width: 5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final spriteSize = (min(w, h) * 0.2).clamp(52.0, 84.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: LoopBuilder(
                    period: const Duration(seconds: 6),
                    builder: (context, t, _) =>
                        CustomPaint(painter: _MeadowPainter(t)),
                  ),
                ),
                // Gece olunca mera hafifçe kararır.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 3),
                      color: night
                          ? const Color(0xFF14204A).withValues(alpha: 0.28)
                          : Colors.transparent,
                    ),
                  ),
                ),
                for (final a in sorted)
                  _AnimalSprite(
                    key: ValueKey(a.id),
                    animal: a,
                    area: Size(w, h),
                    size: spriteSize,
                    night: night,
                    walking: a.isWalking(game.elapsed),
                  ),
                if (game.animals.isEmpty)
                  Center(
                    child: StaggerIn(
                      index: 0,
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: FarmColors.paper.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🐣', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            const Text(
                              'Meran boş',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Yavru hayvan al, besleyip büyüt.\nSüt, yumurta ve yün topla ya da et olarak sat.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FarmColors.inkSoft),
                            ),
                            const SizedBox(height: 14),
                            FarmButton(
                              emoji: '🏪',
                              label: 'Mağazaya git',
                              onTap: (_) => onGoShop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimalSprite extends StatelessWidget {
  final Animal animal;
  final Size area;
  final double size;
  final bool night;
  final bool walking;

  const _AnimalSprite({
    super.key,
    required this.animal,
    required this.area,
    required this.size,
    required this.night,
    required this.walking,
  });

  @override
  Widget build(BuildContext context) {
    final a = animal;
    final bubbleH = size * 0.5;
    final totalH = size + bubbleH;
    return AnimatedPositioned(
      duration: Duration(milliseconds: max(a.moveMs, 300)),
      curve: Curves.easeInOutSine,
      left: a.x * (area.width - size),
      top: a.y * (area.height - totalH),
      width: size,
      height: totalH,
      child: Pressable(
        onTap: (pos) => _onTap(context, pos),
        onLongPress: () => showAnimalSheet(context, a.id),
        child: Column(
          children: [
            SizedBox(
              height: bubbleH,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: _bubble(a),
              ),
            ),
            SizedBox(
              height: size,
              child: AnimatedScale(
                scale: 0.55 + 0.45 * a.growth,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Gölge
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: size * 0.7,
                        height: size * 0.14,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(size * 0.35, size * 0.07),
                          ),
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: a.facingRight ? 1 : -1),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      builder: (context, flip, child) => Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(flip, 1, 1),
                        child: child,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                        child: AnimalFigure(
                          key: ValueKey(a.isAdult),
                          typeId: a.typeId,
                          baby: !a.isAdult,
                          walking: walking,
                          size: size,
                          phase: a.id * 0.29,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Animal a) {
    if (a.productReady) {
      return _Bubble(
        key: const ValueKey('ready'),
        emoji: GameData.item(a.def.productId).emoji,
        color: Colors.white,
        size: size,
        bounce: true,
      );
    }
    if (a.hungry) {
      return _Bubble(
        key: const ValueKey('hungry'),
        emoji: '🌾',
        color: const Color(0xFFFFE1D6),
        size: size,
        bounce: a.starving,
      );
    }
    if (night) {
      return LoopBuilder(
        key: const ValueKey('sleep'),
        period: const Duration(seconds: 2),
        phase: a.id * 0.3,
        builder: (context, t, child) => Opacity(
          opacity: sin(t * pi),
          child: Transform.translate(
            offset: Offset(size * 0.2, -t * 8),
            child: child,
          ),
        ),
        child: Text('💤', style: TextStyle(fontSize: size * 0.24)),
      );
    }
    return const SizedBox(key: ValueKey('none'));
  }

  void _onTap(BuildContext context, Offset pos) {
    final game = GameScope.read(context);
    final a = animal;
    if (a.productReady) {
      final item = GameData.item(a.def.productId);
      game.collect(a);
      Sfx.voice(a.typeId, adult: true);
      Sfx.play(Sound.harvest, volume: 0.6);
      Fx.floatText(context, pos, '+1 ${item.emoji}');
      Fx.flyTo(
        context,
        pos,
        barnTargetKey,
        item.emoji,
        count: 1,
        pulse: barnPulse,
      );
      Fx.flyTo(context, pos, xpTargetKey, '⭐', count: 1, pulse: xpPulse);
    } else if (a.hungry) {
      final used = game.feed(a);
      if (used != null) {
        Sfx.play(Sound.eat);
        Fx.floatText(context, pos, '$used → 😋');
      }
    } else {
      Sfx.voice(a.typeId, adult: a.isAdult);
      showAnimalSheet(context, a.id);
    }
  }
}

class _Bubble extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;
  final bool bounce;

  const _Bubble({
    super.key,
    required this.emoji,
    required this.color,
    required this.size,
    required this.bounce,
  });

  @override
  Widget build(BuildContext context) {
    final d = size * 0.46;
    return LoopBuilder(
      period: const Duration(milliseconds: 900),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(
          0,
          bounce ? -sin(t * pi).abs() * 5 : sin(t * 2 * pi) * 1.5,
        ),
        child: child,
      ),
      child: Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(emoji, style: TextStyle(fontSize: d * 0.58)),
      ),
    );
  }
}

class _MeadowPainter extends CustomPainter {
  final double t;
  _MeadowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FarmColors.meadow, FarmColors.grass],
        ).createShader(rect),
    );

    // Gölet
    final pond = Rect.fromLTWH(
      size.width * 0.62,
      size.height * 0.06,
      size.width * 0.32,
      size.height * 0.14,
    );
    canvas.drawOval(pond.inflate(4), Paint()..color = const Color(0xFF6E9E4A));
    canvas.drawOval(pond, Paint()..color = const Color(0xFF6CC0E8));
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: 0.5 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: pond.center,
        width: pond.width * 0.3 * (0.4 + t),
        height: pond.height * 0.3 * (0.4 + t),
      ),
      ripple,
    );

    // Rüzgârda eğilen ot öbekleri ve çiçekler
    final rng = Random(11);
    final blade = Paint()
      ..color = FarmColors.grassDark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 38; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      if (pond.inflate(8).contains(p)) continue;
      final sway = sin((t + p.dx / size.width) * 2 * pi) * 3;
      for (final dx in [-4.0, 0.0, 4.0]) {
        canvas.drawLine(
          p + Offset(dx, 0),
          p + Offset(dx * 1.5 + sway, -9),
          blade,
        );
      }
    }
    const petals = [Color(0xFFFFFFFF), Color(0xFFFFE066), Color(0xFFFF9EB5)];
    for (var i = 0; i < 16; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      if (pond.inflate(8).contains(p)) continue;
      canvas.drawCircle(p, 3, Paint()..color = petals[i % petals.length]);
      canvas.drawCircle(p, 1.3, Paint()..color = const Color(0xFFF2A93B));
    }

    // Yem teknesi
    final trough = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.06, size.height * 0.08, 64, 18),
      const Radius.circular(5),
    );
    canvas.drawRRect(trough, Paint()..color = FarmColors.woodDark);
    canvas.drawRRect(trough.deflate(4), Paint()..color = FarmColors.straw);
  }

  @override
  bool shouldRepaint(_MeadowPainter old) => old.t != t;
}

// ---------------------------------------------------------------- Detay paneli

void showAnimalSheet(BuildContext context, int animalId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AnimalSheet(animalId: animalId),
  );
}

class _AnimalSheet extends StatelessWidget {
  final int animalId;
  const _AnimalSheet({required this.animalId});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final a = game.animals.where((x) => x.id == animalId).firstOrNull;
    if (a == null) return const SizedBox.shrink();
    final def = a.def;
    final product = GameData.item(def.productId);
    final meat = GameData.item(def.meatId);
    final meatValue = game.priceOf(def.meatId) * def.meatAmount;

    return SheetFrame(
      title: '${a.displayName} #${a.id}',
      subtitle: a.isAdult
          ? '${product.name} verir · kesilirse ${def.meatAmount} ${meat.name}'
          : 'Besledikçe büyür, sonra ${product.name.toLowerCase()} verir',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [FarmColors.meadow, FarmColors.grass],
                ),
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (c, an) =>
                    ScaleTransition(scale: an, child: c),
                child: AnimalFigure(
                  key: ValueKey(a.isAdult),
                  typeId: a.typeId,
                  baby: !a.isAdult,
                  size: 88,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (!a.isAdult)
            _StatRow(
              label: 'Büyüme',
              value: a.growth,
              color: FarmColors.straw,
              trailing: a.starving
                  ? 'Aç, büyümüyor'
                  : '${formatSeconds((1 - a.growth) * def.growSeconds)} kaldı',
            ),
          _StatRow(
            label: 'Tokluk',
            value: a.fullness,
            color: a.hungry ? FarmColors.down : FarmColors.grassDark,
            trailing: a.starving ? 'Çok aç!' : '%${(a.fullness * 100).round()}',
          ),
          if (a.isAdult)
            _StatRow(
              label: '${product.emoji} ${product.name}',
              value: a.production,
              color: FarmColors.water,
              trailing: a.productReady
                  ? 'Hazır'
                  : a.starving
                  ? 'Aç, üretmiyor'
                  : '${formatSeconds((1 - a.production) * def.produceSeconds)} kaldı',
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FarmButton(
                emoji: '🌿',
                label: 'Besle (${game.feedCount})',
                color: FarmColors.wood,
                onTap: a.fullness > 0.9
                    ? null
                    : (pos) {
                        final used = game.feed(a);
                        if (used != null) {
                          Sfx.play(Sound.eat);
                          Fx.floatText(context, pos, '$used → 😋');
                        }
                      },
              ),
              if (a.isAdult)
                FarmButton(
                  emoji: product.emoji,
                  label: 'Topla',
                  onTap: !a.productReady
                      ? null
                      : (pos) {
                          game.collect(a);
                          Sfx.voice(a.typeId, adult: true);
                          Sfx.play(Sound.harvest, volume: 0.6);
                          Fx.floatText(context, pos, '+1 ${product.emoji}');
                          Fx.flyTo(
                            context,
                            pos,
                            barnTargetKey,
                            product.emoji,
                            count: 1,
                            pulse: barnPulse,
                          );
                        },
                ),
              if (a.isAdult)
                _SlaughterButton(
                  label: '${meat.emoji} ×${def.meatAmount} · ~$meatValue 🪙',
                  onConfirm: (pos) {
                    Sfx.play(Sound.plant);
                    Sfx.play(Sound.harvest, volume: 0.7);
                    Fx.floatText(
                      context,
                      pos,
                      '+${def.meatAmount} ${meat.emoji}',
                    );
                    Fx.flyTo(
                      context,
                      pos,
                      barnTargetKey,
                      meat.emoji,
                      count: def.meatAmount,
                      pulse: barnPulse,
                    );
                    Fx.flyTo(
                      context,
                      pos,
                      xpTargetKey,
                      '⭐',
                      count: 2,
                      pulse: xpPulse,
                    );
                    Navigator.pop(context);
                    // Panel kapanırken içeriği boşalmasın diye hayvanı biraz sonra çıkar.
                    Future.delayed(
                      const Duration(milliseconds: 300),
                      () => game.slaughter(a),
                    );
                  },
                ),
            ],
          ),
          if (!a.isAdult) ...[
            const SizedBox(height: 12),
            const Text(
              'Yavrular yetişkin olunca et olarak satılabilir.',
              style: TextStyle(color: FarmColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String trailing;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                trailing,
                style: const TextStyle(
                  color: FarmColors.inkSoft,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SmoothBar(value: value, color: color, height: 10),
        ],
      ),
    );
  }
}

/// İlk dokunuşta onay ister, üç saniye içinde ikinci dokunuşta işlemi yapar.
class _SlaughterButton extends StatefulWidget {
  final String label;
  final void Function(Offset pos) onConfirm;

  const _SlaughterButton({required this.label, required this.onConfirm});

  @override
  State<_SlaughterButton> createState() => _SlaughterButtonState();
}

class _SlaughterButtonState extends State<_SlaughterButton> {
  bool _confirming = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, axis: Axis.horizontal, child: c),
      ),
      child: FarmButton(
        key: ValueKey(_confirming),
        label: _confirming
            ? 'Emin misin? Evet, sat'
            : 'Et olarak sat: ${widget.label}',
        color: _confirming ? FarmColors.down : FarmColors.barnRed,
        onTap: (pos) {
          if (_confirming) {
            _timer?.cancel();
            widget.onConfirm(pos);
          } else {
            setState(() => _confirming = true);
            _timer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _confirming = false);
            });
          }
        },
      ),
    );
  }
}
