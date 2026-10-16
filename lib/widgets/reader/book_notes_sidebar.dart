import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/reader_provider.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import 'translation_sheet.dart';

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
    final vocabulary = reader.vocabulary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Drawer(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TabBar Header
              TabBar(
                labelColor: AppTheme.primaryPinkDark,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                indicatorColor: AppTheme.primaryPinkDark,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Заметки (${highlights.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_added_rounded, size: 17),
                        const SizedBox(width: 6),
                        Text('Словарь (${vocabulary.length})'),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),

              // TabBar Views
              Expanded(
                child: TabBarView(
                  children: [
                    // --- TAB 1: Highlights & Notes ---
                    _buildHighlightsTab(context, reader, highlights, isDark),

                    // --- TAB 2: Book Vocabulary ---
                    _buildVocabularyTab(context, reader, vocabulary, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsTab(
    BuildContext context,
    ReaderProvider reader,
    List<dynamic> highlights,
    bool isDark,
  ) {
    if (highlights.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Пока нет выделений и заметок.\nВыделите текст в книге для добавления.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.4),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: highlights.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
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
                      style: const TextStyle(
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
                    color: Color(item.colorValue).withValues(alpha: 0.2),
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
    );
  }

  Widget _buildVocabularyTab(
    BuildContext context,
    ReaderProvider reader,
    List<dynamic> vocabulary,
    bool isDark,
  ) {
    if (vocabulary.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'В словаре этой книги пока нет сохраненных слов.\nВыделите слово при чтении и нажмите кнопку перевода ✨',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.4),
          ),
        ),
      );
    }

    final cardBg = isDark ? const Color(0xFF242023) : const Color(0xFFF8F5F6);
    final borderCol = isDark ? const Color(0xFF3B3338) : const Color(0xFFEADBDE);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: vocabulary.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final item = vocabulary[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.word,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Speak audio
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Прослушать',
                    color: AppTheme.primaryPinkDark,
                    onPressed: () {
                      TtsService.instance.speakWord(item.word, lang: item.sourceLang);
                    },
                  ),
                  // Copy
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Копировать',
                    color: isDark ? Colors.white60 : Colors.black54,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${item.word} — ${item.translation}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Слово скопировано'), duration: Duration(milliseconds: 700)),
                      );
                    },
                  ),
                  // Open translator sheet
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Открыть перевод',
                    color: isDark ? Colors.white60 : Colors.black54,
                    onPressed: () {
                      Navigator.pop(context); // Close drawer
                      TranslationSheet.show(
                        context,
                        text: item.word,
                        contextSnippet: item.contextSnippet,
                        reader: reader,
                      );
                    },
                  ),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Удалить из словаря',
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    onPressed: () => reader.removeVocabularyWord(item.id),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.translation,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryPinkDark,
                ),
              ),
              if (item.definition != null && item.definition!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.definition!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
              if (item.contextSnippet != null && item.contextSnippet!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.contextSnippet!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
