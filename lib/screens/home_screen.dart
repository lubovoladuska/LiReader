import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book_item.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/library/shelves_sidebar.dart';
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

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                  if (library.searchQuery.isEmpty)
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
                              ),
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
              leading: const Icon(Icons.folder_open_rounded, color: AppTheme.primaryPinkDark),
              title: const Text('Переместить на полку...'),
              onTap: () {
                Navigator.pop(ctx);
                _showAssignShelfDialog(context, book);
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
}
