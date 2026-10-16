import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/book_item.dart';
import '../models/reader_theme_settings.dart';
import '../models/search_result.dart';
import '../models/vocabulary_item.dart';
import '../services/book_parser_service.dart';
import '../services/database_helper.dart';
import '../services/image_utils.dart';
import '../services/tts_service.dart';

class ReaderProvider extends ChangeNotifier {
  final BookItem book;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  bool _isLoading = true;
  BookParsedData? _parsedData;
  int _currentChapterIndex = 0;
  double _chapterScrollProgress = 0.0;
  bool _isMenuVisible = true;
  List<BookHighlight> _highlights = [];
  List<VocabularyItem> _vocabulary = [];
  ReaderThemeSettings _themeSettings = const ReaderThemeSettings();

  // --- Reading Session Tracking & Accuracy ---
  DateTime _sessionStartTime = DateTime.now();
  DateTime _lastUserActivityTime = DateTime.now();
  int _sessionWordsRead = 0;
  int _sessionPagesRead = 0;
  Set<int> _completedChapterIndices = {};
  Timer? _sessionAutoFlushTimer;

  // --- In-Book Search ---
  String _searchQuery = '';
  bool _isSearching = false;
  List<SearchResultItem> _searchResults = [];
  int _currentSearchIndex = 0;

  // --- Sleep Timer ---
  Timer? _sleepTimer;
  int _sleepTimerRemainingSeconds = 0;
  VoidCallback? _onSleepTimerExpired;

  ReaderProvider({required this.book}) {
    _currentChapterIndex = book.currentChapterOrPage;
    _sessionStartTime = DateTime.now();
    _sessionAutoFlushTimer = Timer.periodic(const Duration(seconds: 45), (_) => _flushReadingSession());
    _init();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _sessionAutoFlushTimer?.cancel();
    _sleepTimer?.cancel();
    _flushReadingSession();
    super.dispose();
  }

  bool _hasError = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError || (_parsedData == null && !_isLoading);
  String? get errorMessage => _errorMessage;
  BookParsedData? get parsedData => _parsedData;
  int get currentChapterIndex => _currentChapterIndex;
  double get chapterScrollProgress => _chapterScrollProgress;
  bool get isMenuVisible => _isMenuVisible;

  List<BookHighlight> get highlights => _highlights;
  List<VocabularyItem> get vocabulary => _vocabulary;
  ReaderThemeSettings get themeSettings => _themeSettings;

  // Backwards compatibility shortcuts
  double get fontSize => _themeSettings.fontSize;
  double get lineHeight => _themeSettings.lineHeight;

  int get totalChapters => _parsedData?.chapters.length ?? 1;

  // Search Getters
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;
  List<SearchResultItem> get searchResults => _searchResults;
  int get currentSearchIndex => _currentSearchIndex;
  SearchResultItem? get currentSearchResult =>
      _searchResults.isNotEmpty && _currentSearchIndex < _searchResults.length
          ? _searchResults[_currentSearchIndex]
          : null;

  // Sleep Timer Getters
  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  int get sleepTimerRemainingSeconds => _sleepTimerRemainingSeconds;

  Future<void> reload() async {
    await _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();
    try {
      _parsedData = await BookParserService.parseBook(book);
      _highlights = await _dbHelper.getHighlightsForBook(book.id);
      _vocabulary = await _dbHelper.getVocabularyItems(bookId: book.id);
      _completedChapterIndices = await _dbHelper.getCompletedChapterIndices(book.id);

      // Load persisted global theme settings
      final settingsJson = await _dbHelper.getSetting('reader_theme_settings');
      if (settingsJson != null) {
        try {
          final map = json.decode(settingsJson) as Map<String, dynamic>;
          var settings = ReaderThemeSettings.fromMap(map);
          if (settings.backgroundImagePath != null && !settings.isAssetBackground) {
            final bgFile = File(settings.backgroundImagePath!);
            if (!bgFile.existsSync()) {
              final resolved = await BookParserService.resolveBookFile(settings.backgroundImagePath!);
              if (resolved != null) {
                settings = settings.copyWith(backgroundImagePath: resolved.path);
              } else {
                settings = settings.copyWith(backgroundImagePath: null);
              }
            }
          }
          _themeSettings = settings;
        } catch (_) {}
      }

      // Clamp chapter index
      if (_currentChapterIndex >= totalChapters) {
        _currentChapterIndex = 0;
      }
    } catch (e) {
      debugPrint('Error initializing reader: $e');
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _persistSettings() {
    try {
      final jsonStr = json.encode(_themeSettings.toMap());
      _dbHelper.saveSetting('reader_theme_settings', jsonStr);
    } catch (_) {}
  }

  void toggleMenu() {
    _isMenuVisible = !_isMenuVisible;
    notifyListeners();
  }

  void setMenuVisible(bool visible) {
    if (_isMenuVisible != visible) {
      _isMenuVisible = visible;
      notifyListeners();
    }
  }

  void registerUserActivity() {
    _lastUserActivityTime = DateTime.now();
  }

  int _getChapterWordCount(int chapterIndex) {
    if (_parsedData == null || chapterIndex < 0 || chapterIndex >= _parsedData!.chapters.length) {
      return 0;
    }
    final content = _parsedData!.chapters[chapterIndex].content;
    return content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  Future<void> _checkAndMarkChapterCompleted(int chapterIndex) async {
    if (_completedChapterIndices.contains(chapterIndex)) return;
    if (_parsedData == null || chapterIndex < 0 || chapterIndex >= _parsedData!.chapters.length) return;

    final words = _getChapterWordCount(chapterIndex);
    final success = await _dbHelper.markChapterCompleted(
      bookId: book.id,
      chapterIndex: chapterIndex,
      wordsCount: words,
    );
    if (success) {
      _completedChapterIndices.add(chapterIndex);
      _sessionWordsRead += words;
      _sessionPagesRead++;
    }
  }

  void setChapter(int index) {
    registerUserActivity();
    if (index >= 0 && index < totalChapters) {
      if (index > _currentChapterIndex && _chapterScrollProgress >= 0.50) {
        _checkAndMarkChapterCompleted(_currentChapterIndex);
      }
      _currentChapterIndex = index;
      _chapterScrollProgress = 0.0;
      _dbHelper.updateBookProgress(book.id, index, 0.0);
      notifyListeners();
    }
  }

  void saveScrollProgress(double offset, {double fractional = 0.0}) {
    registerUserActivity();
    _chapterScrollProgress = fractional.clamp(0.0, 1.0);
    if (_chapterScrollProgress >= 0.92) {
      _checkAndMarkChapterCompleted(_currentChapterIndex);
    }
    _dbHelper.updateBookProgress(book.id, _currentChapterIndex, offset);
    notifyListeners();
  }

  // --- Reading Session Tracking & Idle Detection ---

  void _flushReadingSession() {
    final now = DateTime.now();
    final idleSeconds = now.difference(_lastUserActivityTime).inSeconds;
    final totalElapsed = now.difference(_sessionStartTime).inSeconds;

    // Discard inactivity periods exceeding 90 seconds (screen left open on table)
    int activeDuration = totalElapsed;
    if (idleSeconds > 90) {
      activeDuration = (totalElapsed - (idleSeconds - 90)).clamp(0, 86400);
    }

    if (activeDuration >= 5 || _sessionWordsRead > 0 || _sessionPagesRead > 0) {
      _dbHelper.recordReadingSession(
        bookId: book.id,
        bookTitle: book.title,
        durationSeconds: activeDuration,
        wordsRead: _sessionWordsRead,
        pagesRead: _sessionPagesRead,
      );
    }
    _sessionStartTime = DateTime.now();
    _sessionWordsRead = 0;
    _sessionPagesRead = 0;
  }

  // --- In-Book Search ---

  Future<void> searchInBook(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty || _parsedData == null) {
      _searchResults = [];
      _currentSearchIndex = 0;
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final results = <SearchResultItem>[];
    final lowerQuery = _searchQuery.toLowerCase();

    for (int chIdx = 0; chIdx < _parsedData!.chapters.length; chIdx++) {
      final ch = _parsedData!.chapters[chIdx];
      final text = ch.content;
      final lowerText = text.toLowerCase();
      int startIndex = 0;

      while (startIndex < lowerText.length) {
        final matchIdx = lowerText.indexOf(lowerQuery, startIndex);
        if (matchIdx == -1) break;

        final beforeStart = (matchIdx - 35).clamp(0, text.length);
        final afterEnd = (matchIdx + lowerQuery.length + 35).clamp(0, text.length);

        final snippetBefore = (beforeStart > 0 ? '...' : '') +
            text.substring(beforeStart, matchIdx).replaceAll('\n', ' ');
        final matchedText = text.substring(matchIdx, matchIdx + lowerQuery.length);
        final snippetAfter = text.substring(matchIdx + lowerQuery.length, afterEnd).replaceAll('\n', ' ') +
            (afterEnd < text.length ? '...' : '');

        results.add(SearchResultItem(
          chapterIndex: chIdx,
          chapterTitle: ch.title.isNotEmpty ? ch.title : 'Глава ${chIdx + 1}',
          matchCharOffset: matchIdx,
          snippetBefore: snippetBefore,
          matchedText: matchedText,
          snippetAfter: snippetAfter,
        ));

        startIndex = matchIdx + lowerQuery.length;
        if (results.length >= 200) break;
      }
      if (results.length >= 200) break;
    }

    _searchResults = results;
    _currentSearchIndex = 0;
    _isSearching = false;

    if (results.isNotEmpty) {
      goToSearchResult(0);
    }
    notifyListeners();
  }

  void nextSearchResult() {
    if (_searchResults.isEmpty) return;
    _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    goToSearchResult(_currentSearchIndex);
  }

  void prevSearchResult() {
    if (_searchResults.isEmpty) return;
    _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
    goToSearchResult(_currentSearchIndex);
  }

  void goToSearchResult(int index) {
    if (index >= 0 && index < _searchResults.length) {
      _currentSearchIndex = index;
      final target = _searchResults[index];
      if (target.chapterIndex != _currentChapterIndex) {
        setChapter(target.chapterIndex);
      } else {
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _currentSearchIndex = 0;
    _isSearching = false;
    notifyListeners();
  }

  // --- Sleep Timer ---

  void startSleepTimer(int minutes, {VoidCallback? onExpire}) {
    cancelSleepTimer();
    _sleepTimerRemainingSeconds = minutes * 60;
    _onSleepTimerExpired = onExpire;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemainingSeconds <= 1) {
        timer.cancel();
        _sleepTimerRemainingSeconds = 0;
        notifyListeners();
        _onSleepTimerExpired?.call();
      } else {
        _sleepTimerRemainingSeconds--;
        if (_sleepTimerRemainingSeconds % 5 == 0) {
          notifyListeners();
        }
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemainingSeconds = 0;
    notifyListeners();
  }

  // --- Theme & Typography Settings ---

  void updateThemeSettings(ReaderThemeSettings newSettings) {
    _themeSettings = newSettings;
    _persistSettings();
    notifyListeners();
  }

  void resetThemeToDefaults() {
    _themeSettings = const ReaderThemeSettings();
    _persistSettings();
    notifyListeners();
  }

  void setFontSize(double size) {
    _themeSettings = _themeSettings.copyWith(fontSize: size.clamp(12.0, 36.0));
    _persistSettings();
    notifyListeners();
  }

  void setLineHeight(double height) {
    _themeSettings = _themeSettings.copyWith(lineHeight: height.clamp(1.2, 2.6));
    _persistSettings();
    notifyListeners();
  }

  void setLetterSpacing(double spacing) {
    _themeSettings = _themeSettings.copyWith(letterSpacing: spacing.clamp(-0.5, 3.0));
    _persistSettings();
    notifyListeners();
  }

  void setParagraphSpacing(double spacing) {
    _themeSettings = _themeSettings.copyWith(paragraphSpacing: spacing.clamp(8.0, 36.0));
    _persistSettings();
    notifyListeners();
  }

  void setFontFamily(ReaderFontFamily family) {
    _themeSettings = _themeSettings.copyWith(fontFamily: family);
    _persistSettings();
    notifyListeners();
  }

  void setTextAlign(TextAlign align) {
    _themeSettings = _themeSettings.copyWith(textAlign: align);
    _persistSettings();
    notifyListeners();
  }

  void setHorizontalPadding(double padding) {
    _themeSettings = _themeSettings.copyWith(horizontalPadding: padding.clamp(12.0, 80.0));
    _persistSettings();
    notifyListeners();
  }

  void setColorPreset(ReaderColorPreset preset) {
    _themeSettings = _themeSettings.copyWith(
      colorPreset: preset,
      isCustomColors: false,
    );
    _persistSettings();
    notifyListeners();
  }

  void setCustomColors({Color? background, Color? text}) {
    _themeSettings = _themeSettings.copyWith(
      customBackgroundColor: background ?? _themeSettings.customBackgroundColor,
      customTextColor: text ?? _themeSettings.customTextColor,
      isCustomColors: true,
    );
    _persistSettings();
    notifyListeners();
  }

  // --- Background Image Customization ---

  Future<bool> pickCustomBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final path = result.files.single.path!;
        // Auto-detect EXIF orientation from JPEG header
        final exifOrientation = await ImageUtils.getExifOrientation(path);
        final initialRotation = ImageUtils.exifToClockwiseDegrees(exifOrientation);

        _themeSettings = _themeSettings.copyWith(
          backgroundImagePath: path,
          isAssetBackground: false,
          backgroundRotation: initialRotation,
        );
        _persistSettings();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error picking background image: $e');
    }
    return false;
  }

  void setBackgroundAsset(String assetPath) {
    _themeSettings = _themeSettings.copyWith(
      backgroundImagePath: assetPath,
      isAssetBackground: true,
      backgroundRotation: 0,
    );
    _persistSettings();
    notifyListeners();
  }

  void rotateBackground() {
    final nextRotation = (_themeSettings.backgroundRotation + 90) % 360;
    _themeSettings = _themeSettings.copyWith(backgroundRotation: nextRotation);
    _persistSettings();
    notifyListeners();
  }

  void setBackgroundRotation(int degrees) {
    _themeSettings = _themeSettings.copyWith(backgroundRotation: degrees % 360);
    _persistSettings();
    notifyListeners();
  }

  void setBackgroundFit(ReaderBackgroundFit fit) {
    _themeSettings = _themeSettings.copyWith(backgroundFit: fit);
    _persistSettings();
    notifyListeners();
  }

  void setBackgroundDimming(double dimming) {
    _themeSettings = _themeSettings.copyWith(backgroundDimming: dimming.clamp(0.0, 0.95));
    _persistSettings();
    notifyListeners();
  }

  void setBackgroundBlur(double blur) {
    _themeSettings = _themeSettings.copyWith(backgroundBlur: blur.clamp(0.0, 20.0));
    _persistSettings();
    notifyListeners();
  }

  void clearBackgroundImage() {
    _themeSettings = _themeSettings.copyWith(
      clearBackgroundImage: true,
      backgroundRotation: 0,
    );
    _persistSettings();
    notifyListeners();
  }

  // --- Highlights ---

  Future<void> addHighlight({
    required String selectedText,
    required int colorValue,
    String? note,
  }) async {
    final highlight = BookHighlight(
      id: _uuid.v4(),
      bookId: book.id,
      chapterIndex: _currentChapterIndex,
      selectedText: selectedText,
      colorValue: colorValue,
      note: note,
      createdAt: DateTime.now(),
    );

    await _dbHelper.insertHighlight(highlight);
    _highlights.insert(0, highlight);
    notifyListeners();
  }

  Future<void> deleteHighlight(String id) async {
    await _dbHelper.deleteHighlight(id);
    _highlights.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  // --- Vocabulary / Dictionary ---

  Future<void> saveVocabularyWord({
    required String word,
    required String translation,
    String? phonetic,
    String? definition,
    String sourceLang = 'auto',
    String targetLang = 'ru',
    String? contextSnippet,
  }) async {
    final item = VocabularyItem(
      id: _uuid.v4(),
      word: word.trim(),
      translation: translation.trim(),
      phonetic: phonetic,
      definition: definition,
      sourceLang: sourceLang,
      targetLang: targetLang,
      contextSnippet: contextSnippet,
      bookId: book.id,
      bookTitle: book.title,
      addedAt: DateTime.now(),
    );

    await _dbHelper.insertVocabularyItem(item);
    _vocabulary.removeWhere((v) => v.word.toLowerCase() == word.trim().toLowerCase());
    _vocabulary.insert(0, item);
    notifyListeners();
  }

  Future<void> removeVocabularyWord(String id) async {
    await _dbHelper.deleteVocabularyItem(id);
    _vocabulary.removeWhere((v) => v.id == id);
    notifyListeners();
  }

  bool isWordInVocabulary(String word) {
    final clean = word.trim().toLowerCase();
    return _vocabulary.any((v) => v.word.toLowerCase() == clean);
  }

  // --- TTS (Text-to-Speech) Audio Reading ---

  List<String> getChapterParagraphs(int chapterIndex) {
    if (_parsedData == null || chapterIndex < 0 || chapterIndex >= _parsedData!.chapters.length) {
      return [];
    }
    final content = _parsedData!.chapters[chapterIndex].content;
    final paragraphs = content
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isNotEmpty) return paragraphs;

    return content
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void startTts({int startParagraph = 0}) {
    final paragraphs = getChapterParagraphs(_currentChapterIndex);
    if (paragraphs.isEmpty) return;

    TtsService.instance.playChapter(
      paragraphs,
      startIndex: startParagraph,
      onChapterFinished: () {
        if (_currentChapterIndex + 1 < totalChapters) {
          setChapter(_currentChapterIndex + 1);
          startTts(startParagraph: 0);
        }
      },
    );
    notifyListeners();
  }

  void stopTts() {
    TtsService.instance.stop();
    notifyListeners();
  }
}
