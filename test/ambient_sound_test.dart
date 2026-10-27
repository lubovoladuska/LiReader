import 'package:flutter_test/flutter_test.dart';
import 'package:lireader/models/ambient_track.dart';
import 'package:lireader/services/ambient_sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ambient Sound Model & Service Tests', () {
    test('defaultTracks contains 4 valid preset tracks', () {
      final tracks = AmbientTrack.defaultTracks;
      expect(tracks.length, 4);

      final ids = tracks.map((t) => t.id).toList();
      expect(ids, containsAll(['rain', 'fireplace', 'forest', 'cafe']));

      for (final track in tracks) {
        expect(track.title.isNotEmpty, isTrue);
        expect(track.subtitle.isNotEmpty, isTrue);
        expect(track.assetPath.startsWith('assets/audio/ambient/'), isTrue);
        expect(track.assetPath.endsWith('.mp3'), isTrue);
      }
    });

    test('volumeNotifier clamps values between 0.0 and 1.0', () async {
      final service = AmbientSoundService.instance;

      await service.setVolume(0.5);
      expect(service.volume, 0.5);

      await service.setVolume(1.8);
      expect(service.volume, 1.0);

      await service.setVolume(-0.4);
      expect(service.volume, 0.0);

      // Reset to default
      await service.setVolume(0.7);
      expect(service.volume, 0.7);
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
