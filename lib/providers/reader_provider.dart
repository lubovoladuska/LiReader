import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/book_item.dart';
import '../services/book_parser_service.dart';
import '../services/database_helper.dart';

class ReaderProvider extends ChangeNotifier {
  final BookItem book;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  bool _isLoading = true;
  BookParsedData? _parsedData;
  int _currentChapterIndex = 0;
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  bool _isMenuVisible = true;
  List<BookHighlight> _highlights = [];

  ReaderProvider({required this.book}) {
    _currentChapterIndex = book.currentChapterOrPage;
    _init();
  }

  bool get isLoading => _isLoading;
  BookParsedData? get parsedData => _parsedData;
  int get currentChapterIndex => _currentChapterIndex;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  bool get isMenuVisible => _isMenuVisible;
  List<BookHighlight> get highlights => _highlights;

  int get totalChapters => _parsedData?.chapters.length ?? 1;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _parsedData = await BookParserService.parseBook(book);
      _highlights = await _dbHelper.getHighlightsForBook(book.id);

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

  void saveScrollProgress(double offset) {
    _dbHelper.updateBookProgress(book.id, _currentChapterIndex, offset);
  }

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);
    notifyListeners();
  }

  void setLineHeight(double height) {
    _lineHeight = height.clamp(1.2, 2.4);
    notifyListeners();
  }

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
