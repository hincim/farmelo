import 'package:flutter/material.dart';

import '../theme.dart';

/// Basıldığında hafifçe küçülen, bırakınca yaylanarak geri gelen dokunma alanı.
class Pressable extends StatefulWidget {
  final Widget child;
  final void Function(Offset globalPosition)? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.93,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: () => _set(false),
      onTapUp: enabled
          ? (d) {
              _set(false);
              widget.onTap!(d.globalPosition);
            }
          : null,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _down ? 90 : 350),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Değer değiştikçe yumuşakça dolan ilerleme çubuğu.
class SmoothBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color? background;
  final double height;
  final Duration duration;

  const SmoothBar({
    super.key,
    required this.value,
    required this.color,
    this.background,
    this.height = 8,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: duration,
      builder: (context, v, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: background ?? Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(height),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayıyı eski değerinden yenisine kaydırarak gösterir.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const AnimatedCount(
    this.value, {
    super.key,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$prefix${v.round()}$suffix',
        style: (style ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Ahşap tabela görünümlü eylem düğmesi.
class FarmButton extends StatelessWidget {
  final String label;
  final String? emoji;
  final void Function(Offset globalPosition)? onTap;
  final Color color;
  final Color textColor;
  final bool compact;

  const FarmButton({
    super.key,
    required this.label,
    this.emoji,
    this.onTap,
    this.color = FarmColors.grassDark,
    this.textColor = Colors.white,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: enabled ? 1 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 11,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(color, Colors.black, 0.35)!,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: TextStyle(fontSize: compact ? 14 : 16)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alt öğelerini sırayla, kayarak ve belirerek getirir.
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Offset from;

  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.from = const Offset(0, 0.25),
  });

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 45 * widget.index.clamp(0, 12)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: widget.from, end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Sonsuz döngüde 0..1 arası değer üreten yardımcı (sallanma, zıplama vb.).
class LoopBuilder extends StatefulWidget {
  final Duration period;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;
  final double phase;

  const LoopBuilder({
    super.key,
    required this.period,
    required this.builder,
    this.child,
    this.phase = 0,
  });

  @override
  State<LoopBuilder> createState() => _LoopBuilderState();
}

class _LoopBuilderState extends State<LoopBuilder>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..value = widget.phase % 1
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _c.value, child),
    );
  }
}

String formatSeconds(double s) {
  final total = s.ceil();
  if (total < 60) return '$total sn';
  final m = total ~/ 60;
  final r = total % 60;
  return r == 0 ? '$m dk' : '$m dk $r sn';
}

/// Alt sayfalar için ortak çerçeve: kâğıt zemin, tutamaç, başlık.
class SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const SheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FarmColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: FarmColors.inkSoft.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: FarmColors.inkSoft)),
          ],
          const SizedBox(height: 14),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}
