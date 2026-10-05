import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  OverlayEntry? _contextMenuOverlay;

  @override
  void dispose() {
    _removeContextMenu();
    _scrollController.dispose();
    super.dispose();
  }

  void _removeContextMenu() {
    _contextMenuOverlay?.remove();
    _contextMenuOverlay = null;
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    String selectedText,
    ReaderProvider reader,
  ) {
    _removeContextMenu();

    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _contextMenuOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeContextMenu,
            ),
          ),
          Positioned(
            left: (position.dx - 140).clamp(16.0, MediaQuery.of(context).size.width - 290),
            top: (position.dy - 60).clamp(40.0, MediaQuery.of(context).size.height - 80),
            child: HighlightContextMenu(
              selectedText: selectedText,
              onColorSelected: (colorVal) async {
                await reader.addHighlight(
                  selectedText: selectedText,
                  colorValue: colorVal,
                );
                _removeContextMenu();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Фрагмент выделен маркером'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              onAddNote: () {
                _removeContextMenu();
                _showAddNoteDialog(context, selectedText, reader);
              },
              onCopy: () {
                Clipboard.setData(ClipboardData(text: selectedText));
                _removeContextMenu();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Скопировано в буфер обмена'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );

    overlay.insert(_contextMenuOverlay!);
  }

  void _showAddNoteDialog(BuildContext context, String text, ReaderProvider reader) {
    final noteController = TextEditingController();
    int selectedColor = AppTheme.highlightColors.first.value;

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
                  color: Color(selectedColor).withOpacity(0.3),
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
                  final isSelected = c.value == selectedColor;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = c.value),
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

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    // Highlights for this chapter
    final chapterHighlights = reader.highlights.where((h) => h.chapterIndex == widget.chapterIndex).toList();

    return GestureDetector(
      onTap: () {
        _removeContextMenu();
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
                  // Chapter Header
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

                  // Chapter Content with selection support
                  SelectableText(
                    widget.content,
                    style: TextStyle(
                      fontSize: reader.fontSize,
                      height: reader.lineHeight,
                      color: textColor,
                    ),
                    contextMenuBuilder: (ctx, editableTextState) {
                      // Custom selection menu
                      final selection = editableTextState.textEditingValue.selection;
                      final selectedText = editableTextState.textEditingValue.text.substring(
                        selection.start,
                        selection.end,
                      );

                      if (selectedText.trim().isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final renderBox = ctx.findRenderObject() as RenderBox?;
                          final pos = renderBox != null
                              ? renderBox.localToGlobal(Offset.zero)
                              : Offset(MediaQuery.of(context).size.width / 2, 200);
                          _showContextMenu(context, pos, selectedText, reader);
                        });
                      }

                      return const SizedBox.shrink();
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
