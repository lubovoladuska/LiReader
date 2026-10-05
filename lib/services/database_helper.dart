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

    final dbPath = await getApplicationDocumentsDirectory();
    final path = p.join(dbPath.path, 'LiReader', filePath);

    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
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
        coverPath TEXT
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

  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
    await db.delete('highlights', where: 'bookId = ?', whereArgs: [id]);
  }

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
