import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/book_item.dart';
import '../services/book_parser_service.dart';
import '../services/database_helper.dart';

enum LibraryFilter {
  all,
  reading,
  favorites,
  shelf,
}

enum LibraryViewMode {
  grid,
  list,
}

enum LibrarySortBy {
  lastRead('Недавно открытые'),
  title('По названию (А-Я)'),
  author('По автору'),
  format('По формату файла');

  final String label;
  const LibrarySortBy(this.label);
}

class LibraryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  List<BookItem> _books = [];
  List<ShelfItem> _shelves = [];
  bool _isLoading = false;
  String _searchQuery = '';
  LibraryFilter _activeFilter = LibraryFilter.all;
  String? _selectedShelfId;
  BookFormat? _selectedFormat;
  LibraryViewMode _viewMode = LibraryViewMode.grid;
  LibrarySortBy _sortBy = LibrarySortBy.lastRead;

  List<BookItem> get allBooks => _books;
  List<ShelfItem> get shelves => _shelves;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  LibraryFilter get activeFilter => _activeFilter;
  String? get selectedShelfId => _selectedShelfId;
  BookFormat? get selectedFormat => _selectedFormat;
  LibraryViewMode get viewMode => _viewMode;
  LibrarySortBy get sortBy => _sortBy;

  ShelfItem? get activeShelf {
    if (_selectedShelfId == null) return null;
    return _shelves.where((s) => s.id == _selectedShelfId).firstOrNull;
  }

  List<BookItem> get books {
    List<BookItem> filtered = List.from(_books);

    switch (_activeFilter) {
      case LibraryFilter.all:
        break;
      case LibraryFilter.reading:
        filtered = filtered.where((b) => b.currentChapterOrPage > 0 || b.scrollProgress > 0).toList();
        break;
      case LibraryFilter.favorites:
        filtered = filtered.where((b) => b.isFavorite).toList();
        break;
      case LibraryFilter.shelf:
        filtered = filtered.where((b) => b.shelfId == _selectedShelfId).toList();
        break;
    }

    if (_selectedFormat != null) {
      if (_selectedFormat == BookFormat.txt) {
        filtered = filtered.where((b) => b.format == BookFormat.txt || b.format == BookFormat.markdown).toList();
      } else {
        filtered = filtered.where((b) => b.format == _selectedFormat).toList();
      }
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case LibrarySortBy.lastRead:
        filtered.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
        break;
      case LibrarySortBy.title:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySortBy.author:
        filtered.sort((a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase()));
        break;
      case LibrarySortBy.format:
        filtered.sort((a, b) => a.format.name.compareTo(b.format.name));
        break;
    }

    return filtered;
  }



  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();
    try {
      _books = await _dbHelper.getBooks();
      _shelves = await _dbHelper.getShelves();

      // Auto-heal missing covers for existing books
      _healMissingCovers();
    } catch (e) {
      debugPrint('Error loading library: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _healMissingCovers() async {
    for (int i = 0; i < _books.length; i++) {
      var book = _books[i];
      // 1. Auto-heal broken/cached file path if possible
      if (!File(book.filePath).existsSync()) {
        try {
          final resolvedFile = await BookParserService.resolveBookFile(book.filePath);
          if (resolvedFile != null) {
            final permPath = await BookParserService.copyToPermanentStorage(resolvedFile.path);
            await _dbHelper.updateBookDetails(book.id, filePath: permPath);
            book = book.copyWith(filePath: permPath);
            _books[i] = book;
          }
        } catch (_) {}
      }

      final coverExists = book.coverPath != null && File(book.coverPath!).existsSync();
      if (!coverExists && (book.format == BookFormat.epub || book.format == BookFormat.fb2)) {
        try {
          final newCoverPath = await BookParserService.extractCoverForBook(book);
          if (newCoverPath != null && File(newCoverPath).existsSync()) {
            await _dbHelper.updateBookDetails(book.id, coverPath: newCoverPath);
            _books[i] = book.copyWith(coverPath: newCoverPath);
            notifyListeners();
          }
        } catch (_) {}
      }
    }
  }

  Future<bool> relinkBook(String bookId, String newFilePath) async {
    try {
      final permPath = await BookParserService.copyToPermanentStorage(newFilePath);
      final idx = _books.indexWhere((b) => b.id == bookId);
      if (idx == -1) return false;

      var book = _books[idx].copyWith(filePath: permPath);
      final newCover = await BookParserService.extractCoverForBook(book);
      if (newCover != null) {
        book = book.copyWith(coverPath: newCover);
      }

      await _dbHelper.updateBookDetails(
        bookId,
        filePath: permPath,
        coverPath: newCover,
      );

      _books[idx] = book;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error relinking book: $e');
      return false;
    }
  }

  void setFilter(LibraryFilter filter, {String? shelfId}) {
    _activeFilter = filter;
    _selectedShelfId = shelfId;
    notifyListeners();
  }

  void setFormatFilter(BookFormat? format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void setViewMode(LibraryViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setSortBy(LibrarySortBy sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }


  Future<BookItem?> pickAndAddBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf', 'fb2', 'zip', 'txt', 'md'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          final newBook = await BookParserService.createBookItemFromFile(filePath);
          final bookWithShelf = newBook.copyWith(
            shelfId: _activeFilter == LibraryFilter.shelf ? _selectedShelfId : null,
          );
          await _dbHelper.insertBook(bookWithShelf);
          await loadLibrary();
          return bookWithShelf;
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

  Future<void> toggleFavorite(String bookId) async {
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      final newFav = !_books[idx].isFavorite;
      await _dbHelper.toggleBookFavorite(bookId, newFav);
      _books[idx] = _books[idx].copyWith(isFavorite: newFav);
      notifyListeners();
    }
  }

  Future<void> updateBookDetails(String bookId, {String? title, String? author}) async {
    await _dbHelper.updateBookDetails(bookId, title: title, author: author);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      _books[idx] = _books[idx].copyWith(
        title: title,
        author: author,
      );
      notifyListeners();
    }
  }

  Future<void> assignBookToShelf(String bookId, String? shelfId) async {
    await _dbHelper.updateBookShelf(bookId, shelfId);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      _books[idx] = _books[idx].copyWith(
        shelfId: shelfId,
        clearShelf: shelfId == null,
      );
      notifyListeners();
    }
  }


  Future<ShelfItem> createShelf(String name) async {
    final shelf = ShelfItem(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await _dbHelper.insertShelf(shelf);
    _shelves.add(shelf);
    notifyListeners();
    return shelf;
  }


  Future<void> deleteShelf(String shelfId) async {
    await _dbHelper.deleteShelf(shelfId);
    _shelves.removeWhere((s) => s.id == shelfId);
    for (int i = 0; i < _books.length; i++) {
      if (_books[i].shelfId == shelfId) {
        _books[i] = _books[i].copyWith(clearShelf: true);
      }
    }
    if (_selectedShelfId == shelfId) {
      _activeFilter = LibraryFilter.all;
      _selectedShelfId = null;
    }
    notifyListeners();
  }

  Future<void> removeBook(String id) async {
    await _dbHelper.deleteBook(id);
    _books.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}
