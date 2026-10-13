import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsPlaybackState {
  stopped,
  playing,
  paused,
}

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  final ValueNotifier<TtsPlaybackState> stateNotifier = ValueNotifier(TtsPlaybackState.stopped);
  final ValueNotifier<int> currentParagraphNotifier = ValueNotifier(-1);
  final ValueNotifier<double> rateNotifier = ValueNotifier(1.0);

  List<String> _currentParagraphs = [];
  int _currentParagraphIndex = 0;
  VoidCallback? _onChapterFinished;

  bool get isPlaying => stateNotifier.value == TtsPlaybackState.playing;
  bool get isPaused => stateNotifier.value == TtsPlaybackState.paused;
  bool get isStopped => stateNotifier.value == TtsPlaybackState.stopped;
  int get currentParagraphIndex => currentParagraphNotifier.value;
  double get currentRate => rateNotifier.value;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5); // FlutterTTS 0.5 is 1.0x normal speed on Android

      // Default language Russian if available
      final languages = await _tts.getLanguages;
      if (languages is List && languages.any((l) => l.toString().toLowerCase().startsWith('ru'))) {
        await _tts.setLanguage('ru-RU');
      }

      _tts.setStartHandler(() {
        stateNotifier.value = TtsPlaybackState.playing;
      });

      _tts.setCompletionHandler(() {
        _onParagraphCompleted();
      });

      _tts.setCancelHandler(() {
        stateNotifier.value = TtsPlaybackState.stopped;
      });

      _tts.setPauseHandler(() {
        stateNotifier.value = TtsPlaybackState.paused;
      });

      _tts.setContinueHandler(() {
        stateNotifier.value = TtsPlaybackState.playing;
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        stateNotifier.value = TtsPlaybackState.stopped;
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  /// Begins reading a list of chapter paragraphs starting from [startIndex]
  Future<void> playChapter(
    List<String> paragraphs, {
    int startIndex = 0,
    VoidCallback? onChapterFinished,
  }) async {
    await init();

    _currentParagraphs = paragraphs;
    _onChapterFinished = onChapterFinished;
    _currentParagraphIndex = startIndex.clamp(0, paragraphs.isNotEmpty ? paragraphs.length - 1 : 0);

    if (_currentParagraphs.isEmpty) {
      stop();
      return;
    }

    _speakCurrentParagraph();
  }

  Future<void> _speakCurrentParagraph() async {
    if (_currentParagraphIndex < 0 || _currentParagraphIndex >= _currentParagraphs.length) {
      stop();
      _onChapterFinished?.call();
      return;
    }

    final rawText = _currentParagraphs[_currentParagraphIndex].trim();
    if (rawText.isEmpty) {
      _currentParagraphIndex++;
      _speakCurrentParagraph();
      return;
    }

    // Auto-detect English text vs Russian
    final hasCyrillic = RegExp(r'[а-яА-ЯёЁ]').hasMatch(rawText);
    try {
      if (hasCyrillic) {
        await _tts.setLanguage('ru-RU');
      } else {
        await _tts.setLanguage('en-US');
      }
    } catch (_) {}

    currentParagraphNotifier.value = _currentParagraphIndex;
    stateNotifier.value = TtsPlaybackState.playing;

    await _tts.speak(rawText);
  }

  void _onParagraphCompleted() {
    if (stateNotifier.value != TtsPlaybackState.playing) return;

    if (_currentParagraphIndex + 1 < _currentParagraphs.length) {
      _currentParagraphIndex++;
      _speakCurrentParagraph();
    } else {
      // Reached end of chapter
      currentParagraphNotifier.value = -1;
      stateNotifier.value = TtsPlaybackState.stopped;
      _onChapterFinished?.call();
    }
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
      stateNotifier.value = TtsPlaybackState.paused;
    } catch (_) {
      await _tts.stop();
      stateNotifier.value = TtsPlaybackState.paused;
    }
  }

  Future<void> resume() async {
    if (isPaused) {
      _speakCurrentParagraph();
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    currentParagraphNotifier.value = -1;
    stateNotifier.value = TtsPlaybackState.stopped;
  }

  Future<void> nextParagraph() async {
    if (_currentParagraphIndex + 1 < _currentParagraphs.length) {
      await _tts.stop();
      _currentParagraphIndex++;
      _speakCurrentParagraph();
    } else {
      stop();
      _onChapterFinished?.call();
    }
  }

  Future<void> previousParagraph() async {
    if (_currentParagraphIndex > 0) {
      await _tts.stop();
      _currentParagraphIndex--;
      _speakCurrentParagraph();
    } else {
      await _tts.stop();
      _speakCurrentParagraph();
    }
  }

  Future<void> setSpeechRate(double rate) async {
    // FlutterTTS maps 0.5 to 1.0x normal speed. 1.0 is ~2x speed.
    rateNotifier.value = rate;
    final flutterTtsRate = (rate * 0.5).clamp(0.25, 1.0);
    await _tts.setSpeechRate(flutterTtsRate);
  }

  /// Cycles through common playback speeds
  Future<void> cycleSpeechRate() async {
    const rates = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final current = rateNotifier.value;
    int nextIdx = 0;
    for (int i = 0; i < rates.length; i++) {
      if ((rates[i] - current).abs() < 0.05) {
        nextIdx = (i + 1) % rates.length;
        break;
      }
    }
    await setSpeechRate(rates[nextIdx]);
  }
}
