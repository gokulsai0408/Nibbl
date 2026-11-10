import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Mochi's little sound effects (synthesized originals in assets/sounds).
///
/// Mixes with other audio (never pauses the user's music) and respects the
/// phone's silent mode. Toggled by the "Sound effects" setting.
abstract final class SoundFx {
  static bool enabled = true;

  static final _players = <String, AudioPlayer>{};
  static final _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
    respectSilence: true,
  ).build();
  static int _squeak = 0;

  static Future<void> _play(String file, {double volume = 0.7}) async {
    if (!enabled) return;
    try {
      var player = _players[file];
      if (player == null) {
        player = AudioPlayer();
        _players[file] = player;
        await player.setAudioContext(_context);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await player.stop();
      await player.play(AssetSource('sounds/$file'), volume: volume);
    } catch (e) {
      debugPrint('Sound effect failed: $e');
    }
  }

  /// Short rubbery squeak (alternates between two pitches).
  static Future<void> squeak() => _play(_squeak++ % 2 == 0 ? 'squeak1.wav' : 'squeak2.wav');

  /// Springy boing for a big hop.
  static Future<void> boing() => _play('boing.wav', volume: 0.6);

  /// Three-chirp giggle for tickles.
  static Future<void> giggle() => _play('giggle.wav', volume: 0.55);
}
