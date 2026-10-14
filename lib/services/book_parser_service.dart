import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../models/book_item.dart';
import 'comic_parser_service.dart';

class BookChapter {
  final int index;
  final String title;
  final String content;

  BookChapter({
    required this.index,
    required this.title,
    required this.content,
  });
}

class BookParsedData {
  final String title;
  final String author;
  final List<BookChapter> chapters;

  BookParsedData({
    required this.title,
    required this.author,
    required this.chapters,
  });
}

class BookParserService {
  static const _uuid = Uuid();

  /// Copies a book file to permanent app documents storage so it is never lost by cache cleaners.
  static Future<String> copyToPermanentStorage(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) return sourcePath;

      final appDocsDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(appDocsDir.path, 'LiReader', 'books'));
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }
      final fileName = p.basename(sourcePath);
      final destPath = p.join(booksDir.path, fileName);
      final destFile = File(destPath);
      if (await destFile.exists() && destFile.lengthSync() > 0) {
        return destPath;
      }
      final copied = await sourceFile.copy(destPath);
      return copied.path;
    } catch (e) {
      debugPrint('Error copying book to permanent storage: $e');
      return sourcePath;
    }
  }

  /// Automatically locates a book file if its original path is missing or points to a deleted cache folder.
  static Future<File?> resolveBookFile(String originalPath) async {
    final direct = File(originalPath);
    if (direct.existsSync() && direct.lengthSync() > 0) return direct;

    final fileName = p.basename(originalPath);
    final candidates = <String>[
      '/storage/emulated/0/Download/$fileName',
      '/sdcard/Download/$fileName',
      '/storage/emulated/0/Download/Telegram/$fileName',
      '/sdcard/Download/Telegram/$fileName',
      '/storage/emulated/0/Documents/$fileName',
      '/sdcard/Documents/$fileName',
    ];

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      candidates.add(p.join(appDocs.path, 'LiReader', 'books', fileName));
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        candidates.add(p.join(extDir.path, fileName));
      }
    } catch (_) {}

    for (final path in candidates) {
      try {
        final f = File(path);
        if (f.existsSync() && f.lengthSync() > 0) {
          return f;
        }
      } catch (_) {}
    }

    // Fuzzy check: search in /storage/emulated/0/Download/
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        final files = downloadDir.listSync(followLinks: false);
        final baseWithoutExt = p.basenameWithoutExtension(originalPath).toLowerCase();
        for (final entity in files) {
          if (entity is File) {
            final name = p.basename(entity.path).toLowerCase();
            if (name.contains(baseWithoutExt) || baseWithoutExt.contains(p.basenameWithoutExtension(name))) {
              if (p.extension(entity.path).toLowerCase() == p.extension(originalPath).toLowerCase()) {
                return entity;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<BookItem> createBookItemFromFile(String filePath) async {
    final permanentPath = await copyToPermanentStorage(filePath);
    final ext = p.extension(permanentPath).toLowerCase();
    final lowerPath = permanentPath.toLowerCase();
    final fileName = p.basenameWithoutExtension(permanentPath);

    BookFormat format = BookFormat.unknown;
    String title = fileName;
    String author = 'Неизвестный автор';
    int totalUnits = 1;

    String? coverPath;

    if (ext == '.epub') {
      format = BookFormat.epub;
      final parsed = await parseEpub(permanentPath);
      title = parsed.title.isNotEmpty ? parsed.title : fileName;
      author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
      totalUnits = parsed.chapters.length;
      coverPath = await _extractEpubCover(permanentPath);
    } else if (ext == '.fb2' || lowerPath.endsWith('.fb2.zip')) {
      format = BookFormat.fb2;
      final parsed = await parseFb2(permanentPath);
      title = parsed.title.isNotEmpty ? parsed.title : fileName;
      author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
      totalUnits = parsed.chapters.length;
      coverPath = await _extractFb2Cover(permanentPath);
    } else if (ext == '.cbz' || ext == '.cbr') {
      format = BookFormat.cbz;
      final meta = await ComicParserService.inspectComic(permanentPath);
      title = meta.title.isNotEmpty ? meta.title : fileName;
      author = meta.author.isNotEmpty ? meta.author : 'Комикс / Манга';
      totalUnits = meta.totalPages;
      coverPath = meta.coverPath;
    } else if (ext == '.zip') {
      try {
        final bytes = await File(permanentPath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final hasFb2 = archive.files.any((f) => f.name.toLowerCase().endsWith('.fb2'));
        final hasEpub = archive.files.any((f) => f.name.toLowerCase().endsWith('.opf') || f.name.toLowerCase().endsWith('.ncx'));
        final hasImages = archive.files.any((f) => ComicParserService.isImageFile(f.name));
        if (hasFb2) {
          format = BookFormat.fb2;
          final parsed = await parseFb2(permanentPath);
          title = parsed.title.isNotEmpty ? parsed.title : fileName;
          author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
          totalUnits = parsed.chapters.length;
          coverPath = await _extractFb2Cover(permanentPath);
        } else if (hasEpub) {
          format = BookFormat.epub;
          final parsed = await parseEpub(permanentPath);
          title = parsed.title.isNotEmpty ? parsed.title : fileName;
          author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
          totalUnits = parsed.chapters.length;
          coverPath = await _extractEpubCover(permanentPath);
        } else if (hasImages) {
          format = BookFormat.cbz;
          final meta = await ComicParserService.inspectComic(permanentPath);
          title = meta.title.isNotEmpty ? meta.title : fileName;
          author = meta.author.isNotEmpty ? meta.author : 'Комикс / Манга';
          totalUnits = meta.totalPages;
          coverPath = meta.coverPath;
        }
      } catch (e) {
        debugPrint('Error inspecting ZIP container: $e');
      }
    } else if (ext == '.txt') {
      format = BookFormat.txt;
      final parsed = await parseTxt(permanentPath);
      totalUnits = parsed.chapters.length;
    } else if (ext == '.md') {
      format = BookFormat.markdown;
      final parsed = await parseTxt(permanentPath);
      totalUnits = parsed.chapters.length;
    } else if (ext == '.pdf') {
      format = BookFormat.pdf;
    }

    return BookItem(
      id: _uuid.v4(),
      title: title,
      author: author,
      filePath: permanentPath,
      format: format,
      totalChaptersOrPages: totalUnits > 0 ? totalUnits : 1,
      currentChapterOrPage: 0,
      scrollProgress: 0.0,
      addedAt: DateTime.now(),
      lastReadAt: DateTime.now(),
      coverPath: coverPath,
    );
  }

  static Future<Directory> _getCoversDirectory() async {
    String baseDirPath;
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      baseDirPath = appDocsDir.path;
    } catch (_) {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['APPDATA'] ?? '.';
      baseDirPath = p.join(userProfile, 'Documents');
    }
    final coversDirPath = p.join(baseDirPath, 'LiReader', 'covers');
    final dir = Directory(coversDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String?> _extractEpubCover(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. First locate OPF file via META-INF/container.xml
      final containerFile = archive.findFile('META-INF/container.xml');
      String? opfPath;
      if (containerFile != null) {
        try {
          final cXml = XmlDocument.parse(utf8.decode(containerFile.content as List<int>, allowMalformed: true));
          final rootfile = cXml.findAllElements('rootfile').firstOrNull;
          opfPath = rootfile?.getAttribute('full-path');
        } catch (_) {}
      }
      opfPath ??= 'content.opf';
      final opfFile = archive.findFile(opfPath) ?? archive.files.firstWhere(
        (f) => f.name.endsWith('.opf'),
        orElse: () => archive.files.first,
      );

      String opfDir = p.dirname(opfFile.name);
      if (opfDir == '.') opfDir = '';

      ArchiveFile? coverArchiveFile;

      if (opfFile.name.endsWith('.opf')) {
        try {
          final opfXml = XmlDocument.parse(utf8.decode(opfFile.content as List<int>, allowMalformed: true));
          
          // Look for <meta name="cover" content="item_id"/>
          String? coverItemId;
          for (final meta in opfXml.findAllElements('meta')) {
            if (meta.getAttribute('name')?.toLowerCase() == 'cover') {
              coverItemId = meta.getAttribute('content');
              break;
            }
          }

          // Map manifest items
          final manifestItems = <String, String>{};
          for (final item in opfXml.findAllElements('item')) {
            final id = item.getAttribute('id');
            final href = item.getAttribute('href');
            if (id != null && href != null) {
              manifestItems[id] = href;
              // Check if properties="cover-image" (EPUB 3 standard)
              final properties = item.getAttribute('properties');
              if (properties != null && properties.contains('cover-image')) {
                coverItemId = id;
              }
            }
          }

          if (coverItemId != null && manifestItems.containsKey(coverItemId)) {
            final href = Uri.decodeFull(manifestItems[coverItemId]!);
            final fullCoverPath = opfDir.isEmpty ? href : p.join(opfDir, href).replaceAll(r'\', '/');
            coverArchiveFile = archive.findFile(fullCoverPath);
          }
        } catch (_) {}
      }

      // 2. Fallback heuristic: search for file containing cover/titlepage in filename
      if (coverArchiveFile == null) {
        for (final f in archive.files) {
          final n = f.name.toLowerCase();
          if ((n.contains('cover') || n.contains('titlepage')) &&
              (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png'))) {
            coverArchiveFile = f;
            break;
          }
        }
      }

      // 3. Last fallback: any image file
      if (coverArchiveFile == null) {
        for (final f in archive.files) {
          final n = f.name.toLowerCase();
          if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png')) {
            coverArchiveFile = f;
            break;
          }
        }
      }

      if (coverArchiveFile != null) {
        final coversDir = await _getCoversDirectory();
        final ext = p.extension(coverArchiveFile.name).isNotEmpty ? p.extension(coverArchiveFile.name) : '.jpg';
        final targetPath = p.join(coversDir.path, '${p.basenameWithoutExtension(filePath)}_cover$ext');
        await File(targetPath).writeAsBytes(coverArchiveFile.content as List<int>);
        return targetPath;
      }
    } catch (e) {
      debugPrint('Error extracting EPUB cover: $e');
    }
    return null;
  }

  static Future<List<int>> _loadFb2Bytes(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      // It's a ZIP archive (.fb2.zip or .zip)
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        ArchiveFile? fb2File;
        for (final f in archive.files) {
          if (f.name.toLowerCase().endsWith('.fb2')) {
            fb2File = f;
            break;
          }
        }
        if (fb2File == null) {
          for (final f in archive.files) {
            if (f.isFile && (fb2File == null || f.size > fb2File.size)) {
              fb2File = f;
            }
          }
        }
        if (fb2File != null && fb2File.content != null) {
          return fb2File.content as List<int>;
        }
      } catch (e) {
        debugPrint('Error unpacking ZIP for FB2: $e');
      }
    }
    return bytes;
  }

  static String _decodeCp1251(List<int> bytes) {
    const cp1251Table = <int, int>{
      0x80: 0x0402, 0x81: 0x0403, 0x82: 0x201A, 0x83: 0x0453,
      0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021,
      0x88: 0x20AC, 0x89: 0x2030, 0x8A: 0x0409, 0x8B: 0x2039,
      0x8C: 0x040A, 0x8D: 0x040C, 0x8E: 0x040B, 0x8F: 0x040F,
      0x90: 0x0452, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
      0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
      0x99: 0x2122, 0x9A: 0x0459, 0x9B: 0x203A, 0x9C: 0x045A,
      0x9D: 0x045C, 0x9E: 0x045B, 0x9F: 0x045F, 0xA0: 0x00A0,
      0xA1: 0x040E, 0xA2: 0x045E, 0xA3: 0x0408, 0xA4: 0x00A4,
      0xA5: 0x0490, 0xA6: 0x00A6, 0xA7: 0x00A7, 0xA8: 0x0401,
      0xA9: 0x00A9, 0xAA: 0x0404, 0xAB: 0x00AB, 0xAC: 0x00AC,
      0xAD: 0x00AD, 0xAE: 0x00AE, 0xAF: 0x0407, 0xB0: 0x00B0,
      0xB1: 0x00B1, 0xB2: 0x0406, 0xB3: 0x0456, 0xB4: 0x0491,
      0xB5: 0x00B5, 0xB6: 0x00B6, 0xB7: 0x00B7, 0xB8: 0x0451,
      0xB9: 0x2116, 0xBA: 0x0454, 0xBB: 0x00BB, 0xBC: 0x0458,
      0xBD: 0x0405, 0xBE: 0x0455, 0xBF: 0x0457,
    };

    final charCodes = <int>[];
    for (final b in bytes) {
      if (b < 0x80) {
        charCodes.add(b);
      } else if (b >= 0xC0 && b <= 0xFF) {
        charCodes.add(0x0410 + (b - 0xC0));
      } else {
        charCodes.add(cp1251Table[b] ?? b);
      }
    }
    return String.fromCharCodes(charCodes);
  }

  static String _decodeFb2Bytes(List<int> bytes) {
    final prefixLen = bytes.length < 1024 ? bytes.length : 1024;
    final prefix = ascii.decode(bytes.sublist(0, prefixLen), allowInvalid: true).toLowerCase();

    final isCp1251 = prefix.contains('windows-1251') || prefix.contains('cp1251');
    if (isCp1251) {
      return _decodeCp1251(bytes);
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return _decodeCp1251(bytes);
    }
  }

  static Future<String?> _extractFb2Cover(String filePath) async {
    try {
      final bytes = await _loadFb2Bytes(filePath);
      final rawContent = _decodeFb2Bytes(bytes);

      String? imageId;
      final coverMatch = RegExp(r'<coverpage[^>]*>[\s\S]*?<image[^>]+href=["'']#?([^"'']+)["'']', caseSensitive: false).firstMatch(rawContent);
      if (coverMatch != null) {
        imageId = coverMatch.group(1);
      }

      String? base64Data;
      if (imageId != null) {
        final binMatch = RegExp('<binary[^>]+id=["\'](?:#)?${RegExp.escape(imageId)}["\'][^>]*>([\\s\\S]*?)</binary>', caseSensitive: false).firstMatch(rawContent);
        if (binMatch != null) {
          base64Data = binMatch.group(1);
        }
      }

      if (base64Data == null) {
        final firstBinMatch = RegExp(r'<binary[^>]*>([\s\S]*?)</binary>', caseSensitive: false).firstMatch(rawContent);
        if (firstBinMatch != null) {
          base64Data = firstBinMatch.group(1);
        }
      }

      if (base64Data != null) {
        final cleanBase64 = base64Data.replaceAll(RegExp(r'\s+'), '');
        final imgBytes = base64Decode(cleanBase64);
        final coversDir = await _getCoversDirectory();
        final targetPath = p.join(coversDir.path, '${p.basenameWithoutExtension(filePath)}_cover.jpg');
        await File(targetPath).writeAsBytes(imgBytes);
        return targetPath;
      }
    } catch (e) {
      debugPrint('Error extracting FB2 cover: $e');
    }
    return null;
  }

  static Future<String?> extractCoverForBook(BookItem book) async {
    final file = await resolveBookFile(book.filePath);
    if (file == null) return null;
    final path = file.path;

    if (book.format == BookFormat.epub) {
      return await _extractEpubCover(path);
    } else if (book.format == BookFormat.fb2) {
      return await _extractFb2Cover(path);
    } else if (book.format == BookFormat.cbz) {
      final meta = await ComicParserService.inspectComic(path);
      return meta.coverPath;
    }
    return null;
  }

  static Future<BookParsedData> parseBook(BookItem book) async {
    final file = await resolveBookFile(book.filePath);
    if (file == null) {
      throw FileSystemException('Файл книги не найден на устройстве', book.filePath);
    }
    final path = file.path;

    switch (book.format) {
      case BookFormat.epub:
        return await parseEpub(path);
      case BookFormat.fb2:
        return await parseFb2(path);
      case BookFormat.cbz:
        return await ComicParserService.parseComic(book);
      case BookFormat.txt:
      case BookFormat.markdown:
        return await parseTxt(path);
      default:
        return BookParsedData(
          title: book.title,
          author: book.author,
          chapters: [
            BookChapter(index: 0, title: 'Документ', content: 'Формат просматривается встроенным просмотрщиком.'),
          ],
        );
    }
  }

  static Future<BookParsedData> parseTxt(String filePath) async {
    final file = File(filePath);
    final rawText = await file.readAsString();
    final fileName = p.basenameWithoutExtension(filePath);

    final chapters = <BookChapter>[];
    // Split text into readable chunks if very large (e.g. ~4000 words or by chapter headers)
    final lines = const LineSplitter().convert(rawText);
    final buffer = StringBuffer();
    int chapterIndex = 0;
    String currentTitle = 'Глава 1';

    for (final line in lines) {
      final trimmed = line.trim();
      final isHeading = trimmed.startsWith('# ') ||
          trimmed.startsWith('## ') ||
          RegExp(r'^(Глава|Часть|Chapter|Part)\s+\d+', caseSensitive: false).hasMatch(trimmed);

      if (isHeading && buffer.isNotEmpty) {
        final content = sanitizeReadingText(buffer.toString());
        if (content.isNotEmpty) {
          chapters.add(BookChapter(
            index: chapterIndex,
            title: currentTitle,
            content: content,
          ));
          chapterIndex++;
        }
        currentTitle = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        buffer.clear();
      }
      buffer.writeln(line);
    }

    if (buffer.isNotEmpty || chapters.isEmpty) {
      final content = sanitizeReadingText(buffer.toString());
      if (content.isNotEmpty || chapters.isEmpty) {
        chapters.add(BookChapter(
          index: chapterIndex,
          title: currentTitle,
          content: content.isNotEmpty ? content : 'Пустой документ',
        ));
      }
    }

    return BookParsedData(
      title: fileName,
      author: 'Текстовый документ',
      chapters: chapters,
    );
  }

  static Future<BookParsedData> parseEpub(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String title = p.basenameWithoutExtension(filePath);
    String author = 'Неизвестный автор';
    final chapters = <BookChapter>[];

    // Find container.xml to locate OPF
    final containerFile = archive.findFile('META-INF/container.xml');
    String? opfPath;
    if (containerFile != null) {
      final xmlDoc = XmlDocument.parse(utf8.decode(containerFile.content as List<int>));
      final rootfile = xmlDoc.findAllElements('rootfile').firstOrNull;
      opfPath = rootfile?.getAttribute('full-path');
    }

    opfPath ??= 'content.opf';
    final opfFile = archive.findFile(opfPath) ?? archive.files.firstWhere(
      (f) => f.name.endsWith('.opf'),
      orElse: () => archive.files.first,
    );

    String opfDir = p.dirname(opfFile.name);
    if (opfDir == '.') opfDir = '';

    final opfXml = XmlDocument.parse(utf8.decode(opfFile.content as List<int>));
    final titleElem = opfXml.findAllElements('dc:title').firstOrNull;
    if (titleElem != null) title = titleElem.innerText.trim();

    final creatorElem = opfXml.findAllElements('dc:creator').firstOrNull;
    if (creatorElem != null) author = creatorElem.innerText.trim();

    // Map manifest items
    final manifestItems = <String, String>{};
    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifestItems[id] = href;
      }
    }

    // Extract NCX table of contents if available
    final tocTitles = <String, String>{};
    final ncxItem = manifestItems.entries.firstWhere(
      (e) => e.value.endsWith('.ncx'),
      orElse: () => const MapEntry('', ''),
    );
    if (ncxItem.value.isNotEmpty) {
      final ncxPath = opfDir.isEmpty ? ncxItem.value : p.join(opfDir, ncxItem.value).replaceAll(r'\', '/');
      final ncxFile = archive.findFile(ncxPath);
      if (ncxFile != null) {
        try {
          final ncxXml = XmlDocument.parse(utf8.decode(ncxFile.content as List<int>, allowMalformed: true));
          for (final navPoint in ncxXml.findAllElements('navPoint')) {
            final label = navPoint.findAllElements('text').firstOrNull?.innerText.trim();
            final src = navPoint.findAllElements('content').firstOrNull?.getAttribute('src');
            if (label != null && src != null && label.isNotEmpty) {
              final pureSrc = src.split('#').first;
              tocTitles[pureSrc] = label;
            }
          }
        } catch (_) {}
      }
    }

    // Spine reading order
    int chapterIndex = 0;
    for (final itemref in opfXml.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null && manifestItems.containsKey(idref)) {
        final href = manifestItems[idref]!;
        final fullPath = opfDir.isEmpty ? href : p.join(opfDir, href).replaceAll(r'\', '/');
        final contentFile = archive.findFile(fullPath);
        if (contentFile != null) {
          final htmlContent = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
          final cleanText = _extractTextFromHtml(htmlContent);
          
          if (cleanText.trim().isNotEmpty) {
            String detectedTitle = '';
            if (tocTitles.containsKey(href)) {
              detectedTitle = tocTitles[href]!;
            } else {
              // Try to find first heading in HTML or fallback to first line
              final hMatch = RegExp(r'<h[1-3][^>]*>(.*?)</h[1-3]>', caseSensitive: false).firstMatch(htmlContent);
              if (hMatch != null) {
                detectedTitle = _extractTextFromHtml(hMatch.group(1) ?? '');
              }
              if (detectedTitle.trim().isEmpty) {
                final firstLine = cleanText.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
                if (firstLine.length < 60 && !firstLine.contains('.')) {
                  detectedTitle = firstLine.trim();
                }
              }
            }

            final finalTitle = detectedTitle.isNotEmpty ? detectedTitle : 'Раздел ${chapterIndex + 1}';

            chapters.add(BookChapter(
              index: chapterIndex,
              title: finalTitle,
              content: cleanText,
            ));
            chapterIndex++;
          }
        }
      }
    }

    if (chapters.isEmpty) {
      chapters.add(BookChapter(
        index: 0,
        title: 'Начало книги',
        content: 'Не удалось извлечь главы из данного EPUB файла.',
      ));
    }

    return BookParsedData(
      title: title,
      author: author,
      chapters: chapters,
    );
  }

  static String _cleanFb2Xml(String rawXml) {
    var text = rawXml;
    text = text.replaceAll('&nbsp;', '&#160;');
    text = text.replaceAll('&mdash;', '&#8212;');
    text = text.replaceAll('&ndash;', '&#8211;');
    text = text.replaceAll('&laquo;', '&#171;');
    text = text.replaceAll('&raquo;', '&#187;');
    text = text.replaceAll('&hellip;', '&#8230;');
    text = text.replaceAll('&ensp;', '&#8194;');
    text = text.replaceAll('&emsp;', '&#8195;');
    text = text.replaceAll('&thinsp;', '&#8201;');
    text = text.replaceAll('&copy;', '&#169;');
    text = text.replaceAll('&reg;', '&#174;');
    text = text.replaceAll('&deg;', '&#176;');
    text = text.replaceAll('&plusmn;', '&#177;');

    // Fix unescaped ampersands that aren't valid XML entities
    text = text.replaceAll(RegExp(r'&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);)'), '&amp;');
    return text;
  }

  static String _stripBinaryTags(String xml) {
    return xml.replaceAll(RegExp(r'<binary[^>]*>[\s\S]*?</binary>', caseSensitive: false), '');
  }

  static BookParsedData _parseFb2RegexFallback(String rawXml, String fallbackTitle) {
    String title = fallbackTitle;
    String author = 'Неизвестный автор';

    final titleMatch = RegExp(r'<book-title>([\s\S]*?)</book-title>', caseSensitive: false).firstMatch(rawXml);
    if (titleMatch != null) {
      final t = sanitizeReadingText(titleMatch.group(1)!);
      if (t.isNotEmpty) title = t;
    }

    final authorMatch = RegExp(r'<author>([\s\S]*?)</author>', caseSensitive: false).firstMatch(rawXml);
    if (authorMatch != null) {
      final aBlock = authorMatch.group(1)!;
      final fn = RegExp(r'<first-name>([\s\S]*?)</first-name>', caseSensitive: false).firstMatch(aBlock)?.group(1) ?? '';
      final ln = RegExp(r'<last-name>([\s\S]*?)</last-name>', caseSensitive: false).firstMatch(aBlock)?.group(1) ?? '';
      final full = '${sanitizeReadingText(fn)} ${sanitizeReadingText(ln)}'.trim();
      if (full.isNotEmpty) author = full;
    }

    final bodyMatch = RegExp(r'<body[^>]*>([\s\S]*?)</body>', caseSensitive: false).firstMatch(rawXml);
    final bodyText = bodyMatch != null ? bodyMatch.group(1)! : rawXml;

    final chapters = <BookChapter>[];
    final sectionMatches = RegExp(r'<section[^>]*>([\s\S]*?)</section>', caseSensitive: false).allMatches(bodyText);

    int idx = 0;
    for (final secMatch in sectionMatches) {
      final secContent = secMatch.group(1)!;
      final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(secContent);
      String secTitle = 'Глава ${idx + 1}';
      if (titleMatch != null) {
        final t = sanitizeReadingText(titleMatch.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ' '));
        if (t.isNotEmpty) secTitle = t;
      }

      final pMatches = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false).allMatches(secContent);
      final paragraphs = <String>[];
      for (final pm in pMatches) {
        final pClean = sanitizeReadingText(pm.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ' '));
        if (pClean.isNotEmpty) paragraphs.add(pClean);
      }

      final chapterText = paragraphs.join('\n\n');
      if (chapterText.isNotEmpty) {
        chapters.add(BookChapter(index: idx, title: secTitle, content: chapterText));
        idx++;
      }
    }

    if (chapters.isEmpty) {
      final pMatches = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false).allMatches(bodyText);
      final allPs = <String>[];
      for (final pm in pMatches) {
        final pClean = sanitizeReadingText(pm.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ' '));
        if (pClean.isNotEmpty) allPs.add(pClean);
      }
      final fullText = allPs.join('\n\n');
      chapters.add(BookChapter(
        index: 0,
        title: 'Начало книги',
        content: fullText.isNotEmpty ? fullText : 'Пустой документ FB2',
      ));
    }

    return BookParsedData(title: title, author: author, chapters: chapters);
  }

  static Future<BookParsedData> parseFb2(String filePath) async {
    final bytes = await _loadFb2Bytes(filePath);
    final rawContent = _decodeFb2Bytes(bytes);
    final cleanContent = _cleanFb2Xml(rawContent);
    final strippedContent = _stripBinaryTags(cleanContent);

    try {
      final xml = XmlDocument.parse(strippedContent);

      String title = p.basenameWithoutExtension(filePath);
      String author = 'Неизвестный автор';

      final titleInfo = xml.findAllElements('title-info').firstOrNull;
      if (titleInfo != null) {
        final bookTitle = titleInfo.findAllElements('book-title').firstOrNull;
        if (bookTitle != null) title = bookTitle.innerText.trim();

        final authorElem = titleInfo.findAllElements('author').firstOrNull;
        if (authorElem != null) {
          final first = authorElem.findAllElements('first-name').firstOrNull?.innerText ?? '';
          final last = authorElem.findAllElements('last-name').firstOrNull?.innerText ?? '';
          final full = '$first $last'.trim();
          if (full.isNotEmpty) author = full;
        }
      }

      final chapters = <BookChapter>[];
      final sections = xml.findAllElements('section');
      int idx = 0;

      for (final sec in sections) {
        final secTitle = sec.findAllElements('title').firstOrNull?.innerText.trim() ?? 'Глава ${idx + 1}';
        final titleElem = sec.findElements('title').firstOrNull;

        final paragraphs = <String>[];
        for (final pElem in sec.findAllElements('p')) {
          if (titleElem != null && titleElem.descendants.contains(pElem)) continue;
          final pText = sanitizeReadingText(pElem.innerText);
          if (pText.isNotEmpty) {
            paragraphs.add(pText);
          }
        }

        final content = sanitizeReadingText(paragraphs.join('\n\n'));
        if (content.isNotEmpty) {
          chapters.add(BookChapter(
            index: idx,
            title: secTitle,
            content: content,
          ));
          idx++;
        }
      }

      if (chapters.isEmpty) {
        final body = xml.findAllElements('body').firstOrNull?.innerText ?? '';
        final content = sanitizeReadingText(body);
        chapters.add(BookChapter(
          index: 0,
          title: 'Начало книги',
          content: content.isNotEmpty ? content : 'Пустой документ FB2',
        ));
      }

      return BookParsedData(
        title: title,
        author: author,
        chapters: chapters,
      );
    } catch (e) {
      debugPrint('XmlDocument.parse failed for FB2: $e. Falling back to regex parser.');
      return _parseFb2RegexFallback(cleanContent, p.basenameWithoutExtension(filePath));
    }
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&#xA0;', ' ')
        .replaceAll('&#xa0;', ' ')
        .replaceAll('&ensp;', ' ')
        .replaceAll('&emsp;', ' ')
        .replaceAll('&thinsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&#8230;', '…');
  }

  /// Sanitizes text by stripping whitespace-only lines and collapsing any excessive
  /// newlines into at most a single empty line between paragraphs (\n\n).
  static String sanitizeReadingText(String text) {
    if (text.isEmpty) return '';

    // 1. Normalize line endings
    var s = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Decode HTML entities
    s = _decodeHtmlEntities(s);

    // 3. Process line-by-line: trim every line to eliminate hidden whitespace/indentation
    final lines = s.split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      cleanedLines.add(line.trim());
    }
    s = cleanedLines.join('\n');

    // 4. Collapse any run of 3 or more newlines into exactly 2 newlines (\n\n)
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 5. Collapse duplicate spaces within lines
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return s.trim();
  }

  static String _extractTextFromHtml(String html) {
    if (html.isEmpty) return '';

    // 1. Strip styles, scripts, head, and comments
    var text = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    // 2. Line break tags -> single newline
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // 3. Block boundaries: closing tags -> \n\n, opening tags -> \n
    const blockTags = 'p|div|h1|h2|h3|h4|h5|h6|li|blockquote|section|article|header|footer|aside|table|tr';
    text = text.replaceAll(RegExp('</($blockTags)>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp('<($blockTags)[^>]*>', caseSensitive: false), '\n');

    // 4. Strip all remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // 5. Sanitize and collapse all excessive gaps
    return sanitizeReadingText(text);
  }
}
