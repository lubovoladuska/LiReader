import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reader_provider.dart';
import '../../theme/app_theme.dart';

class ChapterPickerDialog extends StatelessWidget {
  const ChapterPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final chapters = reader.parsedData?.chapters ?? [];
    final currentIdx = reader.currentChapterIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Выберите главу',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: chapters.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final isCurrent = idx == currentIdx;
                    final chap = chapters[idx];
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      selected: isCurrent,
                      selectedTileColor: AppTheme.primaryPink.withValues(alpha: 0.15),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isCurrent ? AppTheme.primaryPinkDark : (isDark ? Colors.white12 : Colors.black12),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                      title: Text(
                        chap.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent ? AppTheme.primaryPinkDark : null,
                        ),
                      ),
                      onTap: () {
                        reader.setChapter(idx);
                        Navigator.pop(context, idx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
