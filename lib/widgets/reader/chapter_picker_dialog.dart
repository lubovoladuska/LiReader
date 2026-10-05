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
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: chapters.length,
                  itemBuilder: (ctx, idx) {
                    final isCurrent = idx == currentIdx;
                    return InkWell(
                      onTap: () {
                        reader.setChapter(idx);
                        Navigator.pop(context, idx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.primaryPinkDark
                              : (isDark ? AppTheme.darkCard : const Color(0xFFF6EFF1)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.primaryPinkDark
                                : (isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                          ),
                        ),
                      ),
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
