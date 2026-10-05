import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import '../models/book_item.dart';
import '../providers/library_provider.dart';
import '../providers/reader_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/reader/book_notes_sidebar.dart';
import '../widgets/reader/chapter_content_view.dart';
import '../widgets/reader/chapter_picker_dialog.dart';

class ReaderScreen extends StatefulWidget {
  final BookItem book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.book.currentChapterOrPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, ReaderProvider reader) {
    reader.setChapter(index);
    context.read<LibraryProvider>().updateProgress(widget.book.id, index, 0.0);
  }

  void _showFontSettings(BuildContext context, ReaderProvider reader) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Настройки текста',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Размер шрифта'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          reader.setFontSize(reader.fontSize - 1);
                          setSheetState(() {});
                        },
                      ),
                      Text('${reader.fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          reader.setFontSize(reader.fontSize + 1);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Межстрочный интервал'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.density_small_rounded),
                        onPressed: () {
                          reader.setLineHeight(1.4);
                          setSheetState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.density_medium_rounded),
                        onPressed: () {
                          reader.setLineHeight(1.6);
                          setSheetState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.density_large_rounded),
                        onPressed: () {
                          reader.setLineHeight(1.9);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReaderProvider(book: widget.book),
      child: Consumer<ReaderProvider>(
        builder: (context, reader, _) {
          if (reader.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final chapters = reader.parsedData?.chapters ?? [];
          final currentChapterTitle = chapters.isNotEmpty && reader.currentChapterIndex < chapters.length
              ? chapters[reader.currentChapterIndex].title
              : 'Чтение';

          return Scaffold(
            endDrawer: BookNotesSidebar(
              onSelectChapter: (idx) {
                if (widget.book.format != BookFormat.pdf) {
                  _pageController.jumpToPage(idx);
                }
              },
            ),
            appBar: reader.isMenuVisible
                ? AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: InkWell(
                      onTap: () async {
                        if (widget.book.format != BookFormat.pdf) {
                          final selected = await showDialog<int>(
                            context: context,
                            builder: (ctx) => ChangeNotifierProvider.value(
                              value: reader,
                              child: const ChapterPickerDialog(),
                            ),
                          );
                          if (selected != null) {
                            _pageController.jumpToPage(selected);
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                currentChapterTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (widget.book.format != BookFormat.pdf) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      if (widget.book.format != BookFormat.pdf)
                        IconButton(
                          icon: const Icon(Icons.text_fields_rounded),
                          tooltip: 'Настройки шрифта',
                          onPressed: () => _showFontSettings(context, reader),
                        ),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.bookmark_border_rounded),
                          tooltip: 'Заметки и цитаты',
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_rounded),
                        tooltip: 'Скрыть панели (полноэкранный режим)',
                        onPressed: () => reader.setMenuVisible(false),
                      ),
                    ],
                  )
                : null,
            body: widget.book.format == BookFormat.pdf
                ? PdfViewer.file(
                    widget.book.filePath,
                    params: PdfViewerParams(
                      onViewerReady: (document, controller) {
                        debugPrint('PDF loaded: ${document.pages.length} pages');
                      },
                    ),
                  )
                : Stack(
                    children: [
                      // Horizontal PageView for Chapters
                      PageView.builder(
                        controller: _pageController,
                        itemCount: chapters.length,
                        onPageChanged: (idx) => _onPageChanged(idx, reader),
                        itemBuilder: (ctx, idx) {
                          final chap = chapters[idx];
                          return ChapterContentView(
                            chapterIndex: idx,
                            title: chap.title,
                            content: chap.content,
                          );
                        },
                      ),

                      // Floating restore button when AppBar is hidden (Immersive mode)
                      if (!reader.isMenuVisible)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'showMenuBtn',
                            elevation: 3,
                            backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.85),
                            tooltip: 'Показать меню',
                            child: const Icon(Icons.fullscreen_exit_rounded, size: 22),
                            onPressed: () => reader.setMenuVisible(true),
                          ),
                        ),

                      // Floating navigation controls for Desktop / Mouse
                      if (reader.isMenuVisible && chapters.length > 1) ...[
                        if (reader.currentChapterIndex > 0)
                          Positioned(
                            left: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: FloatingActionButton.small(
                                heroTag: 'prevChapter',
                                elevation: 2,
                                backgroundColor: Theme.of(context).cardColor,
                                child: const Icon(Icons.chevron_left_rounded, size: 28),
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          ),
                        if (reader.currentChapterIndex < chapters.length - 1)
                          Positioned(
                            right: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: FloatingActionButton.small(
                                heroTag: 'nextChapter',
                                elevation: 2,
                                backgroundColor: Theme.of(context).cardColor,
                                child: const Icon(Icons.chevron_right_rounded, size: 28),
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}
