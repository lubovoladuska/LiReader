enum BookFormat {
  epub,
  pdf,
  fb2,
  txt,
  markdown,
  unknown,
}

class ShelfItem {
  final String id;
  final String name;
  final int iconCode;
  final DateTime createdAt;

  ShelfItem({
    required this.id,
    required this.name,
    this.iconCode = 0xe59c, // Icons.bookmark_rounded
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ShelfItem.fromMap(Map<String, dynamic> map) {
    return ShelfItem(
      id: map['id'],
      name: map['name'],
      iconCode: map['iconCode'] ?? 0xe59c,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class BookItem {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final BookFormat format;
  final int totalChaptersOrPages;
  final int currentChapterOrPage;
  final double scrollProgress;
  final DateTime addedAt;
  final DateTime lastReadAt;
  final String? coverPath;
  final String? shelfId;
  final bool isFavorite;

  BookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    this.totalChaptersOrPages = 1,
    this.currentChapterOrPage = 0,
    this.scrollProgress = 0.0,
    required this.addedAt,
    required this.lastReadAt,
    this.coverPath,
    this.shelfId,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'format': format.name,
      'totalChaptersOrPages': totalChaptersOrPages,
      'currentChapterOrPage': currentChapterOrPage,
      'scrollProgress': scrollProgress,
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt.toIso8601String(),
      'coverPath': coverPath,
      'shelfId': shelfId,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory BookItem.fromMap(Map<String, dynamic> map) {
    return BookItem(
      id: map['id'],
      title: map['title'] ?? 'Без названия',
      author: map['author'] ?? 'Неизвестный автор',
      filePath: map['filePath'],
      format: BookFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => BookFormat.unknown,
      ),
      totalChaptersOrPages: map['totalChaptersOrPages'] ?? 1,
      currentChapterOrPage: map['currentChapterOrPage'] ?? 0,
      scrollProgress: (map['scrollProgress'] as num?)?.toDouble() ?? 0.0,
      addedAt: DateTime.tryParse(map['addedAt'] ?? '') ?? DateTime.now(),
      lastReadAt: DateTime.tryParse(map['lastReadAt'] ?? '') ?? DateTime.now(),
      coverPath: map['coverPath'],
      shelfId: map['shelfId'],
      isFavorite: (map['isFavorite'] == 1 || map['isFavorite'] == true),
    );
  }

  BookItem copyWith({
    String? title,
    String? author,
    int? totalChaptersOrPages,
    int? currentChapterOrPage,
    double? scrollProgress,
    DateTime? lastReadAt,
    String? coverPath,
    String? shelfId,
    bool? isFavorite,
    bool clearShelf = false,
  }) {
    return BookItem(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath,
      format: format,
      totalChaptersOrPages: totalChaptersOrPages ?? this.totalChaptersOrPages,
      currentChapterOrPage: currentChapterOrPage ?? this.currentChapterOrPage,
      scrollProgress: scrollProgress ?? this.scrollProgress,
      addedAt: addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      coverPath: coverPath ?? this.coverPath,
      shelfId: clearShelf ? null : (shelfId ?? this.shelfId),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class BookHighlight {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String selectedText;
  final int colorValue;
  final String? note;
  final DateTime createdAt;

  BookHighlight({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.selectedText,
    required this.colorValue,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'selectedText': selectedText,
      'colorValue': colorValue,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookHighlight.fromMap(Map<String, dynamic> map) {
    return BookHighlight(
      id: map['id'],
      bookId: map['bookId'],
      chapterIndex: map['chapterIndex'] ?? 0,
      selectedText: map['selectedText'] ?? '',
      colorValue: map['colorValue'] ?? 0xFFFFEE8C,
      note: map['note'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
