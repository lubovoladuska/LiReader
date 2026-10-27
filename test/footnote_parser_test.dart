import 'package:flutter_test/flutter_test.dart';
import 'package:lireader/models/book_item.dart';
import 'package:lireader/services/book_parser_service.dart';

void main() {
  group('Footnote Engine & Model Tests', () {
    test('BookParsedData preserves footnotes map', () {
      final parsed = BookParsedData(
        title: 'Тестовая книга',
        author: 'Автор',
        chapters: [
          BookChapter(index: 0, title: 'Глава 1', content: 'Текст главы [1] со сноской.'),
        ],
        footnotes: {
          'n_1': 'Пояснение к слову',
          '1': 'Пояснение к слову',
          '[1]': 'Пояснение к слову',
        },
      );

      expect(parsed.footnotes.length, 3);
      expect(parsed.footnotes['n_1'], 'Пояснение к слову');
      expect(parsed.footnotes['1'], 'Пояснение к слову');
      expect(parsed.footnotes['[1]'], 'Пояснение к слову');
    });

    test('FB2 Parser extracts notes from body[name="notes"]', () {
      const fb2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>Война и мир</book-title>
      <author><first-name>Лев</first-name><last-name>Толстой</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Глава I</p></title>
      <p>— Eh bien, mon prince. Gênes et Lucques ne sont plus que des apanages [1] de la famille Buonaparte.</p>
    </section>
  </body>
  <body name="notes">
    <title><p>Примечания</p></title>
    <section id="n_1">
      <title><p>1</p></title>
      <p>Ну что ж, князь, Генуя и Лукка стали теперь поместьями фамилии Бонапарте.</p>
    </section>
  </body>
</FictionBook>''';

      final parsed = BookParserService.parseFb2ContentForTest(fb2Xml, 'Война и мир');
      expect(parsed.title, 'Война и мир');
      expect(parsed.author, 'Лев Толстой');
      expect(parsed.chapters.length, 1);
      expect(parsed.chapters.first.title, 'Глава I');
      expect(parsed.footnotes.containsKey('n_1'), isTrue);
      expect(parsed.footnotes['n_1'], contains('Генуя и Лукка'));
      expect(parsed.footnotes['1'], contains('Генуя и Лукка'));
      expect(parsed.footnotes['[1]'], contains('Генуя и Лукка'));
    });
  });
}
