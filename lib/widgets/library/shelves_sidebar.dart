import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_item.dart';
import '../../providers/library_provider.dart';
import '../../screens/reading_stats_screen.dart';
import '../../services/backup_service.dart';
import '../../services/feedback_service.dart';
import '../../services/changelog_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../common/about_dialog.dart';
import '../common/app_logo.dart';
import '../common/update_dialog.dart';

class ShelvesSidebar extends StatelessWidget {
  const ShelvesSidebar({super.key});

  void _checkForUpdateManual(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Проверка обновлений на GitHub...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final info = await UpdateService.checkForUpdate();
    if (!context.mounted) return;

    if (info.hasUpdate) {
      UpdateDialog.show(context, info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('У вас установлена последняя версия (v${info.currentVersion}) 👍'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

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
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                final shelf = await context.read<LibraryProvider>().createShelf(name);
                if (context.mounted) {
                  context.read<LibraryProvider>().setFilter(LibraryFilter.shelf, shelfId: shelf.id);
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showBackupOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.backup_rounded, color: AppTheme.primaryPinkDark, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Резервная копия данных',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Сохраните всю библиотеку, сессии чтения и цитаты в файл перед переустановкой приложения.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: AppTheme.primaryPink.withValues(alpha: 0.12),
                leading: const Icon(Icons.file_upload_rounded, color: AppTheme.primaryPinkDark),
                title: const Text('Создать копию (Экспорт в JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Сохранить файл в Загрузки и скопировать'),
                onTap: () {
                  Navigator.pop(ctx);
                  BackupService.exportBackup(context);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: Colors.black.withValues(alpha: 0.04),
                leading: const Icon(Icons.file_download_rounded, color: Colors.blueAccent),
                title: const Text('Восстановить из файла (Импорт)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Выбрать сохраненный .json файл'),
                onTap: () {
                  Navigator.pop(ctx);
                  BackupService.importBackup(context);
                },
              ),
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
                const AppLogo(size: 30, borderRadius: 8),
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
                _buildNavItem(
                  context: context,
                  title: 'Статистика',
                  icon: Icons.insights_rounded,
                  count: null,
                  isSelected: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReadingStatsScreen()),
                    );
                  },
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

          const Divider(height: 1),

          // Footer: Developer WhatsApp & About Dialog
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 19),
                    title: const Text(
                      'Написать автору',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF25D366),
                      ),
                    ),
                    subtitle: const Text(
                      'WhatsApp (+7 708 715 35 37)',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    onTap: () => FeedbackService.openDeveloperWhatsApp(context),
                  ),
                ),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.backup_rounded, size: 20, color: AppTheme.primaryPinkDark),
                  title: const Text(
                    'Резервная копия',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Экспорт / Импорт данных',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  onTap: () => _showBackupOptionsSheet(context),
                ),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.system_update_rounded, size: 20, color: AppTheme.primaryPinkDark),
                  title: const Text(
                    'Проверить обновления',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Поиск новой версии на GitHub',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  onTap: () => _checkForUpdateManual(context),
                ),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.info_outline_rounded, size: 20),
                  title: const Text(
                    'О приложении',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    'v${ChangelogService.currentVersion}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => AboutLiReaderDialog.show(context),
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
    int? count,
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
        trailing: (count != null && count > 0)
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


