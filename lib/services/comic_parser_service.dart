import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../models/book_item.dart';
import 'book_parser_service.dart';

class ComicMetadata {
  final String title;
  final String author;
  final int totalPages;
  final String? coverPath;

  ComicMetadata({
    required this.title,
    required this.author,
    required this.totalPages,
    this.coverPath,
  });
}

class ComicParserService {
  static const _uuid = Uuid();
  static const Set<String> supportedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  };

  /// Checks if a file name represents an image.
  static bool isImageFile(String name) {
    final lower = name.toLowerCase();
    final ext = p.extension(lower);
    return supportedImageExtensions.contains(ext);
  }

  /// Checks if an entry should be ignored (macOS metadata, hidden files, directories).
  static bool isIgnoredEntry(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('__macosx/') ||
        lower.contains('/__macosx/') ||
        p.basename(lower).startsWith('._') ||
        p.basename(lower) == '.ds_store' ||
        p.basename(lower) == 'thumbs.db') {
      return true;
    }
    return false;
  }

  /// Natural alphanumeric sort comparison (e.g., page 2 before page 10).
  static int naturalCompare(String a, String b) {
    final nameA = p.basename(a);
    final nameB = p.basename(b);
    final regExp = RegExp(r'(\d+|\D+)');
    final matchesA = regExp.allMatches(nameA).map((m) => m.group(0)!).toList();
    final matchesB = regExp.allMatches(nameB).map((m) => m.group(0)!).toList();

    final minLen = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
    for (int i = 0; i < minLen; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];
      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else {
        final cmp = partA.toLowerCase().compareTo(partB.toLowerCase());
        if (cmp != 0) return cmp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  /// Directory where extracted comic pages are cached for smooth reading.
  static Future<Directory> getComicCacheDir(String bookId) async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocsDir.path, 'LiReader', 'comics', bookId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Safely deletes extracted comic pages cache when a book is removed.
  static Future<void> deleteComicCache(String bookId) async {
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDocsDir.path, 'LiReader', 'comics', bookId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting comic cache for book $bookId: $e');
    }
  }

  /// Directory for covers.
  static Future<Directory> _getCoversDir() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocsDir.path, 'LiReader', 'covers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Inspects a CBZ / ZIP comic archive to extract metadata and cover.
  static Future<ComicMetadata> inspectComic(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return ComicMetadata(
        title: p.basenameWithoutExtension(filePath),
        author: 'Комикс / Манга',
        totalPages: 1,
      );
    }

    final bytes = await file.readAsBytes();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      debugPrint('Error decoding comic ZIP archive: $e');
      return ComicMetadata(
        title: p.basenameWithoutExtension(filePath),
        author: 'Комикс / Манга',
        totalPages: 1,
      );
    }

    // Filter image entries and sort naturally
    final imageFiles = <ArchiveFile>[];
    ArchiveFile? comicInfoFile;

    for (final f in archive.files) {
      if (!f.isFile || isIgnoredEntry(f.name)) continue;
      final lowerName = f.name.toLowerCase();
      if (lowerName.endsWith('comicinfo.xml')) {
        comicInfoFile = f;
      } else if (isImageFile(f.name)) {
        imageFiles.add(f);
      }
    }

    imageFiles.sort((a, b) => naturalCompare(a.name, b.name));

    String title = p.basenameWithoutExtension(filePath);
    String author = 'Комикс / Манга';

    // Parse ComicInfo.xml if available
    if (comicInfoFile != null) {
      try {
        final content = comicInfoFile.content as List<int>;
        final xmlStr = utf8.decode(content, allowMalformed: true);
        final doc = XmlDocument.parse(xmlStr);

        final parsedTitle = doc.findAllElements('Title').firstOrNull?.innerText.trim();
        final parsedSeries = doc.findAllElements('Series').firstOrNull?.innerText.trim();
        final parsedNumber = doc.findAllElements('Number').firstOrNull?.innerText.trim();
        final parsedWriter = doc.findAllElements('Writer').firstOrNull?.innerText.trim() ??
            doc.findAllElements('Author').firstOrNull?.innerText.trim();

        if (parsedSeries != null && parsedSeries.isNotEmpty) {
          if (parsedNumber != null && parsedNumber.isNotEmpty) {
            title = '$parsedSeries #$parsedNumber';
            if (parsedTitle != null && parsedTitle.isNotEmpty) {
              title += ': $parsedTitle';
            }
          } else {
            title = parsedSeries;
          }
        } else if (parsedTitle != null && parsedTitle.isNotEmpty) {
          title = parsedTitle;
        }

        if (parsedWriter != null && parsedWriter.isNotEmpty) {
          author = parsedWriter;
        }
      } catch (e) {
        debugPrint('Error parsing ComicInfo.xml: $e');
      }
    }

    // Extract cover from the first image
    String? coverPath;
    if (imageFiles.isNotEmpty) {
      try {
        final firstImage = imageFiles.first;
        final rawBytes = firstImage.content as List<int>;
        final coversDir = await _getCoversDir();
        final ext = p.extension(firstImage.name).toLowerCase();
        final safeExt = supportedImageExtensions.contains(ext) ? ext : '.jpg';
        final coverFile = File(p.join(coversDir.path, 'cover_comic_${_uuid.v4()}$safeExt'));
        await coverFile.writeAsBytes(rawBytes);
        coverPath = coverFile.path;
      } catch (e) {
        debugPrint('Error extracting comic cover: $e');
      }
    }

    return ComicMetadata(
      title: title,
      author: author,
      totalPages: imageFiles.isNotEmpty ? imageFiles.length : 1,
      coverPath: coverPath,
    );
  }

  /// Parses and unpacks all comic pages for reading.
  static Future<BookParsedData> parseComic(BookItem book) async {
    final file = await BookParserService.resolveBookFile(book.filePath);
    if (file == null) {
      throw FileSystemException('Файл комикса не найден', book.filePath);
    }

    final cacheDir = await getComicCacheDir(book.id);
    final existingFiles = cacheDir
        .listSync()
        .whereType<File>()
        .where((f) => isImageFile(f.path))
        .toList();

    existingFiles.sort((a, b) => naturalCompare(a.path, b.path));

    // If cache already contains the expected pages, return them directly
    if (existingFiles.isNotEmpty &&
        (book.totalChaptersOrPages <= 1 || existingFiles.length == book.totalChaptersOrPages)) {
      final chapters = <BookChapter>[];
      for (int i = 0; i < existingFiles.length; i++) {
        chapters.add(BookChapter(
          index: i,
          title: 'Стр. ${i + 1}',
          content: existingFiles[i].path,
        ));
      }
      return BookParsedData(
        title: book.title,
        author: book.author,
        chapters: chapters,
      );
    }

    // Otherwise, extract from archive
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);

    final imageFiles = <ArchiveFile>[];
    for (final f in archive.files) {
      if (!f.isFile || isIgnoredEntry(f.name)) continue;
      if (isImageFile(f.name)) {
        imageFiles.add(f);
      }
    }

    imageFiles.sort((a, b) => naturalCompare(a.name, b.name));

    if (imageFiles.isEmpty) {
      return BookParsedData(
        title: book.title,
        author: book.author,
        chapters: [
          BookChapter(
            index: 0,
            title: 'Пустой комикс',
            content: 'В архиве не найдено графических страниц.',
          ),
        ],
      );
    }

    final chapters = <BookChapter>[];
    for (int i = 0; i < imageFiles.length; i++) {
      final img = imageFiles[i];
      final rawBytes = img.content as List<int>;
      final ext = p.extension(img.name).toLowerCase();
      final safeExt = supportedImageExtensions.contains(ext) ? ext : '.jpg';
      final pageIndexPad = i.toString().padLeft(4, '0');
      final pageFile = File(p.join(cacheDir.path, 'page_$pageIndexPad$safeExt'));

      await pageFile.writeAsBytes(rawBytes);

      chapters.add(BookChapter(
        index: i,
        title: 'Стр. ${i + 1}',
        content: pageFile.path,
      ));
    }

    return BookParsedData(
      title: book.title,
      author: book.author,
      chapters: chapters,
    );
  }
}
