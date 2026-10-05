import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book_item.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
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
      context.read<LibraryProvider>().loadBooks();
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

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryPinkDark, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('LiReader', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryPinkDark, size: 26),
            tooltip: 'Добавить книгу',
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
          const SizedBox(width: 8),
        ],
      ),
      body: library.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar in JW Library style
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => library.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Поиск по названию или автору...',
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

                // Books Grid/List
                Expanded(
                  child: library.books.isEmpty
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
                                    ? 'В вашей библиотеке пока нет книг'
                                    : 'Ничего не найдено',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (library.searchQuery.isEmpty)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPinkDark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                                  label: const Text('Открыть файл (EPUB, PDF, FB2, TXT)'),
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
                                : constraints.maxWidth > 600
                                    ? 3
                                    : 2;

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.75,
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
    );
  }

  Widget _buildBookCard(BuildContext context, BookItem book, bool isDark) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
          ).then((_) {
            context.read<LibraryProvider>().loadBooks();
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
                      AppTheme.primaryPink.withOpacity(0.35),
                      AppTheme.accentPeach.withOpacity(0.4),
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
                        color: AppTheme.primaryPinkDark.withOpacity(0.8),
                      ),
                    ),
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
                          style: TextStyle(
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
