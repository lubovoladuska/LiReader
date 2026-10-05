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
            child: Column(
              children: [
                // Top App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      Text(
                        currentCategoryTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // Add Book button
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
        ],
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, BookItem book, bool isDark) {
    final library = context.read<LibraryProvider>();

    return Card(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover placeholder with pastel tones
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryPink.withValues(alpha: 0.35),
                      AppTheme.accentPeach.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        book.format == BookFormat.pdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.menu_book_rounded,
                        size: 44,
                        color: AppTheme.primaryPinkDark.withValues(alpha: 0.8),
                      ),
                    ),
                    // Format badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getFormatBadgeColor(book.format),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          book.format.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Favorite button
                    Positioned(
                      top: 4,
                      left: 4,
                      child: IconButton(
                        icon: Icon(
                          book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: book.isFavorite ? Colors.redAccent : Colors.black38,
                          size: 20,
                        ),
                        onPressed: () => library.toggleFavorite(book.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Book details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
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
                      children: [
                        Text(
                          'Глава ${book.currentChapterOrPage + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPinkDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _showBookOptions(context, book);
                          },
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
