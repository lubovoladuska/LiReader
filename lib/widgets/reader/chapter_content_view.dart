import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/book_item.dart';
import '../../providers/reader_provider.dart';
import '../../theme/app_theme.dart';
import 'highlight_context_menu.dart';

class ChapterContentView extends StatefulWidget {
  final int chapterIndex;
  final String title;
  final String content;

  const ChapterContentView({
    super.key,
    required this.chapterIndex,
    required this.title,
    required this.content,
  });

  @override
  State<ChapterContentView> createState() => _ChapterContentViewState();
}

class _ChapterContentViewState extends State<ChapterContentView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddNoteDialog(BuildContext context, String text, ReaderProvider reader) {
    final noteController = TextEditingController();
    int selectedColor = AppTheme.highlightColors.first.toARGB32();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Заметка к фрагменту', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(selectedColor).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text.length > 120 ? '${text.substring(0, 120)}...' : text,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Цвет маркера:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: AppTheme.highlightColors.map((c) {
                  final isSelected = c.toARGB32() == selectedColor;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = c.toARGB32()),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.black12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Введите ваши мысли или комментарий...',
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryPinkDark,
              ),
              onPressed: () async {
                await reader.addHighlight(
                  selectedText: text,
                  colorValue: selectedColor,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds TextSpans with inline highlights painted onto matching text
  List<TextSpan> _buildHighlightedSpans(
    String fullText,
    List<BookHighlight> highlights,
    Color baseTextColor,
  ) {
    if (highlights.isEmpty) {
      return [TextSpan(text: fullText, style: TextStyle(color: baseTextColor))];
    }

    // Find occurrences of highlighted texts
    final spans = <TextSpan>[];
    int cursor = 0;

    // Helper map of text intervals
    final intervals = <_HighlightInterval>[];
    for (final h in highlights) {
      if (h.selectedText.trim().isEmpty) continue;
      int searchFrom = 0;
      while (true) {
        final found = fullText.indexOf(h.selectedText, searchFrom);
        if (found == -1) break;
        intervals.add(_HighlightInterval(
          start: found,
          end: found + h.selectedText.length,
          color: Color(h.colorValue),
          note: h.note,
        ));
        searchFrom = found + h.selectedText.length;
      }
    }

    // Sort intervals by start pos
    intervals.sort((a, b) => a.start.compareTo(b.start));

    for (final interval in intervals) {
      if (interval.start < cursor) continue; // Skip overlaps for simplicity

      if (interval.start > cursor) {
        spans.add(TextSpan(
          text: fullText.substring(cursor, interval.start),
          style: TextStyle(color: baseTextColor),
        ));
      }

      spans.add(TextSpan(
        text: fullText.substring(interval.start, interval.end),
        style: TextStyle(
          color: Colors.black87,
          backgroundColor: interval.color.withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        ),
      ));

      cursor = interval.end;
    }

    if (cursor < fullText.length) {
      spans.add(TextSpan(
        text: fullText.substring(cursor),
        style: TextStyle(color: baseTextColor),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final chapterHighlights = reader.highlights.where((h) => h.chapterIndex == widget.chapterIndex).toList();

    return GestureDetector(
      onTap: () {
        reader.toggleMenu();
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chapter Header (only show if not already present in content)
                  if (!widget.content.trimLeft().toLowerCase().startsWith(widget.title.trim().toLowerCase()))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: reader.fontSize * 1.35,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPinkDark,
                        ),
                      ),
                    ),

                  // Chapter Content with native SelectableText and Toolbar
                  SelectableText.rich(
                    TextSpan(
                      children: _buildHighlightedSpans(
                        widget.content,
                        chapterHighlights,
                        textColor,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: reader.fontSize,
                      height: reader.lineHeight,
                    ),
                    contextMenuBuilder: (context, editableTextState) {
                      final selection = editableTextState.textEditingValue.selection;
                      final selectedText = editableTextState.textEditingValue.text.substring(
                        selection.start,
                        selection.end,
                      );

                      if (selectedText.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return AdaptiveTextSelectionToolbar(
                        anchors: editableTextState.contextMenuAnchors,
                        children: [
                          HighlightToolbar(
                            onColorSelected: (colorVal) async {
                              await reader.addHighlight(
                                selectedText: selectedText,
                                colorValue: colorVal,
                              );
                              editableTextState.hideToolbar();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Фрагмент подсвечен маркером'),
                                    duration: Duration(milliseconds: 900),
                                  ),
                                );
                              }
                            },
                            onAddNote: () {
                              editableTextState.hideToolbar();
                              _showAddNoteDialog(context, selectedText, reader);
                            },
                            onCopy: () {
                              Clipboard.setData(ClipboardData(text: selectedText));
                              editableTextState.hideToolbar();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Скопировано в буфер обмена'),
                                    duration: Duration(milliseconds: 900),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),

                  // Bottom spacer for comfortable reading
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightInterval {
  final int start;
  final int end;
  final Color color;
  final String? note;

  _HighlightInterval({
    required this.start,
    required this.end,
    required this.color,
    this.note,
  });
}
