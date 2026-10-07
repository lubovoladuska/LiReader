import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/book_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lireader.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String basePath;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      basePath = appDocDir.path;
    } catch (_) {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['APPDATA'] ?? '.';
      basePath = p.join(userProfile, 'Documents');
    }

    final path = p.join(basePath, 'LiReader', filePath);

    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        filePath TEXT NOT NULL,
        format TEXT NOT NULL,
        totalChaptersOrPages INTEGER NOT NULL,
        currentChapterOrPage INTEGER NOT NULL,
        scrollProgress REAL NOT NULL,
        addedAt TEXT NOT NULL,
        lastReadAt TEXT NOT NULL,
        coverPath TEXT,
        shelfId TEXT,
        isFavorite INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE shelves (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE highlights (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        chapterIndex INTEGER NOT NULL,
        selectedText TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE books ADD COLUMN shelfId TEXT');
        await db.execute('ALTER TABLE books ADD COLUMN isFavorite INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shelves (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            iconCode INTEGER NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
  }

  // Global Settings Storage
  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BookItem>> getBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'lastReadAt DESC');
    return maps.map((e) => BookItem.fromMap(e)).toList();
  }

  Future<void> insertBook(BookItem book) async {
    final db = await database;
    await db.insert('books', book.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBookDetails(String id, {String? title, String? author, String? coverPath}) async {
    final db = await database;
    final Map<String, dynamic> values = {};
    if (title != null) values['title'] = title;
    if (author != null) values['author'] = author;
    if (coverPath != null) values['coverPath'] = coverPath;
    if (values.isNotEmpty) {
      await db.update('books', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> updateBookProgress(String id, int chapter, double scrollProgress) async {
    final db = await database;
    await db.update(
      'books',
      {
        'currentChapterOrPage': chapter,
        'scrollProgress': scrollProgress,
        'lastReadAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateBookShelf(String bookId, String? shelfId) async {
    final db = await database;
    await db.update(
      'books',
      {'shelfId': shelfId},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> toggleBookFavorite(String bookId, bool isFavorite) async {
    final db = await database;
    await db.update(
      'books',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
    await db.delete('highlights', where: 'bookId = ?', whereArgs: [id]);
  }

  // Shelves
  Future<List<ShelfItem>> getShelves() async {
    final db = await database;
    final maps = await db.query('shelves', orderBy: 'createdAt ASC');
    return maps.map((e) => ShelfItem.fromMap(e)).toList();
  }

  Future<void> insertShelf(ShelfItem shelf) async {
    final db = await database;
    await db.insert('shelves', shelf.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteShelf(String id) async {
    final db = await database;
    await db.delete('shelves', where: 'id = ?', whereArgs: [id]);
    await db.update('books', {'shelfId': null}, where: 'shelfId = ?', whereArgs: [id]);
  }

  // Highlights
  Future<List<BookHighlight>> getHighlightsForBook(String bookId) async {
    final db = await database;
    final maps = await db.query(
      'highlights',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => BookHighlight.fromMap(e)).toList();
  }

  Future<void> insertHighlight(BookHighlight highlight) async {
    final db = await database;
    await db.insert('highlights', highlight.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteHighlight(String id) async {
    final db = await database;
    await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }
}
