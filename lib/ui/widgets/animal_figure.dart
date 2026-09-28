import 'dart:math';

import 'package:flutter/material.dart';

import 'common.dart';

/// Bacaklı, yürüyebilen hayvan çizimi. Sağa bakar; sola çevirmek için dışarıdan aynalanır.
class AnimalFigure extends StatelessWidget {
  final String typeId;
  final bool baby;
  final bool walking;
  final double size;
  final double phase;

  const AnimalFigure({
    super.key,
    required this.typeId,
    required this.baby,
    required this.size,
    this.walking = false,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Yürümeye başlarken/dururken adım genliği yumuşakça açılıp kapanır.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: walking ? 1 : 0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, amp, _) => LoopBuilder(
        period: const Duration(milliseconds: 2400),
        phase: phase,
        builder: (context, t, _) => CustomPaint(
          size: Size.square(size),
          painter: AnimalPainter(typeId: typeId, baby: baby, t: t, walk: amp),
        ),
      ),
    );
  }
}

class AnimalPainter extends CustomPainter {
  final String typeId;
  final bool baby;
  final double t; // 0..1, 2,4 sn'lik döngü
  final double walk; // 0 duruyor, 1 yürüyor

  AnimalPainter({
    required this.typeId,
    required this.baby,
    required this.t,
    required this.walk,
  });

  static const _hoof = Color(0xFF4A3B33);

  /// Döngü başına adım sayısı: küçük hayvanlar daha sık adım atar.
  int get _steps => switch (typeId) {
    'tavuk' => baby ? 10 : 8,
    'koyun' => 6,
    _ => 5,
  };

  double get _step => (t * _steps) % 1.0;

  /// Bacak açısı (radyan). Çapraz bacaklar aynı fazda hareket eder.
  double get _swing => sin(_step * 2 * pi) * 0.42 * walk;

  /// Yürürken her adımda hafif sekme, dururken yavaş nefes alma.
  double get _bob =>
      -sin(_step * 4 * pi).abs() * 2.2 * walk +
      sin(t * 2 * pi) * 0.7 * (1 - walk);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);
    switch (typeId) {
      case 'inek':
        _cow(canvas);
      case 'koyun':
        _sheep(canvas);
      default:
        baby ? _chick(canvas) : _chicken(canvas);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- Ortak

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Kalçadan sarkan, toynaklı bacak.
  void _leg(
    Canvas c,
    Offset hip,
    double len,
    double w,
    double angle,
    Color color,
    Color hoof,
  ) {
    c.save();
    c.translate(hip.dx, hip.dy);
    c.rotate(angle);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2, 0, w, len),
        Radius.circular(w / 2),
      ),
      _fill(color),
    );
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-w / 2, len - w * 0.8, w, w * 0.8),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      _fill(hoof),
    );
    c.restore();
  }

  /// Dört bacak: uzaktakiler koyu, yakındakiler açık; gövde bunların üstüne çizilir.
  void _fourLegs(
    Canvas c,
    Rect body,
    double hipInset,
    double w,
    Color near,
    Color far,
    Color hoof,
  ) {
    final hipY = body.bottom - hipInset;
    final len = 94 - (hipY - _bob);
    final backX = body.left + body.width * 0.2;
    final frontX = body.right - body.width * 0.2;
    final s = _swing;
    _leg(c, Offset(backX + 6, hipY), len, w, -s, far, hoof);
    _leg(c, Offset(frontX + 6, hipY), len, w, s, far, hoof);
    _leg(c, Offset(backX, hipY), len, w, s, near, hoof);
    _leg(c, Offset(frontX, hipY), len, w, -s, near, hoof);
  }

  void _eye(Canvas c, Offset p, double r) {
    c.drawCircle(p, r, _fill(const Color(0xFF1E1A18)));
    c.drawCircle(
      p + Offset(-r * 0.3, -r * 0.35),
      r * 0.35,
      _fill(Colors.white),
    );
  }

  // ---------------------------------------------------------------- İnek

  void _cow(Canvas c) {
    final body = baby
        ? Rect.fromLTWH(24, 42 + _bob, 44, 24)
        : Rect.fromLTWH(12, 36 + _bob, 64, 30);
    final bodyCol = baby ? const Color(0xFFD9A06B) : const Color(0xFFFBF8F1);
    final spotCol = baby ? const Color(0xFFFFF3E2) : const Color(0xFF2F2A27);
    final line = Color.lerp(bodyCol, Colors.black, 0.25)!;

    _fourLegs(
      c,
      body,
      6,
      baby ? 6.5 : 8,
      Color.lerp(bodyCol, Colors.black, 0.06)!,
      Color.lerp(bodyCol, Colors.black, 0.28)!,
      _hoof,
    );

    // Kuyruk
    final tailBase = Offset(body.left + 2, body.top + 6);
    final tailEnd = tailBase + Offset(-6 + _swing * 6, 24);
    c.drawPath(
      Path()
        ..moveTo(tailBase.dx, tailBase.dy)
        ..quadraticBezierTo(
          tailBase.dx - 8,
          tailBase.dy + 8,
          tailEnd.dx,
          tailEnd.dy,
        ),
      _stroke(line, 2.5),
    );
    c.drawCircle(tailEnd, 3, _fill(const Color(0xFF3A302B)));

    // Gövde ve benekler
    final rr = RRect.fromRectAndRadius(
      body,
      Radius.circular(body.height * 0.48),
    );
    c.drawRRect(rr, _fill(bodyCol));
    c.save();
    c.clipRRect(rr);
    final w = body.width;
    final h = body.height;
    c.drawOval(
      Rect.fromLTWH(body.left + w * 0.18, body.top - 2, w * 0.24, h * 0.55),
      _fill(spotCol),
    );
    c.drawOval(
      Rect.fromLTWH(body.left + w * 0.55, body.top + h * 0.4, w * 0.2, h * 0.4),
      _fill(spotCol),
    );
    c.drawOval(
      Rect.fromLTWH(body.left - 4, body.top + h * 0.5, w * 0.16, h * 0.4),
      _fill(spotCol),
    );
    c.restore();
    c.drawRRect(rr, _stroke(line, 1.2));

    // Meme
    if (!baby) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(body.left + w * 0.42, body.bottom + 1),
          width: 12,
          height: 8,
        ),
        _fill(const Color(0xFFF2B0A4)),
      );
    }

    // Baş: yürürken adımla hafifçe iner kalkar.
    final hs = baby ? 1.05 : 1.0;
    final head = Offset(
      body.right + 6 * hs,
      body.top + 2 + sin(_step * 2 * pi) * 1.2 * walk,
    );
    c.save();
    c.translate(head.dx, head.dy);
    c.scale(hs);
    // Kulak
    c.save();
    c.translate(-9, -8);
    c.rotate(-0.5);
    c.drawOval(
      const Rect.fromLTWH(-6, -3, 12, 6),
      _fill(Color.lerp(bodyCol, Colors.black, 0.2)!),
    );
    c.restore();
    // Boynuz
    if (!baby) {
      c.drawLine(
        const Offset(-3, -9),
        const Offset(-5, -15),
        _stroke(const Color(0xFFEDE3C8), 3),
      );
      c.drawLine(
        const Offset(3, -9),
        const Offset(4, -15),
        _stroke(const Color(0xFFEDE3C8), 3),
      );
    }
    final face = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -10, 21, 20),
      const Radius.circular(9),
    );
    c.drawRRect(face, _fill(bodyCol));
    c.drawRRect(face, _stroke(line, 1.2));
    final snout = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, 14, 11),
      const Radius.circular(5),
    );
    c.drawRRect(snout, _fill(const Color(0xFFF2B5A7)));
    c.drawCircle(const Offset(8, 5), 1.2, _fill(const Color(0xFF9C5A4E)));
    c.drawCircle(const Offset(12, 5), 1.2, _fill(const Color(0xFF9C5A4E)));
    _eye(c, const Offset(0, -3), 2.2);
    c.restore();
  }

  // ---------------------------------------------------------------- Koyun

  void _sheep(Canvas c) {
    final body = baby
        ? Rect.fromLTWH(24, 44 + _bob, 42, 22)
        : Rect.fromLTWH(16, 38 + _bob, 60, 28);
    const wool = Color(0xFFF6F1E4);
    const woolLine = Color(0xFFCFC5AE);
    const skin = Color(0xFF3D3632);

    _fourLegs(
      c,
      body,
      4,
      baby ? 5 : 6,
      skin,
      const Color(0xFF221D1A),
      const Color(0xFF15110F),
    );

    // Yün: kenarlarda kabarık daireler; önce kontur, sonra dolgu.
    final puffs = <(Offset, double)>[];
    final n = baby ? 4 : 6;
    for (var i = 0; i <= n; i++) {
      final x = body.left + body.width * i / n;
      puffs.add((Offset(x, body.top + 2), baby ? 7 : 8.5));
      puffs.add((Offset(x, body.bottom - 3), baby ? 6 : 7.5));
    }
    puffs.add((Offset(body.left - 2, body.center.dy), baby ? 7 : 9));
    puffs.add((Offset(body.left + 2, body.top + 4), 6)); // kuyruk
    final core = RRect.fromRectAndRadius(body, const Radius.circular(12));
    for (final (p, r) in puffs) {
      c.drawCircle(p, r + 1.3, _fill(woolLine));
    }
    c.drawRRect(core.inflate(1.3), _fill(woolLine));
    for (final (p, r) in puffs) {
      c.drawCircle(p, r, _fill(wool));
    }
    c.drawRRect(core, _fill(wool));
    // Yün dokusu
    final curl = _stroke(woolLine.withValues(alpha: 0.7), 1);
    for (var i = 0; i < 5; i++) {
      final p = Offset(
        body.left + body.width * (0.15 + i * 0.17),
        body.center.dy + (i.isEven ? -3 : 4),
      );
      c.drawArc(Rect.fromCircle(center: p, radius: 3), 0.5, 4, false, curl);
    }

    // Baş
    final hs = baby ? 1.1 : 1.0;
    final head = Offset(
      body.right + 3,
      body.top + 8 + sin(_step * 2 * pi) * 1.2 * walk,
    );
    c.save();
    c.translate(head.dx, head.dy);
    c.scale(hs);
    c.rotate(0.35);
    c.save();
    c.translate(-7, -4);
    c.rotate(-0.9);
    c.drawOval(
      const Rect.fromLTWH(-6, -2.5, 12, 5),
      _fill(const Color(0xFF2A2421)),
    );
    c.restore();
    c.drawOval(const Rect.fromLTWH(-7, -9, 15, 20), _fill(skin));
    // Başın üstündeki yün perçemi
    for (final p in const [Offset(-5, -9), Offset(0, -11), Offset(5, -9)]) {
      c.drawCircle(p, 4.5, _fill(woolLine));
      c.drawCircle(p, 3.6, _fill(wool));
    }
    c.drawCircle(const Offset(3, -2), 2.4, _fill(Colors.white));
    _eye(c, const Offset(3.6, -1.8), 1.3);
    c.restore();
  }

  // ---------------------------------------------------------------- Tavuk

  /// Üç parmaklı ince kuş bacağı.
  void _birdLeg(Canvas c, Offset hip, double len, double angle) {
    const color = Color(0xFFE8962E);
    final p = _stroke(color, 2.6);
    c.save();
    c.translate(hip.dx, hip.dy);
    c.rotate(angle);
    c.drawLine(Offset.zero, Offset(0, len), p);
    final foot = Offset(0, len);
    final toe = _stroke(color, 2);
    c.drawLine(foot, foot + const Offset(6, 1), toe);
    c.drawLine(foot, foot + const Offset(4, 3), toe);
    c.drawLine(foot, foot + const Offset(-3, 1.5), toe);
    c.restore();
  }

  void _chicken(Canvas c) {
    final b = _bob;
    // Tavuk yürürken başını ileri geri oynatır.
    final peck = sin(_step * 2 * pi) * 2.5 * walk;
    const white = Color(0xFFFFFDF8);
    const line = Color(0xFFDCD3C3);
    final s = _swing * 1.2;

    final hipY = 70 + b;
    _birdLeg(c, Offset(47, hipY), 94 - hipY - 2, s);
    _birdLeg(c, Offset(55, hipY), 94 - hipY - 2, -s);

    // Kuyruk tüyleri
    for (final a in const [0.35, 0.75, 1.15]) {
      c.save();
      c.translate(32, 52 + b);
      c.rotate(a + pi);
      const f = Rect.fromLTWH(0, -4.5, 20, 9);
      c.drawOval(f.inflate(1.2), _fill(line));
      c.drawOval(f, _fill(white));
      c.restore();
    }

    // Gövde + boyun
    final bodyR = Rect.fromLTWH(28, 44 + b, 46, 30);
    c.drawOval(bodyR.inflate(1.2), _fill(line));
    c.drawCircle(Offset(66 + peck * 0.4, 44 + b), 11.2, _fill(line));
    c.drawOval(bodyR, _fill(white));
    c.drawCircle(Offset(66 + peck * 0.4, 44 + b), 10, _fill(white));

    // Kanat: yürürken hafifçe açılır.
    c.save();
    c.translate(46, 58 + b);
    c.rotate(0.15 - sin(_step * 2 * pi).abs() * 0.15 * walk);
    const wing = Rect.fromLTWH(-12, -7, 24, 14);
    c.drawOval(wing, _fill(const Color(0xFFEDE6D8)));
    c.drawOval(wing, _stroke(line, 1));
    c.restore();

    // Baş
    final h = Offset(71 + peck, 34 + b);
    for (final d in const [Offset(-5, -9), Offset(-1, -11), Offset(3, -9.5)]) {
      c.drawCircle(h + d, 3.8, _fill(const Color(0xFFE0473A)));
    }
    c.drawCircle(h, 10.5, _fill(line));
    c.drawCircle(h, 9.4, _fill(white));
    c.drawPath(
      Path()
        ..moveTo(h.dx + 8, h.dy - 1)
        ..lineTo(h.dx + 16, h.dy + 2)
        ..lineTo(h.dx + 8, h.dy + 5)
        ..close(),
      _fill(const Color(0xFFF2A33A)),
    );
    c.drawOval(
      Rect.fromLTWH(h.dx + 5, h.dy + 5, 5, 8),
      _fill(const Color(0xFFE0473A)),
    );
    _eye(c, h + const Offset(3, -2), 1.9);
  }

  void _chick(Canvas c) {
    final b = _bob;
    final peck = sin(_step * 2 * pi) * 1.5 * walk;
    const yellow = Color(0xFFFFD84D);
    const line = Color(0xFFE5B52A);
    final s = _swing * 1.3;

    final hipY = 76 + b;
    _birdLeg(c, Offset(45, hipY), 94 - hipY - 2, s);
    _birdLeg(c, Offset(53, hipY), 94 - hipY - 2, -s);

    final body = Offset(48, 64 + b);
    final head = Offset(62 + peck, 46 + b);
    c.drawCircle(body, 18.2, _fill(line));
    c.drawCircle(head, 13.2, _fill(line));
    c.drawCircle(body, 17, _fill(yellow));
    c.drawCircle(head, 12, _fill(yellow));
    // Kanatçık
    c.drawOval(
      Rect.fromCenter(
        center: body + const Offset(-3, 2),
        width: 16,
        height: 11,
      ),
      _fill(const Color(0xFFF7C733)),
    );
    // Tepe tüyü
    c.drawLine(
      head + const Offset(-2, -11),
      head + const Offset(-4, -17),
      _stroke(line, 1.8),
    );
    c.drawLine(
      head + const Offset(1, -11),
      head + const Offset(2, -17),
      _stroke(line, 1.8),
    );
    c.drawPath(
      Path()
        ..moveTo(head.dx + 10, head.dy - 1)
        ..lineTo(head.dx + 17, head.dy + 1.5)
        ..lineTo(head.dx + 10, head.dy + 4)
        ..close(),
      _fill(const Color(0xFFF08A24)),
    );
    _eye(c, head + const Offset(4, -2), 2);
  }

  @override
  bool shouldRepaint(AnimalPainter old) =>
      old.t != t ||
      old.walk != walk ||
      old.baby != baby ||
      old.typeId != typeId;
}
