import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// assets/sounds/ altındaki efektler. Dosyalar tool/generate_sounds.py ile üretilir.
enum Sound {
  moo('moo'),
  mooCalf('moo_calf'),
  baa('baa'),
  baaLamb('baa_lamb'),
  cluck('cluck'),
  peep('peep'),
  harvest('harvest'),
  plant('plant'),
  water('water'),
  coin('coin'),
  buy('buy'),
  levelUp('level_up'),
  eat('eat'),
  tap('tap'),
  error('error');

  final String file;
  const Sound(this.file);
}

/// Oyun sesleri. [init] çağrılmadan (ör. testlerde) hiçbir şey çalmaz.
class Sfx {
  static const _prefsKey = 'farmelo_sound_on';

  static final enabled = ValueNotifier<bool>(true);
  static final Map<Sound, Future<AudioPool>> _pools = {};
  static SharedPreferences? _prefs;
  static bool _ready = false;

  static Future<void> init(SharedPreferences? prefs) async {
    _prefs = prefs;
    enabled.value = prefs?.getBool(_prefsKey) ?? true;
    try {
      // Kullanıcının dinlediği müziği kesmeden onunla karışsın.
      await AudioPlayer.global
          .setAudioContext(
            AudioContextConfig(
              focus: AudioContextConfigFocus.mixWithOthers,
              respectSilence: true,
            ).build(),
          )
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Ses bağlamı ayarlanamadı: $e');
    }
    _ready = true;
    // İlk çalışta gecikme olmasın diye arka planda önceden yükle.
    for (final s in Sound.values) {
      unawaited(_pool(s).then((_) {}, onError: (_) {}));
    }
  }

  static Future<AudioPool> _pool(Sound s) => _pools.putIfAbsent(
    s,
    () =>
        AudioPool.createFromAsset(path: 'sounds/${s.file}.wav', maxPlayers: 3),
  );

  static void play(Sound s, {double volume = 1}) {
    if (!_ready || !enabled.value) return;
    unawaited(_play(s, volume));
  }

  static Future<void> _play(Sound s, double volume) async {
    try {
      final pool = await _pool(s);
      await pool.start(volume: volume);
    } catch (e) {
      debugPrint('Ses çalınamadı (${s.file}): $e');
    }
  }

  static void toggle() {
    enabled.value = !enabled.value;
    _prefs?.setBool(_prefsKey, enabled.value);
    if (enabled.value) play(Sound.tap);
  }

  /// Hayvan türüne ve yaşına göre ses.
  static Sound voiceOf(String typeId, {required bool adult}) =>
      switch (typeId) {
        'inek' => adult ? Sound.moo : Sound.mooCalf,
        'koyun' => adult ? Sound.baa : Sound.baaLamb,
        _ => adult ? Sound.cluck : Sound.peep,
      };

  static void voice(
    String typeId, {
    required bool adult,
    double volume = 0.8,
  }) => play(voiceOf(typeId, adult: adult), volume: volume);
}
