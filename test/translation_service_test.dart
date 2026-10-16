import 'package:flutter_test/flutter_test.dart';
import 'package:lireader/models/vocabulary_item.dart';
import 'package:lireader/services/translation_service.dart';

void main() {
  group('VocabularyItem Model Tests', () {
    test('toMap and fromMap preserves all fields correctly', () {
      final now = DateTime.now();
      final item = VocabularyItem(
        id: 'test-123',
        word: 'serendipity',
        translation: 'интуитивная прозорливость',
        phonetic: 'ˌser.ənˈdɪp.ə.ti',
        definition: 'Счастливая случайность',
        sourceLang: 'en',
        targetLang: 'ru',
        contextSnippet: 'It was sheer serendipity that they met.',
        bookId: 'book-99',
        bookTitle: 'Test Book',
        addedAt: now,
      );

      final map = item.toMap();
      final fromMap = VocabularyItem.fromMap(map);

      expect(fromMap.id, equals('test-123'));
      expect(fromMap.word, equals('serendipity'));
      expect(fromMap.translation, equals('интуитивная прозорливость'));
      expect(fromMap.phonetic, equals('ˌser.ənˈdɪp.ə.ti'));
      expect(fromMap.definition, equals('Счастливая случайность'));
      expect(fromMap.sourceLang, equals('en'));
      expect(fromMap.targetLang, equals('ru'));
      expect(fromMap.contextSnippet, equals('It was sheer serendipity that they met.'));
      expect(fromMap.bookId, equals('book-99'));
      expect(fromMap.bookTitle, equals('Test Book'));
      expect(fromMap.addedAt.year, equals(now.year));
    });

    test('fromMap handles null optional fields gracefully', () {
      final map = {
        'id': 'abc',
        'word': 'test',
        'translation': 'тест',
      };

      final item = VocabularyItem.fromMap(map);
      expect(item.id, equals('abc'));
      expect(item.word, equals('test'));
      expect(item.translation, equals('тест'));
      expect(item.phonetic, isNull);
      expect(item.definition, isNull);
      expect(item.sourceLang, equals('auto'));
      expect(item.targetLang, equals('ru'));
      expect(item.contextSnippet, isNull);
      expect(item.bookId, isNull);
    });
  });

  group('TranslationResult Tests', () {
    test('creates TranslationResult with alternatives', () {
      final res = TranslationResult(
        originalText: 'hello',
        translatedText: 'привет',
        sourceLang: 'en',
        targetLang: 'ru',
        alternativeTranslations: ['здравствуйте', 'алло'],
        partOfSpeech: 'Interjection',
        definition: 'Used as a greeting.',
      );

      expect(res.originalText, equals('hello'));
      expect(res.translatedText, equals('привет'));
      expect(res.alternativeTranslations.length, equals(2));
      expect(res.partOfSpeech, equals('Interjection'));
      expect(res.definition, equals('Used as a greeting.'));
    });
  });
}
