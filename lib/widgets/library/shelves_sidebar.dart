import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_item.dart';
import '../../providers/library_provider.dart';
import '../../theme/app_theme.dart';

class ShelvesSidebar extends StatelessWidget {
  const ShelvesSidebar({super.key});

  void _showCreateShelfDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Новая полка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Название полки (напр. Учеба, Роман)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryPinkDark),
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                context.read<LibraryProvider>().createShelf(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeFilter = library.activeFilter;
    final selectedShelfId = library.selectedShelfId;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFFBF8F9),
        border: Border(
          right: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryPinkDark, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'LiReader',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: [
                _buildNavItem(
                  context: context,
                  title: 'Все книги',
                  icon: Icons.library_books_rounded,
                  count: library.allBooks.length,
                  isSelected: activeFilter == LibraryFilter.all,
                  onTap: () => library.setFilter(LibraryFilter.all),
                ),
                _buildNavItem(
                  context: context,
                  title: 'Читаю сейчас',
                  icon: Icons.menu_book_rounded,
                  count: library.allBooks.where((b) => b.currentChapterOrPage > 0 || b.scrollProgress > 0).length,
                  isSelected: activeFilter == LibraryFilter.reading,
                  onTap: () => library.setFilter(LibraryFilter.reading),
                ),
                _buildNavItem(
                  context: context,
                  title: 'Избранное',
                  icon: Icons.favorite_rounded,
                  count: library.allBooks.where((b) => b.isFavorite).length,
                  isSelected: activeFilter == LibraryFilter.favorites,
                  onTap: () => library.setFilter(LibraryFilter.favorites),
                ),

                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'МОИ ПОЛКИ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Создать полку',
                        onPressed: () => _showCreateShelfDialog(context),
                      ),
                    ],
                  ),
                ),

                if (library.shelves.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Нет созданных полок.\nНажмите +, чтобы добавить.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  )
                else
                  ...library.shelves.map((shelf) {
                    final count = library.allBooks.where((b) => b.shelfId == shelf.id).length;
                    final isSelected = activeFilter == LibraryFilter.shelf && selectedShelfId == shelf.id;
                    return _buildShelfItem(
                      context: context,
                      shelf: shelf,
                      count: count,
                      isSelected: isSelected,
                      onTap: () => library.setFilter(LibraryFilter.shelf, shelfId: shelf.id),
                      onDelete: () => library.deleteShelf(shelf.id),
                    );
                  }),

                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'ФОРМАТЫ КНИГ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),

                _buildFormatItem(
                  context: context,
                  title: 'EPUB книги',
                  icon: Icons.book_rounded,
                  count: library.allBooks.where((b) => b.format == BookFormat.epub).length,
                  isSelected: library.selectedFormat == BookFormat.epub,
                  onTap: () {
                    if (library.selectedFormat == BookFormat.epub) {
                      library.setFormatFilter(null);
                    } else {
                      library.setFormatFilter(BookFormat.epub);
                    }
                  },
                ),
                _buildFormatItem(
                  context: context,
                  title: 'FB2 книги',
                  icon: Icons.collections_bookmark_rounded,
                  count: library.allBooks.where((b) => b.format == BookFormat.fb2).length,
                  isSelected: library.selectedFormat == BookFormat.fb2,
                  onTap: () {
                    if (library.selectedFormat == BookFormat.fb2) {
                      library.setFormatFilter(null);
                    } else {
                      library.setFormatFilter(BookFormat.fb2);
                    }
                  },
                ),
                _buildFormatItem(
                  context: context,
                  title: 'PDF документы',
                  icon: Icons.picture_as_pdf_rounded,
                  count: library.allBooks.where((b) => b.format == BookFormat.pdf).length,
                  isSelected: library.selectedFormat == BookFormat.pdf,
                  onTap: () {
                    if (library.selectedFormat == BookFormat.pdf) {
                      library.setFormatFilter(null);
                    } else {
                      library.setFormatFilter(BookFormat.pdf);
                    }
                  },
                ),
                _buildFormatItem(
                  context: context,
                  title: 'Текст (TXT / MD)',
                  icon: Icons.description_rounded,
                  count: library.allBooks.where((b) => b.format == BookFormat.txt || b.format == BookFormat.markdown).length,
                  isSelected: library.selectedFormat == BookFormat.txt,
                  onTap: () {
                    if (library.selectedFormat == BookFormat.txt) {
                      library.setFormatFilter(null);
                    } else {
                      library.setFormatFilter(BookFormat.txt);
                    }
                  },
                ),
              ],
            ),
          ),

        ],
      ),
    ),
  );
}

  Widget _buildNavItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          size: 20,
          color: isSelected
              ? AppTheme.primaryPinkDark
              : (isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryPinkDark : null,
          ),
        ),
        trailing: count > 0
            ? Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primaryPinkDark : Colors.grey,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildShelfItem({
    required BuildContext context,
    required ShelfItem shelf,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          Icons.folder_outlined,
          size: 19,
          color: isSelected
              ? AppTheme.primaryPinkDark
              : (isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(
          shelf.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryPinkDark : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primaryPinkDark : Colors.grey,
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Удалить полку',
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFormatItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          size: 19,
          color: isSelected
              ? AppTheme.primaryPinkDark
              : (isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryPinkDark : null,
          ),
        ),
        trailing: count > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryPinkDark.withValues(alpha: 0.15)
                      : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.primaryPinkDark : Colors.grey,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}


