import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays short sound effects and the narrator voice clips. Failures (missing plugin in
/// tests, no audio device) are swallowed: sound is never worth crashing a run.
class AudioService {
  AudioService({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<AudioPlayer> _sfx = [];
  AudioPlayer? _voice;
  int _next = 0;

  /// Master switch, kept in sync with the Sound setting.
  bool enabled = true;

  static const int _sfxChannels = 4;

  /// Plays `assets/sfx/<name>.wav`; overlapping effects use a small round-robin pool.
  Future<void> sfx(String name) => _play(_pool(), 'sfx/$name.wav', volume: 0.7);

  /// Plays `assets/voice/<name>.mp3`, cutting off any clip still speaking.
  /// A name with `_02` variants may pass [variants] to pick one at random.
  Future<void> voice(String name, {int variants = 1}) {
    final n = variants <= 1 ? 1 : _random.nextInt(variants) + 1;
    final file = n == 1 ? name : '${name}_${n.toString().padLeft(2, '0')}';
    return _play(_voice ??= AudioPlayer(), 'voice/$file.mp3');
  }

  AudioPlayer _pool() {
    if (_sfx.length < _sfxChannels) {
      final p = AudioPlayer();
      _sfx.add(p);
      return p;
    }
    return _sfx[_next++ % _sfxChannels];
  }

  Future<void> _play(AudioPlayer p, String asset, {double volume = 1}) async {
    if (!enabled) return;
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource(asset));
    } catch (e) {
      debugPrint('audio: $asset failed: $e');
    }
  }

  Future<void> dispose() async {
    for (final p in [..._sfx, ?_voice]) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
