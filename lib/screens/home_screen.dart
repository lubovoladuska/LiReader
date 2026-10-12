import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/book_item.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/library/shelves_sidebar.dart';
import '../services/update_service.dart';
import '../widgets/common/update_dialog.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadLibrary();
      _checkForUpdatesSilently();
    });
  }

  void _checkForUpdatesSilently() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      try {
        final info = await UpdateService.checkForUpdate();
        if (info.hasUpdate && mounted) {
          UpdateDialog.show(context, info);
        }
      } catch (e) {
        debugPrint('Silent update check error: $e');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getFormatBadgeColor(BookFormat format) {
    switch (format) {
      case BookFormat.epub:
        return const Color(0xFF6B8AFD);
      case BookFormat.pdf:
        return const Color(0xFFE25C5C);
      case BookFormat.fb2:
        return const Color(0xFF43B581);
      case BookFormat.txt:
      case BookFormat.markdown:
        return const Color(0xFFF5A623);
      default:
        return Colors.grey;
    }
  }

  void _showAddBooksToShelfDialog(BuildContext context, ShelfItem shelf) {
    final library = context.read<LibraryProvider>();
    final availableBooks = library.allBooks.where((b) => b.shelfId != shelf.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final selectedBookIds = <String>{};

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.playlist_add_rounded, color: AppTheme.primaryPinkDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Добавить книги в «${shelf.name}»',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              height: 380,
              child: availableBooks.isEmpty
                  ? const Center(
                      child: Text(
                        'Все книги из библиотеки уже находятся на этой полке',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: availableBooks.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final book = availableBooks[idx];
                        final isChecked = selectedBookIds.contains(book.id);

                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getFormatBadgeColor(book.format).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              book.format.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getFormatBadgeColor(book.format),
                              ),
                            ),
                          ),

                          activeColor: AppTheme.primaryPinkDark,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedBookIds.add(book.id);
                              } else {
                                selectedBookIds.remove(book.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              if (availableBooks.isNotEmpty)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryPinkDark),
                  onPressed: () {
                    for (final bookId in selectedBookIds) {
                      library.assignBookToShelf(bookId, shelf.id);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text('Добавить (${selectedBookIds.length})'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignShelfDialog(BuildContext context, BookItem book) {

    final library = context.read<LibraryProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Переместить на полку', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                title: const Text('Без полки'),
                onTap: () {
                  library.assignBookToShelf(book.id, null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ...library.shelves.map((s) => ListTile(
                    leading: const Icon(Icons.folder_outlined, color: AppTheme.primaryPinkDark),
                    title: Text(s.name),
                    trailing: book.shelfId == s.id ? const Icon(Icons.check, color: AppTheme.primaryPinkDark) : null,
                    onTap: () {
                      library.assignBookToShelf(book.id, s.id);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    String currentCategoryTitle = 'Все книги';
    switch (library.activeFilter) {
      case LibraryFilter.all:
        currentCategoryTitle = 'Все книги';
        break;
      case LibraryFilter.reading:
        currentCategoryTitle = 'Читаю сейчас';
        break;
      case LibraryFilter.favorites:
        currentCategoryTitle = 'Избранное';
        break;
      case LibraryFilter.shelf:
        currentCategoryTitle = library.activeShelf?.name ?? 'Полка';
        break;
    }

    return Scaffold(
      drawer: isDesktop ? null : const Drawer(child: ShelvesSidebar()),
      body: Row(
        children: [
          // Left Sidebar for desktop / tablet
          if (isDesktop) const ShelvesSidebar(),

          // Main Books Content
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  // Top App Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!isDesktop)
                          Builder(
                            builder: (ctx) => IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              padding: const EdgeInsets.only(right: 8),
                              constraints: const BoxConstraints(),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            currentCategoryTitle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (library.activeFilter == LibraryFilter.shelf && library.activeShelf != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryPinkDark,
                              side: const BorderSide(color: AppTheme.primaryPinkDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 10, vertical: isDesktop ? 10 : 8),
                            ),
                            icon: const Icon(Icons.playlist_add_rounded, size: 18),
                            label: Text(
                              isDesktop ? 'Выбрать из библиотеки' : 'Из библиотеки',
                              style: TextStyle(fontSize: isDesktop ? 14 : 12),
                            ),
                            onPressed: () => _showAddBooksToShelfDialog(context, library.activeShelf!),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Add Book button (icon-only on small screens, full button on desktop/tablet)

                        if (isDesktop)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryPinkDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Добавить книгу'),
                            onPressed: () async {
                              final newBook = await library.pickAndAddBook();
                              if (newBook != null && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ReaderScreen(book: newBook)),
                                );
                              }
                            },
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryPinkDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Добавить', style: TextStyle(fontSize: 13)),
                            onPressed: () async {
                              final newBook = await library.pickAndAddBook();
                              if (newBook != null && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ReaderScreen(book: newBook)),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                // Search Bar + View Mode + Sort Menu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => library.setSearchQuery(val),
                          decoration: InputDecoration(
                            hintText: 'Поиск книги или автора...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      library.setSearchQuery('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF2ECEE),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Menu Button
                      PopupMenuButton<LibrarySortBy>(
                        tooltip: 'Сортировка: ${library.sortBy.label}',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : const Color(0xFFF2ECEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.sort_rounded, size: 20),
                        ),
                        onSelected: (sortBy) => library.setSortBy(sortBy),
                        itemBuilder: (ctx) => LibrarySortBy.values.map((s) {
                          final isSelected = library.sortBy == s;
                          return PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_rounded, size: 18, color: AppTheme.primaryPinkDark)
                                else
                                  const SizedBox(width: 18),
                                const SizedBox(width: 8),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.primaryPinkDark : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(width: 4),

                      // View Mode Toggle Button (Grid / List)
                      IconButton(
                        tooltip: library.viewMode == LibraryViewMode.grid ? 'Вид: Список' : 'Вид: Сетка',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.darkSurface : const Color(0xFFF2ECEE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          library.viewMode == LibraryViewMode.grid
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                          size: 20,
                        ),
                        onPressed: () {
                          library.setViewMode(
                            library.viewMode == LibraryViewMode.grid
                                ? LibraryViewMode.list
                                : LibraryViewMode.grid,
                          );
                        },
                      ),
                    ],
                  ),
                ),


                // Format Filter Chips
                SingleChildScrollView(

                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildFormatChip(
                        context: context,
                        label: 'Все форматы',
                        icon: Icons.all_inclusive_rounded,
                        isSelected: library.selectedFormat == null,
                        count: library.allBooks.length,
                        onSelected: () => library.setFormatFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatChip(
                        context: context,
                        label: 'EPUB',
                        icon: Icons.book_rounded,
                        isSelected: library.selectedFormat == BookFormat.epub,
                        count: library.allBooks.where((b) => b.format == BookFormat.epub).length,
                        onSelected: () => library.setFormatFilter(
                          library.selectedFormat == BookFormat.epub ? null : BookFormat.epub,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatChip(
                        context: context,
                        label: 'FB2',
                        icon: Icons.collections_bookmark_rounded,
                        isSelected: library.selectedFormat == BookFormat.fb2,
                        count: library.allBooks.where((b) => b.format == BookFormat.fb2).length,
                        onSelected: () => library.setFormatFilter(
                          library.selectedFormat == BookFormat.fb2 ? null : BookFormat.fb2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatChip(
                        context: context,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_rounded,
                        isSelected: library.selectedFormat == BookFormat.pdf,
                        count: library.allBooks.where((b) => b.format == BookFormat.pdf).length,
                        onSelected: () => library.setFormatFilter(
                          library.selectedFormat == BookFormat.pdf ? null : BookFormat.pdf,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFormatChip(
                        context: context,
                        label: 'TXT / MD',
                        icon: Icons.description_rounded,
                        isSelected: library.selectedFormat == BookFormat.txt,
                        count: library.allBooks.where((b) => b.format == BookFormat.txt || b.format == BookFormat.markdown).length,
                        onSelected: () => library.setFormatFilter(
                          library.selectedFormat == BookFormat.txt ? null : BookFormat.txt,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Grid of books
                Expanded(

                  child: library.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : library.books.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories_outlined,
                                    size: 64,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    library.searchQuery.isEmpty
                                        ? 'В этой категории пока нет книг'
                                        : 'Ничего не найдено',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (library.searchQuery.isEmpty) ...[
                                    if (library.activeFilter == LibraryFilter.shelf && library.activeShelf != null) ...[
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.primaryPinkDark,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.playlist_add_rounded, size: 18),
                                        label: const Text('Выбрать книги из библиотеки'),
                                        onPressed: () => _showAddBooksToShelfDialog(context, library.activeShelf!),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.primaryPinkDark,
                                          side: const BorderSide(color: AppTheme.primaryPinkDark),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                                        label: const Text('Загрузить с устройства'),
                                        onPressed: () async {
                                          final newBook = await library.pickAndAddBook();
                                          if (newBook != null && context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => ReaderScreen(book: newBook)),
                                            );
                                          }
                                        },
                                      ),
                                    ] else
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.primaryPinkDark,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                                        label: const Text('Загрузить EPUB, PDF, FB2, TXT'),
                                        onPressed: () async {
                                          final newBook = await library.pickAndAddBook();
                                          if (newBook != null && context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => ReaderScreen(book: newBook)),
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                ],
                              ),
                            )

                          : library.viewMode == LibraryViewMode.list
                              ? ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: library.books.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, idx) {
                                    final book = library.books[idx];
                                    return _buildBookListTile(context, book, isDark);
                                  },
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final crossAxisCount = constraints.maxWidth > 900
                                        ? 4
                                        : constraints.maxWidth > 580
                                            ? 3
                                            : 2;

                                    return GridView.builder(
                                      padding: const EdgeInsets.all(16),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.72,
                                      ),
                                      itemCount: library.books.length,
                                      itemBuilder: (ctx, idx) {
                                        final book = library.books[idx];
                                        return _buildBookCard(context, book, isDark);
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildBookCard(BuildContext context, BookItem book, bool isDark) {
    final library = context.read<LibraryProvider>();
    final hasCover = book.coverPath != null && File(book.coverPath!).existsSync();
    final progressFraction = book.totalChaptersOrPages > 0
        ? ((book.currentChapterOrPage + 1) / book.totalChaptersOrPages).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : const Color(0xFFEFE8E9),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
          ).then((_) {
            library.loadLibrary();
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Image with JW Library proportions
            Expanded(
              flex: 14,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    Image.file(
                      File(book.coverPath!),
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryPink.withValues(alpha: 0.4),
                            AppTheme.accentPeach.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          book.format == BookFormat.pdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.menu_book_rounded,
                          size: 42,
                          color: AppTheme.primaryPinkDark.withValues(alpha: 0.85),
                        ),
                      ),
                    ),

                  // Format Pill Badge (JW Library style)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _getFormatBadgeColor(book.format).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        book.format.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Favorite Heart Action
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Icon(
                          book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: book.isFavorite ? Colors.redAccent : Colors.black45,
                          size: 20,
                        ),
                        onPressed: () => library.toggleFavorite(book.id),
                      ),
                    ),
                  ),

                  // Thin Progress Bar indicator at the bottom of the cover
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      color: Colors.black.withValues(alpha: 0.15),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progressFraction,
                        child: Container(
                          color: AppTheme.primaryPinkDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Book Details (JW Library typographic layout)
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Глава ${book.currentChapterOrPage + 1} из ${book.totalChaptersOrPages}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPinkDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, size: 17),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showBookOptions(context, book),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookListTile(BuildContext context, BookItem book, bool isDark) {
    final library = context.read<LibraryProvider>();
    final hasCover = book.coverPath != null && File(book.coverPath!).existsSync();
    final progressFraction = book.totalChaptersOrPages > 0
        ? ((book.currentChapterOrPage + 1) / book.totalChaptersOrPages).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progressFraction * 100).toInt();

    return Material(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: isDark ? 0 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
          ).then((_) {
            library.loadLibrary();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkDivider : const Color(0xFFEFE8E9),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: hasCover
                      ? Image.file(
                          File(book.coverPath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryPink.withValues(alpha: 0.4),
                                AppTheme.accentPeach.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              book.format == BookFormat.pdf
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.menu_book_rounded,
                              size: 26,
                              color: AppTheme.primaryPinkDark.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getFormatBadgeColor(book.format).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            book.format.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${book.currentChapterOrPage + 1}/${book.totalChaptersOrPages} ($progressPercent%)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryPinkDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progressFraction,
                                  minHeight: 3,
                                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryPinkDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons
              IconButton(
                icon: Icon(
                  book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: book.isFavorite ? Colors.redAccent : (isDark ? Colors.white38 : Colors.black38),
                  size: 20,
                ),
                onPressed: () => library.toggleFavorite(book.id),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onPressed: () => _showBookOptions(context, book),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookOptions(BuildContext context, BookItem book) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryPinkDark),
              title: const Text('Переименовать книгу...'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameBookDialog(context, book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded, color: AppTheme.primaryPinkDark),
              title: const Text('Переместить на полку...'),
              onTap: () {
                Navigator.pop(ctx);
                _showAssignShelfDialog(context, book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: AppTheme.primaryPinkDark),
              title: const Text('Привязать файл книги...'),
              subtitle: Text(
                File(book.filePath).existsSync() ? 'Файл книги подключён' : 'Файл не найден на устройстве',
                style: TextStyle(
                  fontSize: 11,
                  color: File(book.filePath).existsSync() ? Colors.green : Colors.redAccent,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['epub', 'fb2', 'txt', 'md', 'pdf'],
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
                  final newPath = result.files.single.path!;
                  if (context.mounted) {
                    final ok = await context.read<LibraryProvider>().relinkBook(book.id, newPath);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Файл «${p.basename(newPath)}» успешно привязан!' : 'Не удалось привязать файл'),
                          backgroundColor: ok ? Colors.green : Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(
                book.isFavorite ? Icons.favorite_border_rounded : Icons.favorite_rounded,
                color: Colors.redAccent,
              ),
              title: Text(book.isFavorite ? 'Убрать из избранного' : 'Добавить в избранное'),
              onTap: () {
                context.read<LibraryProvider>().toggleFavorite(book.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Удалить из библиотеки', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                context.read<LibraryProvider>().removeBook(book.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameBookDialog(BuildContext context, BookItem book) {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Переименовать книгу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Название книги',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorController,
              decoration: InputDecoration(
                labelText: 'Автор',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryPinkDark),
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newAuthor = authorController.text.trim();
              if (newTitle.isNotEmpty) {
                context.read<LibraryProvider>().updateBookDetails(
                  book.id,
                  title: newTitle,
                  author: newAuthor.isNotEmpty ? newAuthor : 'Автор не указан',
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }


  Widget _buildFormatChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required int count,
    required VoidCallback onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      label: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selectedColor: AppTheme.primaryPinkDark,
      backgroundColor: isDark ? AppTheme.darkSurface : const Color(0xFFF3ECEE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryPinkDark
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (_) => onSelected(),
    );
  }
}

