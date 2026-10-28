import 'package:flutter_test/flutter_test.dart';
import 'package:lireader/models/ambient_track.dart';
import 'package:lireader/services/ambient_sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ambient Sound Model & Service Tests', () {
    test('defaultTracks contains 10 valid natural sound tracks', () {
      final tracks = AmbientTrack.defaultTracks;
      expect(tracks.length, 10);

      final ids = tracks.map((t) => t.id).toList();
      expect(
        ids,
        containsAll([
          'rain',
          'thunder',
          'fireplace',
          'forest',
          'night',
          'waves',
          'wind',
          'cafe',
          'train',
          'stream',
        ]),
      );

      for (final track in tracks) {
        expect(track.title.isNotEmpty, isTrue);
        expect(track.subtitle.isNotEmpty, isTrue);
        expect(track.assetPath.startsWith('assets/audio/ambient/'), isTrue);
        expect(track.assetPath.endsWith('.mp3'), isTrue);
      }
    });

    test('defaultPresets contains atmospheric multi-track combinations', () {
      final presets = AmbientPreset.defaultPresets;
      expect(presets.length, greaterThanOrEqualTo(5));

      for (final p in presets) {
        expect(p.id.isNotEmpty, isTrue);
        expect(p.title.isNotEmpty, isTrue);
        expect(p.emoji.isNotEmpty, isTrue);
        expect(p.trackVolumes.isNotEmpty, isTrue);
      }
    });

    test('volumeNotifier clamps values between 0.0 and 1.0', () async {
      final service = AmbientSoundService.instance;

      await service.setMasterVolume(0.5);
      expect(service.masterVolume, 0.5);

      await service.setMasterVolume(1.8);
      expect(service.masterVolume, 1.0);

      await service.setMasterVolume(-0.4);
      expect(service.masterVolume, 0.0);

      // Reset to default
      await service.setMasterVolume(0.75);
      expect(service.masterVolume, 0.75);
    });

    test('sleep timer sets seconds and cancels cleanly', () {
      final service = AmbientSoundService.instance;

      service.setSleepTimer(10);
      expect(service.sleepTimerSecondsNotifier.value, 600);

      service.setSleepTimer(0);
      expect(service.sleepTimerSecondsNotifier.value, 0);
    });
  });
}
