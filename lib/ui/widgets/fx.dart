import 'dart:math';

import 'package:flutter/material.dart';

/// HUD'daki para ve XP göstergelerinin konumları; uçan efektler buraya varır.
final coinTargetKey = GlobalKey();
final xpTargetKey = GlobalKey();
final barnTargetKey = GlobalKey(); // Alt menüdeki Pazar sekmesi.

/// Uçan bir öğe hedefe vardığında artar; HUD bunu dinleyip "zıplar".
final coinPulse = ValueNotifier<int>(0);
final xpPulse = ValueNotifier<int>(0);
final barnPulse = ValueNotifier<int>(0);

Offset centerOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Offset.zero;
  return box.localToGlobal(box.size.center(Offset.zero));
}

class Fx {
  /// Verilen noktadan yukarı süzülüp kaybolan yazı.
  static void floatText(
    BuildContext context,
    Offset globalPos,
    String text, {
    Color color = Colors.white,
    double fontSize = 20,
    Duration delay = Duration.zero,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final local = _toOverlay(overlay, globalPos);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FloatingText(
        pos: local,
        text: text,
        color: color,
        fontSize: fontSize,
        delay: delay,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  /// Emojileri kavis çizerek HUD'daki hedefe uçurur.
  static void flyTo(
    BuildContext context,
    Offset from,
    GlobalKey target,
    String emoji, {
    int count = 5,
    ValueNotifier<int>? pulse,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final targetCtx = target.currentContext;
    if (overlay == null || targetCtx == null) return;
    final start = _toOverlay(overlay, from);
    final end = _toOverlay(overlay, centerOf(targetCtx));
    final rng = Random();
    for (var i = 0; i < count; i++) {
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _FlyingItem(
          from:
              start +
              Offset(rng.nextDouble() * 30 - 15, rng.nextDouble() * 20 - 10),
          to: end,
          emoji: emoji,
          delay: Duration(milliseconds: i * 70),
          bend: (rng.nextDouble() * 2 - 1) * 90,
          onDone: () {
            entry.remove();
            if (pulse != null) pulse.value++;
          },
        ),
      );
      overlay.insert(entry);
    }
  }

  static Offset _toOverlay(OverlayState overlay, Offset global) {
    final box = overlay.context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }
}

class _FloatingText extends StatefulWidget {
  final Offset pos;
  final String text;
  final Color color;
  final double fontSize;
  final Duration delay;
  final VoidCallback onDone;

  const _FloatingText({
    required this.pos,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.delay,
    required this.onDone,
  });

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final rise = Curves.easeOutCubic.transform(t) * 70;
        final pop = t < 0.25 ? Curves.elasticOut.transform(t / 0.25) : 1.0;
        final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
        return Positioned(
          left: widget.pos.dx - 100,
          top: widget.pos.dy - 20 - rise,
          width: 200,
          child: IgnorePointer(
            child: Opacity(
              opacity: _c.isDismissed ? 0 : fade.clamp(0, 1),
              child: Transform.scale(
                scale: 0.4 + 0.6 * pop,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                    shadows: const [
                      Shadow(color: Color(0xAA000000), blurRadius: 6),
                      Shadow(color: Color(0x66000000), offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlyingItem extends StatefulWidget {
  final Offset from;
  final Offset to;
  final String emoji;
  final Duration delay;
  final double bend;
  final VoidCallback onDone;

  const _FlyingItem({
    required this.from,
    required this.to,
    required this.emoji,
    required this.delay,
    required this.bend,
    required this.onDone,
  });

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward().whenComplete(widget.onDone);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final a = widget.from;
        final b = widget.to;
        // Önce yukarı fırlayıp sonra hedefe süzülen ikinci dereceden Bezier eğrisi.
        final ctrl = Offset(
          (a.dx + b.dx) / 2 + widget.bend,
          min(a.dy, b.dy) - 80,
        );
        final p =
            a * pow(1 - t, 2).toDouble() +
            ctrl * (2 * (1 - t) * t) +
            b * (t * t);
        final scale = t < 0.15 ? t / 0.15 * 1.3 : 1.3 - 0.6 * t;
        return Positioned(
          left: p.dx - 14,
          top: p.dy - 14,
          child: IgnorePointer(
            child: Opacity(
              opacity: _c.isDismissed ? 0 : 1,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(
                    fontSize: 24,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [notifier] her arttığında çocuğunu kısa bir "boing" ile büyütür.
class PulseOnChange extends StatefulWidget {
  final ValueNotifier<int> notifier;
  final Widget child;

  const PulseOnChange({super.key, required this.notifier, required this.child});

  @override
  State<PulseOnChange> createState() => _PulseOnChangeState();
}

class _PulseOnChangeState extends State<PulseOnChange>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_bump);
  }

  void _bump() => _c.forward(from: 0);

  @override
  void dispose() {
    widget.notifier.removeListener(_bump);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final s = 1 + 0.18 * sin(_c.value * pi);
        return Transform.scale(scale: s, child: child);
      },
    );
  }
}
