class VocabularyItem {
  final String id;
  final String word;
  final String translation;
  final String? phonetic;
  final String? definition;
  final String sourceLang;
  final String targetLang;
  final String? contextSnippet;
  final String? bookId;
  final String? bookTitle;
  final DateTime addedAt;

  VocabularyItem({
    required this.id,
    required this.word,
    required this.translation,
    this.phonetic,
    this.definition,
    required this.sourceLang,
    required this.targetLang,
    this.contextSnippet,
    this.bookId,
    this.bookTitle,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'phonetic': phonetic,
      'definition': definition,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'contextSnippet': contextSnippet,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory VocabularyItem.fromMap(Map<String, dynamic> map) {
    return VocabularyItem(
      id: map['id'] as String,
      word: map['word'] as String,
      translation: map['translation'] as String,
      phonetic: map['phonetic'] as String?,
      definition: map['definition'] as String?,
      sourceLang: map['sourceLang'] as String? ?? 'auto',
      targetLang: map['targetLang'] as String? ?? 'ru',
      contextSnippet: map['contextSnippet'] as String?,
      bookId: map['bookId'] as String?,
      bookTitle: map['bookTitle'] as String?,
      addedAt: DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
