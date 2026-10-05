import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
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

  static Future<BookItem> createBookItemFromFile(String filePath) async {
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase();
    final fileName = p.basenameWithoutExtension(filePath);

    BookFormat format = BookFormat.unknown;
    String title = fileName;
    String author = 'Неизвестный автор';
    int totalUnits = 1;

    if (ext == '.epub') {
      format = BookFormat.epub;
      final parsed = await parseEpub(filePath);
      title = parsed.title.isNotEmpty ? parsed.title : fileName;
      author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
      totalUnits = parsed.chapters.length;
    } else if (ext == '.fb2') {
      format = BookFormat.fb2;
      final parsed = await parseFb2(filePath);
      title = parsed.title.isNotEmpty ? parsed.title : fileName;
      author = parsed.author.isNotEmpty ? parsed.author : 'Автор не указан';
      totalUnits = parsed.chapters.length;
    } else if (ext == '.txt') {
      format = BookFormat.txt;
      final parsed = await parseTxt(filePath);
      totalUnits = parsed.chapters.length;
    } else if (ext == '.md') {
      format = BookFormat.markdown;
      final parsed = await parseTxt(filePath);
      totalUnits = parsed.chapters.length;
    } else if (ext == '.pdf') {
      format = BookFormat.pdf;
    }

    return BookItem(
      id: _uuid.v4(),
      title: title,
      author: author,
      filePath: filePath,
      format: format,
      totalChaptersOrPages: totalUnits > 0 ? totalUnits : 1,
      currentChapterOrPage: 0,
      scrollProgress: 0.0,
      addedAt: DateTime.now(),
      lastReadAt: DateTime.now(),
    );
  }

  static Future<BookParsedData> parseBook(BookItem book) async {
    switch (book.format) {
      case BookFormat.epub:
        return await parseEpub(book.filePath);
      case BookFormat.fb2:
        return await parseFb2(book.filePath);
      case BookFormat.txt:
      case BookFormat.markdown:
        return await parseTxt(book.filePath);
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
        chapters.add(BookChapter(
          index: chapterIndex,
          title: currentTitle,
          content: buffer.toString(),
        ));
        chapterIndex++;
        currentTitle = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        buffer.clear();
      }
      buffer.writeln(line);
    }

    if (buffer.isNotEmpty || chapters.isEmpty) {
      chapters.add(BookChapter(
        index: chapterIndex,
        title: currentTitle,
        content: buffer.toString(),
      ));
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
            chapters.add(BookChapter(
              index: chapterIndex,
              title: 'Глава ${chapterIndex + 1}',
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
      final paragraphs = sec.findAllElements('p').map((e) => e.innerText.trim()).join('\n\n');
      if (paragraphs.isNotEmpty) {
        chapters.add(BookChapter(
          index: idx,
          title: secTitle,
          content: paragraphs,
        ));
        idx++;
      }
    }

    if (chapters.isEmpty) {
      final body = xml.findAllElements('body').firstOrNull?.innerText ?? '';
      chapters.add(BookChapter(
        index: 0,
        title: 'Начало книги',
        content: body.isNotEmpty ? body : 'Пустой документ FB2',
      ));
    }

    return BookParsedData(
      title: title,
      author: author,
      chapters: chapters,
    );
  }

  static String _extractTextFromHtml(String html) {
    var text = html.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '');
    text = text.replaceAll(RegExp(r'</?(p|div|br|h1|h2|h3|h4|h5|h6)[^>]*>'), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
