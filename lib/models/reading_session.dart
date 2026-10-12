class ReadingSession {
  final int? id;
  final String bookId;
  final String bookTitle;
  final String date; // YYYY-MM-DD
  final int durationSeconds;
  final int wordsRead;
  final int pagesRead;
  final int timestamp; // Milliseconds since epoch

  ReadingSession({
    this.id,
    required this.bookId,
    required this.bookTitle,
    required this.date,
    required this.durationSeconds,
    required this.wordsRead,
    required this.pagesRead,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'date': date,
      'durationSeconds': durationSeconds,
      'wordsRead': wordsRead,
      'pagesRead': pagesRead,
      'timestamp': timestamp,
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    return ReadingSession(
      id: map['id'] as int?,
      bookId: map['bookId'] as String,
      bookTitle: map['bookTitle'] as String? ?? 'Неизвестная книга',
      date: map['date'] as String,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      wordsRead: map['wordsRead'] as int? ?? 0,
      pagesRead: map['pagesRead'] as int? ?? 0,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }
}

class BookReadingStat {
  final String bookId;
  final String bookTitle;
  final int durationSeconds;
  final int wordsRead;
  final int pagesRead;

  BookReadingStat({
    required this.bookId,
    required this.bookTitle,
    required this.durationSeconds,
    required this.wordsRead,
    required this.pagesRead,
  });
}

class ReadingPeriodStats {
  final int totalDurationSeconds;
  final int totalWordsRead;
  final int totalPagesRead;
  final int booksCount;
  final int currentStreakDays;
  final int bestStreakDays;
  final Map<String, int> dailySeconds; // 'YYYY-MM-DD' -> seconds
  final List<BookReadingStat> bookBreakdown;
  final int wordsPerMinute;
  final String peakTimeOfDay; // 'Утро', 'День', 'Вечер', 'Ночь'

  ReadingPeriodStats({
    required this.totalDurationSeconds,
    required this.totalWordsRead,
    required this.totalPagesRead,
    required this.booksCount,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.dailySeconds,
    required this.bookBreakdown,
    required this.wordsPerMinute,
    required this.peakTimeOfDay,
  });

  factory ReadingPeriodStats.empty() {
    return ReadingPeriodStats(
      totalDurationSeconds: 0,
      totalWordsRead: 0,
      totalPagesRead: 0,
      booksCount: 0,
      currentStreakDays: 0,
      bestStreakDays: 0,
      dailySeconds: {},
      bookBreakdown: [],
      wordsPerMinute: 0,
      peakTimeOfDay: '—',
    );
  }
}
