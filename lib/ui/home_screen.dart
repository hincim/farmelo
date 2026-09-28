import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/game_state.dart';
import 'field_page.dart';
import 'market_page.dart';
import 'pasture_page.dart';
import 'shop_page.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/fx.dart';
import 'widgets/sky_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _pages = PageController();
  late GameState _game;
  StreamSubscription<GameEvent>? _sub;
  int _index = 0;

  String? _toast;
  int _toastId = 0;
  Timer? _toastTimer;
  LevelUpEvent? _levelUp;
  Timer? _ambient;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Meradayken ara sıra bir hayvan kendiliğinden ses çıkarır (gece uyurlar).
    _ambient = Timer.periodic(const Duration(seconds: 7), (_) {
      final night = _game.dayTime < 0.23 || _game.dayTime > 0.8;
      if (_index != 1 || night || _game.animals.isEmpty) return;
      if (_rng.nextDouble() > 0.6) return;
      final a = _game.animals[_rng.nextInt(_game.animals.length)];
      Sfx.voice(a.typeId, adult: a.isAdult, volume: 0.3);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game = GameScope.read(context);
    _sub ??= _game.events.listen(_onEvent);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _game.save();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _toastTimer?.cancel();
    _ambient?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    switch (e) {
      case ToastEvent(:final message):
        Sfx.play(Sound.error, volume: 0.6);
        _toastTimer?.cancel();
        setState(() {
          _toast = message;
          _toastId++;
        });
        _toastTimer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _toast = null);
        });
      case LevelUpEvent():
        Sfx.play(Sound.levelUp);
        setState(() => _levelUp = e);
    }
  }

  void _go(int i) {
    if (i != _index) Sfx.play(Sound.tap, volume: 0.5);
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FieldPage(),
      PasturePage(onGoShop: () => _go(3)),
      const MarketPage(),
      const ShopPage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SkyHeader(),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) =>
                      _PageDepth(controller: _pages, index: i, child: pages[i]),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.6),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: _toast == null
                    ? const SizedBox.shrink()
                    : Center(
                        key: ValueKey(_toastId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: FarmColors.ink.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _toast!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (_levelUp != null)
            Positioned.fill(
              child: _LevelUpBanner(
                key: ValueKey(_levelUp!.level),
                event: _levelUp!,
                onDone: () => setState(() => _levelUp = null),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _NavBar(
        controller: _pages,
        index: _index,
        onTap: _go,
      ),
    );
  }
}

/// Sayfa kaydırılırken yandaki sayfalar hafifçe küçülüp soluklaşır.
class _PageDepth extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const _PageDepth({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var page = index.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }
        final d = (page - index).abs().clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - d * 0.5,
          child: Transform.scale(scale: 1 - d * 0.08, child: child),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  final PageController controller;
  final int index;
  final ValueChanged<int> onTap;

  const _NavBar({
    required this.controller,
    required this.index,
    required this.onTap,
  });

  static const _items = [
    ('🌱', 'Tarla'),
    ('🐄', 'Mera'),
    ('🧺', 'Pazar'),
    ('🏪', 'Mağaza'),
  ];

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final badges = [
      game.readyPlotCount,
      game.readyAnimalCount + game.animals.where((a) => a.hungry).length,
      0,
      0,
    ];

    return Container(
      decoration: BoxDecoration(
        color: FarmColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        height: 60,
        child: LayoutBuilder(
          builder: (context, box) {
            final itemW = box.maxWidth / _items.length;
            return Stack(
              children: [
                // Parmakla sayfa kaydırılırken de takip eden gösterge.
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    var page = index.toDouble();
                    if (controller.hasClients &&
                        controller.position.haveDimensions) {
                      page = controller.page ?? page;
                    }
                    return Positioned(
                      left: page * itemW + 6,
                      width: itemW - 12,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: FarmColors.meadow.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: Pressable(
                          onTap: (_) => onTap(i),
                          child: _NavItem(
                            emoji: _items[i].$1,
                            label: _items[i].$2,
                            selected: i == index,
                            badge: badges[i],
                            isBarn: i == 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final int badge;
  final bool isBarn;

  const _NavItem({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.badge,
    required this.isBarn,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = AnimatedScale(
      scale: selected ? 1.2 : 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
    if (isBarn) {
      // Hasat edilen ürünler buraya uçar.
      icon = PulseOnChange(
        notifier: barnPulse,
        child: KeyedSubtree(key: barnTargetKey, child: icon),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 12,
                color: selected ? FarmColors.ink : FarmColors.inkSoft,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
        ),
        Positioned(
          top: 2,
          right: 14,
          child: AnimatedScale(
            scale: badge > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FarmColors.barnRed,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelUpBanner extends StatefulWidget {
  final LevelUpEvent event;
  final VoidCallback onDone;

  const _LevelUpBanner({super.key, required this.event, required this.onDone});

  @override
  State<_LevelUpBanner> createState() => _LevelUpBannerState();
}

class _LevelUpBannerState extends State<_LevelUpBanner>
    with SingleTickerProviderStateMixin {
  static const _exitAt = 0.85;

  // Bitişi durum dinleyicisiyle yakalıyoruz: forward()'un döndürdüğü future,
  // animasyon yarıda kesilirse hiç tamamlanmaz ve kutu ekranda kalırdı.
  late final _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  /// Dokununca beklemeyi atlayıp doğrudan kapanış animasyonuna geç.
  void _skip() {
    if (_c.value >= _exitAt) return;
    _c.value = _exitAt;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.event.unlocked;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final enter = Curves.elasticOut.transform((t / 0.25).clamp(0, 1));
        final exit = t > _exitAt ? (t - _exitAt) / (1 - _exitAt) : 0.0;
        final opacity = (1 - exit).clamp(0.0, 1.0);
        // Kapanırken dokunuşlar doğrudan oyuna geçsin.
        return IgnorePointer(
          ignoring: t >= _exitAt,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: CustomPaint(painter: _ConfettiPainter(t)),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, -30 * exit),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * enter,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          decoration: BoxDecoration(
                            color: FarmColors.paper,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: FarmColors.straw,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎉', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 4),
                              Text(
                                'Seviye ${widget.event.level}!',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                unlocked.isEmpty
                                    ? 'Çiftliğin büyüyor.'
                                    : 'Yeni: ${unlocked.join(', ')}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: FarmColors.inkSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _colors = [
    FarmColors.straw,
    FarmColors.barnRed,
    FarmColors.grass,
    FarmColors.water,
    Color(0xFFFF9EB5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final origin = Offset(size.width / 2, size.height * 0.32);
    for (var i = 0; i < 70; i++) {
      final angle = -pi / 2 + (rng.nextDouble() * 2 - 1) * pi * 0.75;
      final speed = 300 + rng.nextDouble() * 500;
      final spin = rng.nextDouble() * 10;
      final time = t * 3.2; // saniye
      final p =
          origin +
          Offset(
            cos(angle) * speed * time * 0.6,
            sin(angle) * speed * time * 0.6 + 420 * time * time,
          );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(spin * time);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -2.5, 8, 5),
        Paint()..color = _colors[i % _colors.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
