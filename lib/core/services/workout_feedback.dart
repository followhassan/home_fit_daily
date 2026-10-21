import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FeedbackCue { countdown, exerciseStart, restStart, complete }

/// Optional sounds and vibration during a workout.
///
/// Failures are swallowed and logged: audio or haptics must never block or
/// break a workout.
abstract interface class WorkoutFeedback {
  Future<void> init();
  void configure({required bool sound, required bool vibration});
  void cue(FeedbackCue cue);
  Future<void> dispose();
}

/// Plays short bundled tones (generated for this app, see
/// `docs/ASSETS.md`). Audio mixes with the user's music without pausing it
/// and, on iOS, respects the silent switch.
class AudioHapticFeedback implements WorkoutFeedback {
  static const _files = {
    FeedbackCue.countdown: 'audio/tick.wav',
    FeedbackCue.exerciseStart: 'audio/go.wav',
    FeedbackCue.restStart: 'audio/rest.wav',
    FeedbackCue.complete: 'audio/complete.wav',
  };

  final Map<FeedbackCue, AudioPlayer> _players = {};
  bool _sound = true;
  bool _vibration = true;
  bool _audioReady = false;

  @override
  Future<void> init() async {
    try {
      final context = AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      );
      for (final entry in _files.entries) {
        final player = AudioPlayer();
        await player.setAudioContext(context);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(entry.value));
        _players[entry.key] = player;
      }
      _audioReady = true;
    } catch (e) {
      debugPrint('Workout sounds unavailable: $e');
      _audioReady = false;
    }
  }

  @override
  void configure({required bool sound, required bool vibration}) {
    _sound = sound;
    _vibration = vibration;
  }

  @override
  void cue(FeedbackCue cue) {
    if (_sound && _audioReady) {
      final player = _players[cue];
      if (player != null) {
        player
            .stop()
            .then((_) => player.resume())
            .catchError((Object e) => debugPrint('Sound failed: $e'));
      }
    }
    if (_vibration) {
      final haptic = switch (cue) {
        FeedbackCue.countdown => HapticFeedback.selectionClick(),
        FeedbackCue.exerciseStart => HapticFeedback.heavyImpact(),
        FeedbackCue.restStart => HapticFeedback.mediumImpact(),
        FeedbackCue.complete => HapticFeedback.heavyImpact(),
      };
      haptic.catchError((Object e) => debugPrint('Haptics failed: $e'));
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
    _audioReady = false;
  }
}

/// Silent implementation used in tests.
class SilentFeedback implements WorkoutFeedback {
  final List<FeedbackCue> cues = [];

  @override
  Future<void> init() async {}

  @override
  void configure({required bool sound, required bool vibration}) {}

  @override
  void cue(FeedbackCue cue) => cues.add(cue);

  @override
  Future<void> dispose() async {}
}
