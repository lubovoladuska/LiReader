import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/book_item.dart';
import '../models/reader_theme_settings.dart';
import '../services/book_parser_service.dart';
import '../services/database_helper.dart';

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
  ReaderThemeSettings _themeSettings = const ReaderThemeSettings();

  ReaderProvider({required this.book}) {
    _currentChapterIndex = book.currentChapterOrPage;
    _init();
  }

  bool get isLoading => _isLoading;
  BookParsedData? get parsedData => _parsedData;
  int get currentChapterIndex => _currentChapterIndex;
  double get chapterScrollProgress => _chapterScrollProgress;
  bool get isMenuVisible => _isMenuVisible;

  List<BookHighlight> get highlights => _highlights;
  ReaderThemeSettings get themeSettings => _themeSettings;

  // Backwards compatibility shortcuts
  double get fontSize => _themeSettings.fontSize;
  double get lineHeight => _themeSettings.lineHeight;

  int get totalChapters => _parsedData?.chapters.length ?? 1;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _parsedData = await BookParserService.parseBook(book);
      _highlights = await _dbHelper.getHighlightsForBook(book.id);

      // Load persisted global theme settings
      final settingsJson = await _dbHelper.getSetting('reader_theme_settings');
      if (settingsJson != null) {
        try {
          final map = json.decode(settingsJson) as Map<String, dynamic>;
          _themeSettings = ReaderThemeSettings.fromMap(map);
        } catch (_) {}
      }

      // Clamp chapter index
      if (_currentChapterIndex >= totalChapters) {
        _currentChapterIndex = 0;
      }
    } catch (e) {
      debugPrint('Error initializing reader: $e');
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

  void setChapter(int index) {
    if (index >= 0 && index < totalChapters) {
      _currentChapterIndex = index;
      _dbHelper.updateBookProgress(book.id, index, 0.0);
      notifyListeners();
    }
  }

  void saveScrollProgress(double offset, {double fractional = 0.0}) {
    _chapterScrollProgress = fractional.clamp(0.0, 1.0);
    _dbHelper.updateBookProgress(book.id, _currentChapterIndex, offset);
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
}
