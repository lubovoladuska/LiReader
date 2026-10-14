import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/reader_provider.dart';
import '../../services/book_parser_service.dart';
import '../../services/database_helper.dart';
import '../../theme/app_theme.dart';

enum ComicReadingMode {
  leftToRight('Комиксы (L-R)', Icons.arrow_forward_rounded),
  rightToLeft('Манга (R-L)', Icons.arrow_back_rounded),
  webtoon('Вебтун (Лента)', Icons.swap_vert_rounded);

  final String label;
  final IconData icon;
  const ComicReadingMode(this.label, this.icon);
}

class ComicViewer extends StatefulWidget {
  final BookItem book;
  final List<BookChapter> pages;
  final int initialPage;
  final VoidCallback onToggleMenu;
  final bool isMenuVisible;

  const ComicViewer({
    super.key,
    required this.book,
    required this.pages,
    required this.initialPage,
    required this.onToggleMenu,
    required this.isMenuVisible,
  });

  @override
  State<ComicViewer> createState() => ComicViewerState();
}

class ComicViewerState extends State<ComicViewer> {
  late PageController _pageController;
  late ScrollController _verticalScrollController;
  ComicReadingMode _readingMode = ComicReadingMode.leftToRight;
  int _currentPageIndex = 0;
  Color _backgroundColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPage.clamp(0, widget.pages.isEmpty ? 0 : widget.pages.length - 1);
    _pageController = PageController(initialPage: _currentPageIndex);
    _verticalScrollController = ScrollController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final modeStr = await DatabaseHelper.instance.getSetting('comic_reading_mode_${widget.book.id}') ??
        await DatabaseHelper.instance.getSetting('comic_reading_mode');
    if (modeStr != null && mounted) {
      final savedMode = ComicReadingMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => ComicReadingMode.leftToRight,
      );
      setState(() {
        _readingMode = savedMode;
      });
    }

    final bgStr = await DatabaseHelper.instance.getSetting('comic_bg_color');
    if (bgStr != null && mounted) {
      final val = int.tryParse(bgStr);
      if (val != null) {
        setState(() {
          _backgroundColor = Color(val);
        });
      }
    }
  }

  Future<void> setReadingMode(ComicReadingMode mode) async {
    setState(() {
      _readingMode = mode;
    });
    await DatabaseHelper.instance.saveSetting('comic_reading_mode_${widget.book.id}', mode.name);
    await DatabaseHelper.instance.saveSetting('comic_reading_mode', mode.name);

    // Jump to current page in the newly selected mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_readingMode != ComicReadingMode.webtoon && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPageIndex);
      }
    });
  }

  Future<void> setBackgroundColor(Color color) async {
    setState(() {
      _backgroundColor = color;
    });
    await DatabaseHelper.instance.saveSetting('comic_bg_color', color.toARGB32().toString());
  }

  ComicReadingMode get readingMode => _readingMode;
  int get currentPageIndex => _currentPageIndex;
  int get totalPages => widget.pages.length;

  void jumpToPage(int index) {
    if (index < 0 || index >= widget.pages.length) return;
    setState(() {
      _currentPageIndex = index;
    });
    if (_readingMode == ComicReadingMode.webtoon) {
      // In webtoon mode, jump or scroll
      // Scroll position approximation
      if (_verticalScrollController.hasClients) {
        final maxScroll = _verticalScrollController.position.maxScrollExtent;
        final target = (maxScroll / (widget.pages.length - 1)) * index;
        _verticalScrollController.jumpTo(target.clamp(0.0, maxScroll));
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    }
    _syncProgress(index);
  }

  void previousPage() {
    if (_currentPageIndex > 0) {
      jumpToPage(_currentPageIndex - 1);
    }
  }

  void nextPage() {
    if (_currentPageIndex < widget.pages.length - 1) {
      jumpToPage(_currentPageIndex + 1);
    }
  }

  void _syncProgress(int pageIndex) {
    if (pageIndex == _currentPageIndex) return;
    setState(() {
      _currentPageIndex = pageIndex;
    });
    final reader = context.read<ReaderProvider>();
    reader.setChapter(pageIndex);
    context.read<LibraryProvider>().updateProgress(widget.book.id, pageIndex, 0.0);
  }

  void showThumbnailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComicThumbnailsSheet(
        pages: widget.pages,
        currentPage: _currentPageIndex,
        onSelectPage: (idx) {
          jumpToPage(idx);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void showComicSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComicSettingsSheet(
        currentMode: _readingMode,
        currentColor: _backgroundColor,
        onModeChanged: (mode) {
          setReadingMode(mode);
          Navigator.pop(ctx);
        },
        onColorChanged: (color) {
          setBackgroundColor(color);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Container(
        color: _backgroundColor,
        child: const Center(
          child: Text(
            'В комиксе нет доступных страниц',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      color: _backgroundColor,
      child: _readingMode == ComicReadingMode.webtoon
          ? _buildWebtoonView()
          : _buildPagedView(),
    );
  }

  Widget _buildPagedView() {
    final isRTL = _readingMode == ComicReadingMode.rightToLeft;

    return PageView.builder(
      controller: _pageController,
      reverse: isRTL,
      itemCount: widget.pages.length,
      onPageChanged: (idx) {
        _syncProgress(idx);
      },
      itemBuilder: (ctx, idx) {
        final page = widget.pages[idx];
        return _InteractiveComicPage(
          imagePath: page.content,
          pageNumber: idx + 1,
          totalPages: widget.pages.length,
          isRTL: isRTL,
          onTapCenter: widget.onToggleMenu,
          onTapLeft: () {
            if (isRTL) {
              nextPage();
            } else {
              previousPage();
            }
          },
          onTapRight: () {
            if (isRTL) {
              previousPage();
            } else {
              nextPage();
            }
          },
        );
      },
    );
  }

  Widget _buildWebtoonView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final maxScroll = _verticalScrollController.position.maxScrollExtent;
          if (maxScroll > 0) {
            final fraction = (_verticalScrollController.offset / maxScroll).clamp(0.0, 1.0);
            final page = (fraction * (widget.pages.length - 1)).round();
            if (page != _currentPageIndex) {
              _syncProgress(page);
            }
          }
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onToggleMenu,
        child: ListView.builder(
          controller: _verticalScrollController,
          itemCount: widget.pages.length,
          padding: EdgeInsets.zero,
          cacheExtent: 1200,
          itemBuilder: (ctx, idx) {
            final page = widget.pages[idx];
            return Image.file(
              File(page.content),
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 250,
                color: Colors.black26,
                child: Center(
                  child: Text(
                    'Не удалось загрузить страницу ${idx + 1}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InteractiveComicPage extends StatefulWidget {
  final String imagePath;
  final int pageNumber;
  final int totalPages;
  final bool isRTL;
  final VoidCallback onTapCenter;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;

  const _InteractiveComicPage({
    required this.imagePath,
    required this.pageNumber,
    required this.totalPages,
    required this.isRTL,
    required this.onTapCenter,
    required this.onTapLeft,
    required this.onTapRight,
  });

  @override
  State<_InteractiveComicPage> createState() => _InteractiveComicPageState();
}

class _InteractiveComicPageState extends State<_InteractiveComicPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_resetAnimation != null) {
          _transformController.value = _resetAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_transformController.value != Matrix4.identity()) {
      // Animate reset to 1.0x
      _resetAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      _animationController.forward(from: 0);
    } else {
      // Zoom in 2.5x at tap location
      final position = details.localPosition;
      final x = -position.dx * 1.5;
      final y = -position.dy * 1.5;
      final zoomed = Matrix4.diagonal3Values(2.5, 2.5, 1.0)
        ..setTranslationRaw(x, y, 0.0);

      _resetAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: zoomed,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return Stack(
          children: [
            // Pinch-to-zoomable comic image
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: () {},
                onTapUp: (details) {
                  // Only handle zone taps if not zoomed in
                  if (_transformController.value != Matrix4.identity()) {
                    return;
                  }
                  final dx = details.localPosition.dx;
                  if (dx < screenWidth * 0.28) {
                    widget.onTapLeft();
                  } else if (dx > screenWidth * 0.72) {
                    widget.onTapRight();
                  } else {
                    widget.onTapCenter();
                  }
                },
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 4.5,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_rounded, size: 54, color: Colors.white38),
                            const SizedBox(height: 12),
                            Text(
                              'Ошибка загрузки страницы ${widget.pageNumber}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ComicThumbnailsSheet extends StatelessWidget {
  final List<BookChapter> pages;
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  const _ComicThumbnailsSheet({
    required this.pages,
    required this.currentPage,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 4),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Страницы (${pages.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Текущая: ${currentPage + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryPinkDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: pages.length,
              itemBuilder: (ctx, idx) {
                final isCurrent = idx == currentPage;
                final file = File(pages[idx].content);

                return InkWell(
                  onTap: () => onSelectPage(idx),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? AppTheme.primaryPinkDark : Colors.transparent,
                        width: isCurrent ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          file,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey),
                            ),
                          ),
                        ),
                        // Number overlay pill
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppTheme.primaryPinkDark
                                  : Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicSettingsSheet extends StatelessWidget {
  final ComicReadingMode currentMode;
  final Color currentColor;
  final ValueChanged<ComicReadingMode> onModeChanged;
  final ValueChanged<Color> onColorChanged;

  const _ComicSettingsSheet({
    required this.currentMode,
    required this.currentColor,
    required this.onModeChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = [
      {'name': 'OLED Чёрный', 'color': Colors.black},
      {'name': 'Тёмный графит', 'color': const Color(0xFF1E1E1E)},
      {'name': 'Сепия', 'color': const Color(0xFFF4ECD8)},
      {'name': 'Белый', 'color': Colors.white},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Настройки чтения комикса / манги',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Режим чтения:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: ComicReadingMode.values.map((mode) {
                final isSelected = mode == currentMode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(mode.icon, size: 16, color: isSelected ? Colors.white : null),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              mode.name == 'leftToRight'
                                  ? 'L-R'
                                  : (mode.name == 'rightToLeft' ? 'R-L Манга' : 'Вебтун'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryPinkDark,
                      onSelected: (_) => onModeChanged(mode),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Фон страницы:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: colors.map((item) {
                final color = item['color'] as Color;
                final isSelected = currentColor.toARGB32() == color.toARGB32();

                return GestureDetector(
                  onTap: () => onColorChanged(color),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryPinkDark
                                : Colors.grey.withValues(alpha: 0.4),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['name'] as String,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
