import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/book_item.dart';
import '../models/reading_session.dart';

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
        version: 4,
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

    await db.execute('''
      CREATE TABLE reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId TEXT NOT NULL,
        bookTitle TEXT NOT NULL,
        date TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        wordsRead INTEGER NOT NULL,
        pagesRead INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
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
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reading_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bookId TEXT NOT NULL,
            bookTitle TEXT NOT NULL,
            date TEXT NOT NULL,
            durationSeconds INTEGER NOT NULL,
            wordsRead INTEGER NOT NULL,
            pagesRead INTEGER NOT NULL,
            timestamp INTEGER NOT NULL
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

  Future<void> updateBookDetails(String id, {String? title, String? author, String? coverPath, String? filePath}) async {
    final db = await database;
    final Map<String, dynamic> values = {};
    if (title != null) values['title'] = title;
    if (author != null) values['author'] = author;
    if (coverPath != null) values['coverPath'] = coverPath;
    if (filePath != null) values['filePath'] = filePath;
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

  // Reading Sessions & Detailed Stats
  Future<void> recordReadingSession({
    required String bookId,
    required String bookTitle,
    required int durationSeconds,
    required int wordsRead,
    required int pagesRead,
  }) async {
    if (durationSeconds < 3 && wordsRead <= 0 && pagesRead <= 0) return;
    final db = await database;
    final now = DateTime.now();
    final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final session = ReadingSession(
      bookId: bookId,
      bookTitle: bookTitle,
      date: dateStr,
      durationSeconds: durationSeconds,
      wordsRead: wordsRead,
      pagesRead: pagesRead,
      timestamp: now.millisecondsSinceEpoch,
    );
    await db.insert('reading_sessions', session.toMap());
  }

  Future<ReadingPeriodStats> getReadingStats({String period = 'week'}) async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Calculate streak metrics from all sessions history
    final distinctDatesRes = await db.rawQuery(
      'SELECT DISTINCT date FROM reading_sessions WHERE durationSeconds >= 30 ORDER BY date DESC'
    );
    final distinctDateStrs = distinctDatesRes.map((r) => r['date'] as String).toList();
    
    int currentStreak = 0;
    int bestStreak = 0;

    if (distinctDateStrs.isNotEmpty) {
      final nowDay = DateTime(now.year, now.month, now.day);
      final todayDateStr = todayStr;
      final yesterday = nowDay.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // Current streak check
      if (distinctDateStrs.contains(todayDateStr) || distinctDateStrs.contains(yesterdayStr)) {
        var checkDate = distinctDateStrs.contains(todayDateStr) ? nowDay : yesterday;
        while (true) {
          final s = '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
          if (distinctDateStrs.contains(s)) {
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      }

      // Best streak calculation
      final sortedAscDates = distinctDateStrs.map((s) => DateTime.parse(s)).toList()..sort();
      if (sortedAscDates.isNotEmpty) {
        int tempStreak = 1;
        bestStreak = 1;
        for (int i = 1; i < sortedAscDates.length; i++) {
          final diff = sortedAscDates[i].difference(sortedAscDates[i - 1]).inDays;
          if (diff == 1) {
            tempStreak++;
            if (tempStreak > bestStreak) bestStreak = tempStreak;
          } else if (diff > 1) {
            tempStreak = 1;
          }
        }
      }
    }
    if (currentStreak > bestStreak) bestStreak = currentStreak;

    // 2. Fetch sessions according to selected period
    String? whereClause;
    List<dynamic>? whereArgs;

    if (period == 'today') {
      whereClause = 'date = ?';
      whereArgs = [todayStr];
    } else if (period == 'week') {
      final start = now.subtract(const Duration(days: 6));
      final startStr = '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      whereClause = 'date >= ?';
      whereArgs = [startStr];
    } else if (period == 'month') {
      final start = now.subtract(const Duration(days: 29));
      final startStr = '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      whereClause = 'date >= ?';
      whereArgs = [startStr];
    } // 'all' has whereClause = null

    final rawSessions = await db.query(
      'reading_sessions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    final sessions = rawSessions.map((e) => ReadingSession.fromMap(e)).toList();

    int totalDuration = 0;
    int totalWords = 0;
    int totalPages = 0;
    final Set<String> distinctBooks = {};
    final Map<String, BookReadingStat> booksMap = {};
    final Map<int, int> hourBucketSeconds = {
      0: 0, // Night (23-04)
      1: 0, // Morning (05-11)
      2: 0, // Day (12-16)
      3: 0, // Evening (17-22)
    };

    for (final s in sessions) {
      totalDuration += s.durationSeconds;
      totalWords += s.wordsRead;
      totalPages += s.pagesRead;
      distinctBooks.add(s.bookId);

      // Book breakdown aggregation
      if (booksMap.containsKey(s.bookId)) {
        final existing = booksMap[s.bookId]!;
        booksMap[s.bookId] = BookReadingStat(
          bookId: s.bookId,
          bookTitle: s.bookTitle.isNotEmpty ? s.bookTitle : existing.bookTitle,
          durationSeconds: existing.durationSeconds + s.durationSeconds,
          wordsRead: existing.wordsRead + s.wordsRead,
          pagesRead: existing.pagesRead + s.pagesRead,
        );
      } else {
        booksMap[s.bookId] = BookReadingStat(
          bookId: s.bookId,
          bookTitle: s.bookTitle,
          durationSeconds: s.durationSeconds,
          wordsRead: s.wordsRead,
          pagesRead: s.pagesRead,
        );
      }

      // Time of day bucket
      final sessionTime = DateTime.fromMillisecondsSinceEpoch(s.timestamp);
      final h = sessionTime.hour;
      if (h >= 5 && h < 12) {
        hourBucketSeconds[1] = (hourBucketSeconds[1] ?? 0) + s.durationSeconds;
      } else if (h >= 12 && h < 17) {
        hourBucketSeconds[2] = (hourBucketSeconds[2] ?? 0) + s.durationSeconds;
      } else if (h >= 17 && h < 23) {
        hourBucketSeconds[3] = (hourBucketSeconds[3] ?? 0) + s.durationSeconds;
      } else {
        hourBucketSeconds[0] = (hourBucketSeconds[0] ?? 0) + s.durationSeconds;
      }
    }

    // 3. Compute daily seconds for the 7-day bar chart
    final Map<String, int> dailySecondsMap = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dStr = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dailySecondsMap[dStr] = 0;
    }
    final sevenDaysAgo = now.subtract(const Duration(days: 6));
    final sevenDaysAgoStr = '${sevenDaysAgo.year.toString().padLeft(4, '0')}-${sevenDaysAgo.month.toString().padLeft(2, '0')}-${sevenDaysAgo.day.toString().padLeft(2, '0')}';
    final recentSessions = await db.query(
      'reading_sessions',
      where: 'date >= ?',
      whereArgs: [sevenDaysAgoStr],
    );
    for (final r in recentSessions) {
      final d = r['date'] as String;
      final dur = r['durationSeconds'] as int? ?? 0;
      if (dailySecondsMap.containsKey(d)) {
        dailySecondsMap[d] = dailySecondsMap[d]! + dur;
      }
    }

    // 4. Words per minute
    final wpm = totalDuration > 30 && totalWords > 0
        ? (totalWords / (totalDuration / 60.0)).round()
        : 0;

    // 5. Peak time of day
    String peakTime = '—';
    if (totalDuration > 0) {
      var maxBucket = 1;
      var maxSecs = -1;
      hourBucketSeconds.forEach((bucket, secs) {
        if (secs > maxSecs) {
          maxSecs = secs;
          maxBucket = bucket;
        }
      });
      if (maxBucket == 1) {
        peakTime = 'Утро (05:00 - 12:00)';
      } else if (maxBucket == 2) {
        peakTime = 'День (12:00 - 17:00)';
      } else if (maxBucket == 3) {
        peakTime = 'Вечер (17:00 - 23:00)';
      } else {
        peakTime = 'Ночь (23:00 - 05:00)';
      }
    }

    final bookList = booksMap.values.toList()
      ..sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));

    return ReadingPeriodStats(
      totalDurationSeconds: totalDuration,
      totalWordsRead: totalWords,
      totalPagesRead: totalPages,
      booksCount: distinctBooks.length,
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
      dailySeconds: dailySecondsMap,
      bookBreakdown: bookList,
      wordsPerMinute: wpm,
      peakTimeOfDay: peakTime,
    );
  }
}
