import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../models/book_item.dart';

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
    } else if (ext == '.fb2') {
      format = BookFormat.fb2;
      final parsed = await parseFb2(permanentPath);
      title = parsed.title.isNotEmpty ? parsed.title : fileName;
      author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
      totalUnits = parsed.chapters.length;
      coverPath = await _extractFb2Cover(permanentPath);
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

  static Future<String?> _extractFb2Cover(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final xml = XmlDocument.parse(content);

      // Find coverpage image reference in title-info
      final coverpage = xml.findAllElements('coverpage').firstOrNull;
      String? imageId;
      if (coverpage != null) {
        final imageElem = coverpage.findAllElements('image').firstOrNull;
        if (imageElem != null) {
          final href = imageElem.getAttribute('l:href') ?? imageElem.getAttribute('xlink:href') ?? imageElem.getAttribute('href');
          if (href != null) {
            imageId = href.startsWith('#') ? href.substring(1) : href;
          }
        }
      }

      // Look in binary tags
      final binaries = xml.findAllElements('binary');
      for (final bin in binaries) {
        final id = bin.getAttribute('id');
        if (imageId != null && id == imageId) {
          final base64Data = bin.innerText.replaceAll(RegExp(r'\s+'), '');
          final imgBytes = base64Decode(base64Data);
          final coversDir = await _getCoversDirectory();
          final targetPath = p.join(coversDir.path, '${p.basenameWithoutExtension(filePath)}_cover.jpg');
          await File(targetPath).writeAsBytes(imgBytes);
          return targetPath;
        }
      }

      // If specific cover not matched, pick first binary
      if (binaries.isNotEmpty) {
        final base64Data = binaries.first.innerText.replaceAll(RegExp(r'\s+'), '');
        final imgBytes = base64Decode(base64Data);
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

  static Future<BookParsedData> parseFb2(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    final xml = XmlDocument.parse(content);

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
        author = '$first $last'.trim();
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
        // Skip p elements that belong to <title>
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
