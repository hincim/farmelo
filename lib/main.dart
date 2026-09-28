import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Kayıt deposu açılamadı, ilerleme kaydedilmeyecek: $e');
  }
  final game = GameState.load(prefs)..start();
  runApp(FarmeloApp(game: game));
}

class FarmeloApp extends StatelessWidget {
  final GameState game;
  const FarmeloApp({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    // GameScope en üstte: alt sayfalar (bottom sheet) dahil her yerden erişilir.
    return GameScope(
      game: game,
      child: MaterialApp(
        title: 'Farmelo',
        debugShowCheckedModeBanner: false,
        theme: buildFarmTheme(),
        home: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.96 + 0.04 * v, child: child),
          ),
          child: const HomeScreen(),
        ),
      ),
    );
  }
}
