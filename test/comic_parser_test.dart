import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:lireader/services/comic_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComicParserService Tests', () {
    test('naturalCompare correctly sorts numbered filenames', () {
      final list = [
        'page_10.jpg',
        'page_2.jpg',
        'page_1.jpg',
        'page_20.jpg',
        'page_3.jpg',
      ];

      list.sort(ComicParserService.naturalCompare);

      expect(list, [
        'page_1.jpg',
        'page_2.jpg',
        'page_3.jpg',
        'page_10.jpg',
        'page_20.jpg',
      ]);
    });

    test('naturalCompare handles chapter and page combinations', () {
      final list = [
        'ch2_page_1.png',
        'ch1_page_10.png',
        'ch1_page_2.png',
        'ch1_page_1.png',
      ];

      list.sort(ComicParserService.naturalCompare);

      expect(list, [
        'ch1_page_1.png',
        'ch1_page_2.png',
        'ch1_page_10.png',
        'ch2_page_1.png',
      ]);
    });

    test('isImageFile correctly identifies image formats', () {
      expect(ComicParserService.isImageFile('01.jpg'), isTrue);
      expect(ComicParserService.isImageFile('01.jpeg'), isTrue);
      expect(ComicParserService.isImageFile('01.png'), isTrue);
      expect(ComicParserService.isImageFile('01.webp'), isTrue);
      expect(ComicParserService.isImageFile('01.gif'), isTrue);
      expect(ComicParserService.isImageFile('01.bmp'), isTrue);

      expect(ComicParserService.isImageFile('ComicInfo.xml'), isFalse);
      expect(ComicParserService.isImageFile('metadata.json'), isFalse);
      expect(ComicParserService.isImageFile('notes.txt'), isFalse);
    });

    test('isIgnoredEntry filters system and hidden files', () {
      expect(ComicParserService.isIgnoredEntry('__MACOSX/._01.jpg'), isTrue);
      expect(ComicParserService.isIgnoredEntry('folder/__MACOSX/._01.jpg'), isTrue);
      expect(ComicParserService.isIgnoredEntry('.DS_Store'), isTrue);
      expect(ComicParserService.isIgnoredEntry('Thumbs.db'), isTrue);
      expect(ComicParserService.isIgnoredEntry('._cover.png'), isTrue);

      expect(ComicParserService.isIgnoredEntry('chapter1/01.jpg'), isFalse);
      expect(ComicParserService.isIgnoredEntry('page_01.png'), isFalse);
    });

    test('inspectComic correctly parses archive with ComicInfo.xml and pages', () async {
      final tempDir = Directory.systemTemp.createTempSync('comic_test_');
      final cbzPath = '${tempDir.path}/test_comic.cbz';

      try {
        final archive = Archive();

        // 1. Add ComicInfo.xml
        const comicXml = '''<?xml version="1.0" encoding="utf-8"?>
<ComicInfo>
  <Title>The Golden Adventure</Title>
  <Series>Epic Saga</Series>
  <Number>1</Number>
  <Writer>Stan Lee</Writer>
  <Summary>A legendary adventure begins!</Summary>
</ComicInfo>''';
        final xmlBytes = utf8.encode(comicXml);
        archive.addFile(ArchiveFile('ComicInfo.xml', xmlBytes.length, xmlBytes));

        // 2. Add dummy image pages (1x1 transparent PNG)
        final dummyPng = [
          137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
          0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196,
          137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0,
          5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174,
          66, 96, 130
        ];

        archive.addFile(ArchiveFile('page_02.png', dummyPng.length, dummyPng));
        archive.addFile(ArchiveFile('page_01.png', dummyPng.length, dummyPng));
        archive.addFile(ArchiveFile('page_10.png', dummyPng.length, dummyPng));

        // Encode as ZIP (CBZ)
        final zipBytes = ZipEncoder().encode(archive)!;
        File(cbzPath).writeAsBytesSync(zipBytes);

        // Inspect
        final meta = await ComicParserService.inspectComic(cbzPath);

        expect(meta.title, 'Epic Saga #1: The Golden Adventure');
        expect(meta.author, 'Stan Lee');
        expect(meta.totalPages, 3);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
