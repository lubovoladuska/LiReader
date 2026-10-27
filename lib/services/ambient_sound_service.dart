import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/ambient_track.dart';

class AmbientSoundService {
  static final AmbientSoundService instance = AmbientSoundService._internal();

  factory AmbientSoundService() => instance;

  AmbientSoundService._internal();

  AudioPlayer? _player;
  AudioPlayer get player => _player ??= AudioPlayer();

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<AmbientTrack?> currentTrackNotifier = ValueNotifier<AmbientTrack?>(null);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.7);
  final ValueNotifier<int> sleepTimerSecondsNotifier = ValueNotifier<int>(0);

  Timer? _sleepTimer;
  double _savedVolume = 0.7;

  bool get isPlaying => isPlayingNotifier.value;
  AmbientTrack? get currentTrack => currentTrackNotifier.value;
  double get volume => volumeNotifier.value;

  /// Starts or switches to [track] with seamless looping.
  Future<void> playTrack(AmbientTrack track) async {
    try {
      if (currentTrack?.id == track.id && isPlaying) {
        await pause();
        return;
      }

      currentTrackNotifier.value = track;
      await player.setAsset(track.assetPath);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(volumeNotifier.value);
      await player.play();
      isPlayingNotifier.value = true;
    } catch (e) {
      debugPrint('Error playing ambient track: $e');
      isPlayingNotifier.value = false;
    }
  }

  /// Toggles between play and pause.
  Future<void> togglePlay() async {
    if (isPlaying) {
      await pause();
    } else {
      final track = currentTrack ?? AmbientTrack.defaultTracks.first;
      await playTrack(track);
    }
  }

  /// Pauses ambient playback.
  Future<void> pause() async {
    try {
      await player.pause();
    } catch (_) {}
    isPlayingNotifier.value = false;
  }

  /// Stops ambient playback and resets position.
  Future<void> stop() async {
    try {
      await player.stop();
    } catch (_) {}
    isPlayingNotifier.value = false;
    _sleepTimer?.cancel();
    sleepTimerSecondsNotifier.value = 0;
  }

  /// Changes volume level (0.0 to 1.0).
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    _savedVolume = clamped;
    volumeNotifier.value = clamped;
    try {
      await player.setVolume(clamped);
    } catch (_) {}
  }

  /// Sets sleep timer in minutes (0 to cancel).
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      sleepTimerSecondsNotifier.value = 0;
      return;
    }

    sleepTimerSecondsNotifier.value = minutes * 60;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sleepTimerSecondsNotifier.value > 1) {
        sleepTimerSecondsNotifier.value--;
      } else {
        timer.cancel();
        sleepTimerSecondsNotifier.value = 0;
        fadeStop();
      }
    });
  }

  /// Gradually reduces volume to zero and stops playback.
  Future<void> fadeStop({Duration duration = const Duration(seconds: 3)}) async {
    if (!isPlaying) return;

    final steps = 12;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final initialVol = volumeNotifier.value;

    for (int i = steps - 1; i >= 0; i--) {
      await Future.delayed(stepDuration);
      try {
        await player.setVolume(initialVol * (i / steps));
      } catch (_) {}
    }

    await stop();
    // Restore volume setting for next play
    try {
      await player.setVolume(_savedVolume);
    } catch (_) {}
  }

  void dispose() {
    _sleepTimer?.cancel();
    _player?.dispose();
    _player = null;
  }
}
