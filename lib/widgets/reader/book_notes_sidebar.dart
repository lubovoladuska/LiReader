import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reader_provider.dart';
import '../../theme/app_theme.dart';

class BookNotesSidebar extends StatelessWidget {
  final Function(int chapterIndex) onSelectChapter;

  const BookNotesSidebar({
    super.key,
    required this.onSelectChapter,
  });

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final highlights = reader.highlights;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Заметки и цитаты',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${highlights.length}',
                    style: TextStyle(
                      color: AppTheme.primaryPinkDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (highlights.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Пока нет выделений и заметок.\nВыделите текст в книге для добавления.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: highlights.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, idx) {
                    final item = highlights[idx];
                    return InkWell(
                      onTap: () {
                        onSelectChapter(item.chapterIndex);
                        Navigator.pop(context); // Close drawer
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(item.colorValue),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Глава ${item.chapterIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryPinkDark,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => reader.deleteHighlight(item.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(item.colorValue).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.selectedText,
                                style: const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ),
                            if (item.note != null && item.note!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.edit_note, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.note!,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
