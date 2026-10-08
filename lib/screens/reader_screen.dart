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

import '../widgets/reader/reader_theme_settings_sheet.dart';

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

  void _showThemeSettings(BuildContext context, ReaderProvider reader) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReaderThemeSettingsSheet(reader: reader),
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
                      // Prominent button for Notes and Quotes
                      Builder(
                        builder: (ctx) => FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: AppTheme.primaryPink.withValues(alpha: 0.25),
                          ),
                          icon: const Icon(Icons.format_quote_rounded, size: 18, color: AppTheme.primaryPinkDark),
                          label: Text(
                            reader.highlights.isNotEmpty ? 'Цитаты (${reader.highlights.length})' : 'Цитаты',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryPinkDark,
                            ),
                          ),
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Theme & Typography Settings
                      if (widget.book.format != BookFormat.pdf)
                        IconButton(
                          icon: const Icon(Icons.tune_rounded),
                          tooltip: 'Оформление текста и темы',
                          onPressed: () => _showThemeSettings(context, reader),
                        ),

                      // Fullscreen toggle
                      IconButton(
                        icon: const Icon(Icons.fullscreen_rounded),
                        tooltip: 'Полноэкранный режим (скрыть панели)',
                        onPressed: () => reader.setMenuVisible(false),
                      ),
                      const SizedBox(width: 4),
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
                          top: 0,
                          right: 0,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, right: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => reader.setMenuVisible(true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: AppTheme.primaryPinkDark.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fullscreen_exit_rounded, size: 18, color: AppTheme.primaryPinkDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Меню',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryPinkDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
