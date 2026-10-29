import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/ambient_track.dart';

/// Ambient soundscape service supporting multi-layer simultaneous playback,
/// individual track volume balancing, atmospheric presets, and smooth sleep timer.
class AmbientSoundService {
  static final AmbientSoundService instance = AmbientSoundService._internal();

  factory AmbientSoundService() => instance;

  AmbientSoundService._internal();

  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _trackVolumes = {};

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> masterVolumeNotifier = ValueNotifier<double>(0.75);
  final ValueNotifier<Map<String, double>> activeVolumesNotifier =
      ValueNotifier<Map<String, double>>({});
  final ValueNotifier<int> activeCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> sleepTimerSecondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<AmbientTrack?> currentTrackNotifier =
      ValueNotifier<AmbientTrack?>(null);

  // Backward compatibility alias
  ValueNotifier<double> get volumeNotifier => masterVolumeNotifier;

  Timer? _sleepTimer;
  double _savedMasterVolume = 0.75;

  bool get isPlaying => isPlayingNotifier.value;
  double get masterVolume => masterVolumeNotifier.value;
  double get volume => masterVolume;
  AmbientTrack? get currentTrack => currentTrackNotifier.value;
  Map<String, double> get trackVolumes => Map.unmodifiable(_trackVolumes);

  double getTrackVolume(String trackId) => _trackVolumes[trackId] ?? 0.0;
  bool isTrackActive(String trackId) => (_trackVolumes[trackId] ?? 0.0) > 0.0;

  bool _cacheCleared = false;

  /// Ensures an [AudioPlayer] exists and is loaded for [trackId].
  Future<AudioPlayer?> _getOrInitPlayer(String trackId) async {
    if (!_cacheCleared) {
      _cacheCleared = true;
      try {
        await AudioPlayer.clearAssetCache();
      } catch (_) {}
    }

    if (_players.containsKey(trackId)) {
      return _players[trackId];
    }

    try {
      final track = AmbientTrack.defaultTracks.firstWhere(
        (t) => t.id == trackId,
        orElse: () => AmbientTrack.defaultTracks.first,
      );
      final player = AudioPlayer();
      await player.setAsset(track.assetPath);
      await player.setLoopMode(LoopMode.one);
      _players[trackId] = player;
      return player;
    } catch (e) {
      debugPrint('Error loading ambient sound asset ($trackId): $e');
      return null;
    }
  }

  /// Sets individual volume for [trackId] (0.0 to 1.0).
  /// If [volume] > 0 and playback is currently running, the track starts immediately.
  Future<void> setTrackVolume(String trackId, double volume) async {
    final clamped = volume.clamp(0.0, 1.0);

    if (clamped <= 0.001) {
      _trackVolumes.remove(trackId);
      final player = _players[trackId];
      if (player != null) {
        try {
          await player.pause();
        } catch (_) {}
      }
    } else {
      _trackVolumes[trackId] = clamped;
      final player = await _getOrInitPlayer(trackId);
      if (player != null) {
        try {
          await player.setVolume(clamped * masterVolume);
          if (isPlaying && !player.playing) {
            await player.play();
          }
        } catch (_) {}
      }
    }

    _notifyStateChanges();

    // If a track was turned on while stopped, automatically begin playback
    if (_trackVolumes.isNotEmpty && !isPlaying && clamped > 0) {
      await play();
    }
  }

  /// Toggles track on (with [defaultVolume]) or off.
  Future<void> toggleTrack(String trackId, {double defaultVolume = 0.7}) async {
    if (isTrackActive(trackId)) {
      await setTrackVolume(trackId, 0.0);
    } else {
      await setTrackVolume(trackId, defaultVolume);
    }
  }

  /// Applies a multi-layer soundscape preset.
  Future<void> applyPreset(AmbientPreset preset) async {
    // 1. Mute any active tracks not in preset
    final currentIds = _trackVolumes.keys.toList();
    for (final id in currentIds) {
      if (!preset.trackVolumes.containsKey(id)) {
        await setTrackVolume(id, 0.0);
      }
    }

    // 2. Set preset volumes
    for (final entry in preset.trackVolumes.entries) {
      await setTrackVolume(entry.key, entry.value);
    }

    // 3. Ensure playing
    await play();
  }

  /// Changes master volume level (0.0 to 1.0).
  Future<void> setMasterVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    _savedMasterVolume = clamped;
    masterVolumeNotifier.value = clamped;

    for (final entry in _players.entries) {
      final trackVol = _trackVolumes[entry.key] ?? 0.0;
      try {
        await entry.value.setVolume(trackVol * clamped);
      } catch (_) {}
    }
  }

  /// Backward-compatible setVolume
  Future<void> setVolume(double value) => setMasterVolume(value);

  /// Starts or resumes playback for all active tracks.
  Future<void> play() async {
    if (_trackVolumes.isEmpty) {
      // Default to rain if nothing is active yet
      await setTrackVolume('rain', 0.7);
    }

    for (final entry in _trackVolumes.entries) {
      if (entry.value > 0) {
        final player = await _getOrInitPlayer(entry.key);
        if (player != null) {
          try {
            await player.setVolume(entry.value * masterVolume);
            if (!player.playing) {
              await player.play();
            }
          } catch (_) {}
        }
      }
    }

    isPlayingNotifier.value = true;
    _notifyStateChanges();
  }

  /// Pauses all active tracks.
  Future<void> pause() async {
    for (final player in _players.values) {
      try {
        if (player.playing) {
          await player.pause();
        }
      } catch (_) {}
    }
    isPlayingNotifier.value = false;
  }

  /// Toggles master playback state.
  Future<void> togglePlay() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Stops all audio and mutes all tracks.
  Future<void> stopAll() async {
    await pause();
    _trackVolumes.clear();
    _notifyStateChanges();
    _sleepTimer?.cancel();
    sleepTimerSecondsNotifier.value = 0;
  }

  /// Backward-compatible stop()
  Future<void> stop() => pause();

  /// Legacy playTrack for single-track interactions
  Future<void> playTrack(AmbientTrack track) async {
    if (isTrackActive(track.id) && isPlaying) {
      await setTrackVolume(track.id, 0.0);
    } else {
      // Solo play: mute others or add
      await setTrackVolume(track.id, 0.75);
    }
  }

  void _notifyStateChanges() {
    activeVolumesNotifier.value = Map<String, double>.from(_trackVolumes);
    activeCountNotifier.value = _trackVolumes.length;

    if (_trackVolumes.isEmpty) {
      currentTrackNotifier.value = null;
      if (isPlaying) {
        isPlayingNotifier.value = false;
      }
    } else {
      final firstId = _trackVolumes.keys.first;
      currentTrackNotifier.value = AmbientTrack.defaultTracks.firstWhere(
        (t) => t.id == firstId,
        orElse: () => AmbientTrack.defaultTracks.first,
      );
    }
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

  /// Gradually reduces master volume to zero and pauses playback.
  Future<void> fadeStop({Duration duration = const Duration(seconds: 3)}) async {
    if (!isPlaying) return;

    const steps = 12;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final initialVol = masterVolumeNotifier.value;

    for (int i = steps - 1; i >= 0; i--) {
      await Future.delayed(stepDuration);
      final factor = i / steps;
      masterVolumeNotifier.value = initialVol * factor;
      for (final entry in _players.entries) {
        final trackVol = _trackVolumes[entry.key] ?? 0.0;
        try {
          await entry.value.setVolume(trackVol * masterVolumeNotifier.value);
        } catch (_) {}
      }
    }

    await pause();
    // Restore master volume setting for next play
    await setMasterVolume(_savedMasterVolume);
  }

  void dispose() {
    _sleepTimer?.cancel();
    for (final player in _players.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
