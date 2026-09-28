import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../theme.dart';
import 'common.dart';
import 'fx.dart';

/// Gün-gece döngüsüyle renk değiştiren gökyüzü, tepeler ve üstünde oyun göstergeleri.
class SkyHeader extends StatelessWidget {
  const SkyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 132 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Bulutlar kendi döngüsünde kayar; gökyüzü rengi oyun saatinden gelir.
          LoopBuilder(
            period: const Duration(seconds: 90),
            builder: (context, t, _) => CustomPaint(
              painter: _SkyPainter(dayTime: game.dayTime, cloudT: t),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LevelBadge(game: game),
                const SizedBox(width: 10),
                Expanded(child: _DayLabel(game: game)),
                _CoinPill(money: game.money),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final GameState game;
  const _LevelBadge({required this.game});

  @override
  Widget build(BuildContext context) {
    return PulseOnChange(
      notifier: xpPulse,
      child: Container(
        key: xpTargetKey,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: FarmColors.paper,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: game.levelProgress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  backgroundColor: FarmColors.cream,
                  color: FarmColors.straw,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SV',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: FarmColors.inkSoft,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Text(
                    '${game.level}',
                    key: ValueKey(game.level),
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  final GameState game;
  const _DayLabel({required this.game});

  @override
  Widget build(BuildContext context) {
    final minutes = (game.dayTime * 24 * 60).floor();
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = ((minutes % 60) ~/ 10 * 10).toString().padLeft(2, '0');
    final night = game.dayTime < 0.23 || game.dayTime > 0.8;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FARMELO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(seconds: 2),
            style: TextStyle(
              color: night ? const Color(0xFFD8E0FF) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: const [Shadow(color: Color(0x55000000), blurRadius: 4)],
            ),
            child: Text('Gün ${game.dayNumber} · $hh:$mm'),
          ),
        ],
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  final int money;
  const _CoinPill({required this.money});

  @override
  Widget build(BuildContext context) {
    return PulseOnChange(
      notifier: coinPulse,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(
          color: FarmColors.paper,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🪙',
              key: coinTargetKey,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 6),
            AnimatedCount(
              money,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final double dayTime;
  final double cloudT;

  _SkyPainter({required this.dayTime, required this.cloudT});

  // (saat, üst renk, alt renk)
  static const _keys = <(double, Color, Color)>[
    (0.00, Color(0xFF0E1838), Color(0xFF28386A)),
    (0.20, Color(0xFF1D2A5C), Color(0xFF4A4C85)),
    (0.26, Color(0xFF4F63A8), Color(0xFFF4A77E)),
    (0.34, Color(0xFF5FB0EE), Color(0xFFCBE9FF)),
    (0.66, Color(0xFF4FA6EC), Color(0xFFC4E6FF)),
    (0.74, Color(0xFF6A5FA8), Color(0xFFF5976A)),
    (0.82, Color(0xFF1D2A5C), Color(0xFF3E4580)),
    (1.00, Color(0xFF0E1838), Color(0xFF28386A)),
  ];

  (Color, Color) _skyColors() {
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i];
      final b = _keys[i + 1];
      if (dayTime >= a.$1 && dayTime <= b.$1) {
        final t = Curves.easeInOut.transform((dayTime - a.$1) / (b.$1 - a.$1));
        return (Color.lerp(a.$2, b.$2, t)!, Color.lerp(a.$3, b.$3, t)!);
      }
    }
    return (_keys.first.$2, _keys.first.$3);
  }

  /// 0 gündüz, 1 gece.
  double get _darkness {
    final sun = sin((dayTime - 0.25) * 2 * pi); // öğlen 1, gece yarısı -1
    return (0.5 - sun * 2).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (topC, bottomC) = _skyColors();
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topC, bottomC],
        ).createShader(rect),
    );

    final dark = _darkness;
    _paintStars(canvas, size, dark);
    _paintSunAndMoon(canvas, size);
    _paintClouds(canvas, size, dark);
    _paintHills(canvas, size, dark);
  }

  void _paintStars(Canvas canvas, Size size, double dark) {
    if (dark <= 0) return;
    final rng = Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85 * dark);
    for (var i = 0; i < 40; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.7,
      );
      final twinkle = 0.6 + 0.4 * sin(cloudT * 2 * pi * 12 + i);
      canvas.drawCircle(p, (0.6 + rng.nextDouble()) * twinkle, paint);
    }
  }

  void _paintSunAndMoon(Canvas canvas, Size size) {
    // Güneş 0.22–0.78 arasında gökyüzünde bir yay çizer; ay kalan zamanda.
    void body(double progress, Color color, double r, {bool moon = false}) {
      final x = size.width * (0.1 + 0.8 * progress);
      final y = size.height * 0.85 - sin(progress * pi) * size.height * 0.6;
      final c = Offset(x, y);
      canvas.drawCircle(
        c,
        r * 2.2,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(c, r, Paint()..color = color);
      if (moon) {
        final (topC, _) = _skyColors();
        canvas.drawCircle(
          c + Offset(r * 0.45, -r * 0.2),
          r * 0.85,
          Paint()..color = topC,
        );
      }
    }

    if (dayTime > 0.2 && dayTime < 0.8) {
      body((dayTime - 0.2) / 0.6, const Color(0xFFFFD54A), 16);
    } else {
      final p = dayTime >= 0.8 ? (dayTime - 0.8) / 0.4 : (dayTime + 0.2) / 0.4;
      body(p, const Color(0xFFF3F1E0), 12, moon: true);
    }
  }

  void _paintClouds(Canvas canvas, Size size, double dark) {
    final paint = Paint()
      ..color = Color.lerp(
        Colors.white,
        const Color(0xFF8E97C2),
        dark,
      )!.withValues(alpha: 0.9 - dark * 0.3);
    const clouds = [(0.0, 0.32, 1.0), (0.38, 0.18, 0.7), (0.7, 0.45, 0.85)];
    final span = size.width + 160;
    for (final (offset, y, s) in clouds) {
      final x = ((cloudT + offset) % 1.0) * span - 80;
      final c = Offset(x, size.height * y);
      canvas.drawCircle(c, 14 * s, paint);
      canvas.drawCircle(c + Offset(16 * s, -8 * s), 18 * s, paint);
      canvas.drawCircle(c + Offset(34 * s, 0), 13 * s, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - 8 * s, c.dy, 52 * s, 13 * s),
          Radius.circular(8 * s),
        ),
        paint,
      );
    }
  }

  void _paintHills(Canvas canvas, Size size, double dark) {
    const night = Color(0xFF1B2A40);
    final far = Color.lerp(const Color(0xFF9CCB6A), night, dark * 0.7)!;
    final near = Color.lerp(FarmColors.grass, night, dark * 0.7)!;
    final w = size.width;
    final h = size.height;

    final back = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.25, h * 0.6, w * 0.5, h * 0.78)
      ..quadraticBezierTo(w * 0.78, h * 0.92, w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = far);

    // Sağ tepedeki ambar.
    final barnC = Color.lerp(FarmColors.barnRed, night, dark * 0.6)!;
    final bx = w * 0.8;
    final by = h * 0.74;
    canvas.drawRect(Rect.fromLTWH(bx, by, 28, 18), Paint()..color = barnC);
    canvas.drawPath(
      Path()
        ..moveTo(bx - 3, by)
        ..lineTo(bx + 14, by - 12)
        ..lineTo(bx + 31, by)
        ..close(),
      Paint()..color = Color.lerp(barnC, Colors.black, 0.25)!,
    );
    canvas.drawRect(
      Rect.fromLTWH(bx + 10, by + 7, 8, 11),
      // Gece ambar kapısından ışık sızar.
      Paint()
        ..color = Color.lerp(
          const Color(0xFF5A2A1E),
          const Color(0xFFFFD66B),
          dark,
        )!,
    );

    final front = Path()
      ..moveTo(0, h * 0.9)
      ..quadraticBezierTo(w * 0.35, h * 0.78, w * 0.62, h * 0.92)
      ..quadraticBezierTo(w * 0.85, h * 1.02, w, h * 0.88)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = near);
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.dayTime != dayTime || old.cloudT != cloudT;
}
