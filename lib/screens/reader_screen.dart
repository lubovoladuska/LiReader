import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import '../models/book_item.dart';
import '../providers/library_provider.dart';
import '../providers/reader_provider.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reader/book_notes_sidebar.dart';
import '../widgets/reader/book_search_sheet.dart';
import '../widgets/reader/chapter_content_view.dart';
import '../widgets/reader/chapter_picker_dialog.dart';
import '../widgets/reader/reader_theme_settings_sheet.dart';
import '../widgets/reader/sleep_timer_dialog.dart';
import '../widgets/reader/tts_mini_player.dart';
import '../widgets/reader/comic_viewer.dart';
import 'wallpaper_customization_screen.dart';
import '../services/ambient_sound_service.dart';
import '../widgets/reader/ambient_sound_sheet.dart';

class ReaderScreen extends StatefulWidget {
  final BookItem book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ComicViewerState> _comicViewerKey = GlobalKey<ComicViewerState>();
  late PageController _pageController;
  Timer? _clockTimer;
  String _currentTimeString = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.book.currentChapterOrPage);
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final newTime = '$hour:$minute';
    if (_currentTimeString != newTime && mounted) {
      setState(() {
        _currentTimeString = newTime;
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    AmbientSoundService.instance.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }


  void _updateSystemUI(bool isMenuVisible) {
    if (isMenuVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }


  void _onPageChanged(int index, ReaderProvider reader) {
    if (reader.currentChapterIndex != index) {
      final wasPlayingOrPaused = TtsService.instance.isPlaying || TtsService.instance.isPaused;
      reader.setChapter(index);
      if (wasPlayingOrPaused) {
        reader.startTts(startParagraph: 0);
      }
    }
    context.read<LibraryProvider>().updateProgress(widget.book.id, index, 0.0);
  }

  void _showThemeSettings(BuildContext context, ReaderProvider reader) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) => ReaderThemeSettingsSheet(reader: reader),
    );
  }

  void _showSearchSheet(BuildContext context, ReaderProvider reader) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookSearchSheet(
        reader: reader,
        onJumpToChapter: (chapterIndex) {
          if (widget.book.format != BookFormat.pdf) {
            _pageController.jumpToPage(chapterIndex);
          }
        },
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, ReaderProvider reader) {
    showDialog(
      context: context,
      builder: (ctx) => SleepTimerDialog(
        reader: reader,
        onTimerFinished: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🌙 Время сна! Прогресс чтения сохранен.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).maybePop();
          }
        },
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
            return Scaffold(
              backgroundColor: reader.themeSettings.activeBackground,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final chapters = reader.parsedData?.chapters ?? [];
          if (reader.hasError || (widget.book.format != BookFormat.pdf && chapters.isEmpty)) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.file_open_rounded, size: 48, color: Colors.deepOrangeAccent),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Файл книги не найден',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Файл «${p.basename(widget.book.filePath)}» был перемещён или находился во временной папке кэша.',
                        style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Указать файл книги на телефоне', style: TextStyle(fontSize: 15)),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['epub', 'fb2', 'txt', 'md', 'pdf', 'cbz', 'cbr'],
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
                            final newPath = result.files.single.path!;
                            if (context.mounted) {
                              final success = await context.read<LibraryProvider>().relinkBook(widget.book.id, newPath);
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Файл книги успешно привязан!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final isComic = widget.book.format == BookFormat.cbz;
          final currentChapterTitle = isComic
              ? (chapters.isNotEmpty && reader.currentChapterIndex < chapters.length
                  ? 'Стр. ${reader.currentChapterIndex + 1} из ${chapters.length}'
                  : 'Комикс')
              : (chapters.isNotEmpty && reader.currentChapterIndex < chapters.length
                  ? chapters[reader.currentChapterIndex].title
                  : 'Чтение');

          _updateSystemUI(reader.isMenuVisible);
          final isDesktop = MediaQuery.of(context).size.width > 700;

          if (!isComic &&
              _pageController.hasClients &&
              _pageController.positions.isNotEmpty &&
              _pageController.page?.round() != reader.currentChapterIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients &&
                  _pageController.positions.isNotEmpty &&
                  _pageController.page?.round() != reader.currentChapterIndex) {
                _pageController.jumpToPage(reader.currentChapterIndex);
              }
            });
          }

          return Scaffold(
            backgroundColor: reader.themeSettings.activeBackground,
            key: _scaffoldKey,
            endDrawer: isComic
                ? null
                : BookNotesSidebar(
                    onSelectChapter: (idx) {
                      if (widget.book.format != BookFormat.pdf) {
                        _pageController.jumpToPage(idx);
                      }
                    },
                  ),
            body: Stack(
              children: [
                // Base content: PDF, Comic (CBZ), or Chapters PageView (stays fullscreen without layout jump)
                if (widget.book.format == BookFormat.pdf)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => reader.toggleMenu(),
                      child: PdfViewer.file(
                        widget.book.filePath,
                        params: PdfViewerParams(
                          onViewerReady: (document, controller) {
                            debugPrint('PDF loaded: ${document.pages.length} pages');
                          },
                        ),
                      ),
                    ),
                  )
                else if (isComic)
                  Positioned.fill(
                    child: ComicViewer(
                      key: _comicViewerKey,
                      book: widget.book,
                      pages: chapters,
                      initialPage: reader.currentChapterIndex,
                      onToggleMenu: () => reader.toggleMenu(),
                      isMenuVisible: reader.isMenuVisible,
                    ),
                  )
                else
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: chapters.length,
                      onPageChanged: (idx) => _onPageChanged(idx, reader),
                      itemBuilder: (ctx, idx) {
                        final chap = chapters[idx];
                        return ChapterContentView(
                          title: chap.title,
                          content: chap.content,
                          chapterIndex: idx,
                          onPreviousChapter: idx > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                          onNextChapter: idx < chapters.length - 1
                              ? () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                        );
                      },
                    ),
                  ),

                // Smooth Animated Top App Bar Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    offset: reader.isMenuVisible ? Offset.zero : const Offset(0, -1.05),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 230),
                      curve: Curves.easeInOut,
                      opacity: reader.isMenuVisible ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !reader.isMenuVisible,
                        child: Material(
                          elevation: 4,
                          color: Theme.of(context).appBarTheme.backgroundColor ??
                              Theme.of(context).colorScheme.surface,
                          child: SafeArea(
                            bottom: false,
                            child: SizedBox(
                              height: kToolbarHeight,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        if (isComic) {
                                          _comicViewerKey.currentState?.showThumbnailsSheet(context);
                                        } else if (widget.book.format != BookFormat.pdf) {
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
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppTheme.primaryPinkDark.withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                currentChapterTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            if (widget.book.format != BookFormat.pdf) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Comic specific buttons OR standard book buttons
                                  if (isComic) ...[
                                    IconButton(
                                      icon: const Icon(Icons.grid_view_rounded),
                                      tooltip: 'Сетка страниц',
                                      onPressed: () => _comicViewerKey.currentState?.showThumbnailsSheet(context),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.tune_rounded),
                                      tooltip: 'Режим чтения и фон',
                                      onPressed: () => _comicViewerKey.currentState?.showComicSettingsDialog(context),
                                    ),
                                  ] else ...[
                                    // Quotes / Highlights button with badge
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.format_quote_rounded),
                                          tooltip: 'Цитаты и заметки (${reader.highlights.length})',
                                          color: reader.highlights.isNotEmpty ? AppTheme.primaryPinkDark : null,
                                          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                                        ),
                                        if (reader.highlights.isNotEmpty)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(
                                                color: AppTheme.primaryPinkDark,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                              child: Text(
                                                '${reader.highlights.length}',
                                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    // Ambient Soundscape button
                                    ValueListenableBuilder<bool>(
                                      valueListenable: AmbientSoundService.instance.isPlayingNotifier,
                                      builder: (context, isPlaying, _) {
                                        return IconButton(
                                          icon: Icon(
                                            isPlaying ? Icons.graphic_eq_rounded : Icons.spatial_audio_off_rounded,
                                            color: isPlaying ? AppTheme.primaryPinkDark : null,
                                          ),
                                          tooltip: isPlaying ? 'Звуки уюта (играет)' : 'Звуки уюта (эмбиент)',
                                          onPressed: () => AmbientSoundSheet.show(context),
                                        );
                                      },
                                    ),
                                    // Theme & Typography Settings
                                    if (widget.book.format != BookFormat.pdf)
                                      IconButton(
                                        icon: const Icon(Icons.tune_rounded),
                                        tooltip: 'Оформление текста и темы',
                                        onPressed: () => _showThemeSettings(context, reader),
                                      ),
                                  ],
                                  // More options menu (Wallpaper, Search, Sleep timer)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded),
                                    tooltip: 'Ещё настройки',
                                    onSelected: (val) {
                                      switch (val) {
                                        case 'toc':
                                          showDialog<int>(
                                            context: context,
                                            builder: (ctx) => ChangeNotifierProvider.value(
                                              value: reader,
                                              child: const ChapterPickerDialog(),
                                            ),
                                          );
                                          break;
                                        case 'wallpaper':
                                          WallpaperCustomizationScreen.show(context, reader);
                                          break;
                                        case 'search':
                                          _showSearchSheet(context, reader);
                                          break;
                                        case 'ambient':
                                          AmbientSoundSheet.show(context);
                                          break;
                                        case 'tts':
                                          reader.startTts();
                                          break;
                                        case 'sleep':
                                          _showSleepTimerDialog(context, reader);
                                          break;
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'ambient',
                                        child: Row(
                                          children: [
                                            Icon(Icons.graphic_eq_rounded, size: 20, color: AppTheme.primaryPinkDark),
                                            SizedBox(width: 12),
                                            Text('Звуки уюта (Эмбиент)'),
                                          ],
                                        ),
                                      ),
                                      if (widget.book.format != BookFormat.pdf && !isComic)
                                        const PopupMenuItem(
                                          value: 'tts',
                                          child: Row(
                                            children: [
                                              Icon(Icons.headphones_rounded, size: 20, color: AppTheme.primaryPinkDark),
                                              SizedBox(width: 12),
                                              Text('Озвучка книги (TTS)'),
                                            ],
                                          ),
                                        ),
                                      if (widget.book.format != BookFormat.pdf && !isComic)
                                        const PopupMenuItem(
                                          value: 'toc',
                                          child: Row(
                                            children: [
                                              Icon(Icons.list_alt_rounded, size: 20, color: AppTheme.primaryPinkDark),
                                              SizedBox(width: 12),
                                              Text('Оглавление / Список глав'),
                                            ],
                                          ),
                                        ),
                                      if (widget.book.format != BookFormat.pdf && !isComic)
                                        const PopupMenuItem(
                                          value: 'search',
                                          child: Row(
                                            children: [
                                              Icon(Icons.search_rounded, size: 20),
                                              SizedBox(width: 12),
                                              Text('Поиск по тексту'),
                                            ],
                                          ),
                                        ),
                                      if (widget.book.format != BookFormat.pdf && !isComic)
                                        const PopupMenuItem(
                                          value: 'wallpaper',
                                          child: Row(
                                            children: [
                                              Icon(Icons.wallpaper_rounded, size: 20),
                                              SizedBox(width: 12),
                                              Text('Фон и обои'),
                                            ],
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: 'sleep',
                                        child: Row(
                                          children: [
                                            Icon(
                                              reader.isSleepTimerActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                                              size: 20,
                                              color: reader.isSleepTimerActive ? AppTheme.primaryPinkDark : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(reader.isSleepTimerActive
                                                ? 'Таймер сна (${reader.sleepTimerRemainingSeconds ~/ 60} мин)'
                                                : 'Таймер сна'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),


                      // Floating Search Navigation Bar
                      if (reader.searchResults.isNotEmpty)
                        Positioned(
                          top: reader.isMenuVisible ? 12 : 8,
                          left: 16,
                          right: 16,
                          child: SafeArea(
                            child: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(context).cardColor,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.primaryPinkDark.withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryPinkDark),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '«${reader.searchQuery}» (${reader.currentSearchIndex + 1} из ${reader.searchResults.length})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Предыдущее совпадение',
                                      onPressed: () {
                                        reader.prevSearchResult();
                                        if (reader.currentSearchResult != null && widget.book.format != BookFormat.pdf) {
                                          _pageController.jumpToPage(reader.currentSearchResult!.chapterIndex);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Следующее совпадение',
                                      onPressed: () {
                                        reader.nextSearchResult();
                                        if (reader.currentSearchResult != null && widget.book.format != BookFormat.pdf) {
                                          _pageController.jumpToPage(reader.currentSearchResult!.chapterIndex);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Закрыть поиск',
                                      onPressed: () => reader.clearSearch(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),



                      // Floating navigation controls for Desktop / Mouse
                      if (isDesktop && reader.isMenuVisible && chapters.length > 1) ...[
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

                      // Interactive Chapter Navigation Bar at Bottom (smooth animated slide & fade)
                      if (widget.book.format != BookFormat.pdf && chapters.length > 1)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 34,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            offset: reader.isMenuVisible ? Offset.zero : const Offset(0, 1.4),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 230),
                              curve: Curves.easeInOut,
                              opacity: reader.isMenuVisible ? 1.0 : 0.0,
                              child: IgnorePointer(
                                ignoring: !reader.isMenuVisible,
                                child: SafeArea(
                                  top: false,
                                  child: Material(
                                    elevation: 10,
                                    borderRadius: BorderRadius.circular(18),
                                    color: Theme.of(context).cardColor.withValues(alpha: 0.96),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: AppTheme.primaryPinkDark.withValues(alpha: 0.25),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              // Previous chapter/page button
                                              IconButton(
                                                icon: const Icon(Icons.skip_previous_rounded, size: 26),
                                                tooltip: isComic ? 'Предыдущая страница' : 'Предыдущая глава',
                                                color: reader.currentChapterIndex > 0
                                                    ? AppTheme.primaryPinkDark
                                                    : Colors.grey.withValues(alpha: 0.35),
                                                onPressed: reader.currentChapterIndex > 0
                                                    ? () {
                                                        if (isComic) {
                                                          _comicViewerKey.currentState?.previousPage();
                                                        } else {
                                                          _pageController.jumpToPage(reader.currentChapterIndex - 1);
                                                        }
                                                      }
                                                    : null,
                                              ),
                                              // Central clickable Chapter/Page indicator
                                              Expanded(
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(10),
                                                  onTap: () async {
                                                    if (isComic) {
                                                      _comicViewerKey.currentState?.showThumbnailsSheet(context);
                                                    } else {
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
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              isComic
                                                                  ? 'Страница ${reader.currentChapterIndex + 1} из ${chapters.length}'
                                                                  : 'Глава ${reader.currentChapterIndex + 1} из ${chapters.length}',
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppTheme.primaryPinkDark,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Icon(
                                                              isComic ? Icons.grid_view_rounded : Icons.format_list_bulleted_rounded,
                                                              size: 14,
                                                              color: AppTheme.primaryPinkDark,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          isComic
                                                              ? (_comicViewerKey.currentState?.readingMode.label ?? 'Комикс')
                                                              : currentChapterTitle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Next chapter/page button
                                              IconButton(
                                                icon: const Icon(Icons.skip_next_rounded, size: 26),
                                                tooltip: isComic ? 'Следующая страница' : 'Следующая глава',
                                                color: reader.currentChapterIndex < chapters.length - 1
                                                    ? AppTheme.primaryPinkDark
                                                    : Colors.grey.withValues(alpha: 0.35),
                                                onPressed: reader.currentChapterIndex < chapters.length - 1
                                                    ? () {
                                                        if (isComic) {
                                                          _comicViewerKey.currentState?.nextPage();
                                                        } else {
                                                          _pageController.jumpToPage(reader.currentChapterIndex + 1);
                                                        }
                                                      }
                                                    : null,
                                              ),
                                            ],
                                          ),
                                          // Smooth Slider
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: AppTheme.primaryPinkDark,
                                              inactiveTrackColor: AppTheme.primaryPinkDark.withValues(alpha: 0.18),
                                              thumbColor: AppTheme.primaryPinkDark,
                                              overlayColor: AppTheme.primaryPinkDark.withValues(alpha: 0.2),
                                              trackHeight: 3.5,
                                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            ),
                                            child: Slider(
                                              value: reader.currentChapterIndex.toDouble().clamp(0.0, (chapters.length - 1).toDouble()),
                                              min: 0.0,
                                              max: (chapters.length - 1).toDouble(),
                                              divisions: chapters.length > 1 ? chapters.length - 1 : 1,
                                              label: isComic
                                                  ? 'Стр. ${reader.currentChapterIndex + 1}'
                                                  : 'Глава ${reader.currentChapterIndex + 1}',
                                              onChanged: (val) {
                                                if (isComic) {
                                                  _comicViewerKey.currentState?.jumpToPage(val.toInt());
                                                } else {
                                                  _pageController.jumpToPage(val.toInt());
                                                }
                                              },
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
                        ),

                      // Floating TTS Mini Player
                      if (widget.book.format != BookFormat.pdf && !isComic)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          left: 0,
                          right: 0,
                          bottom: (chapters.length > 1 && reader.isMenuVisible)
                              ? 142
                              : 28,
                          child: TtsMiniPlayer(
                            totalParagraphs: reader.getChapterParagraphs(reader.currentChapterIndex).length,
                            onClose: () => reader.stopTts(),
                          ),
                        ),

                      // Subtle Reading Status Bar at bottom
                      if (widget.book.format != BookFormat.pdf)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: SafeArea(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Current chapter info & chapter progress %
                                    Text(
                                      isComic
                                          ? 'Стр. ${reader.currentChapterIndex + 1} из ${chapters.length} • ${((reader.currentChapterIndex + 1) / (chapters.isEmpty ? 1 : chapters.length) * 100).toInt()}%'
                                          : (chapters.isNotEmpty
                                              ? 'Гл. ${reader.currentChapterIndex + 1} из ${chapters.length} • ${(reader.chapterScrollProgress * 100).toInt()}%'
                                              : '${(reader.chapterScrollProgress * 100).toInt()}%'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: reader.themeSettings.activeText.withValues(alpha: 0.45),
                                        letterSpacing: 0.2,
                                      ),
                                    ),

                                    // Total book progress & Current local time
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (chapters.isNotEmpty) ...[
                                          Text(
                                            'Книга: ${(((reader.currentChapterIndex + reader.chapterScrollProgress) / chapters.length) * 100).clamp(0, 100).toInt()}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: reader.themeSettings.activeText.withValues(alpha: 0.45),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        if (_currentTimeString.isNotEmpty)
                                          Text(
                                            _currentTimeString,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: reader.themeSettings.activeText.withValues(alpha: 0.45),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );

        },
      ),
    );
  }
}
