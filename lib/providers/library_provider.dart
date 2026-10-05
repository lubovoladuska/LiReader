import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/book_item.dart';
import '../services/book_parser_service.dart';
import '../services/database_helper.dart';

class LibraryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<BookItem> _books = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<BookItem> get books {
    if (_searchQuery.trim().isEmpty) {
      return _books;
    }
    final q = _searchQuery.toLowerCase();
    return _books.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  Future<void> loadBooks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _books = await _dbHelper.getBooks();
    } catch (e) {
      debugPrint('Error loading books: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<BookItem?> pickAndAddBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf', 'fb2', 'txt', 'md'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          final newBook = await BookParserService.createBookItemFromFile(filePath);
          await _dbHelper.insertBook(newBook);
          await loadBooks();
          return newBook;
        }
      }
    } catch (e) {
      debugPrint('Error picking book: $e');
    }
    return null;
  }

  Future<void> updateProgress(String bookId, int chapter, double scrollProgress) async {
    await _dbHelper.updateBookProgress(bookId, chapter, scrollProgress);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      _books[idx] = _books[idx].copyWith(
        currentChapterOrPage: chapter,
        scrollProgress: scrollProgress,
        lastReadAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<void> removeBook(String id) async {
    await _dbHelper.deleteBook(id);
    _books.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}
