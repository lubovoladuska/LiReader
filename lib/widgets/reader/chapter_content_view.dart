import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/book_item.dart';
import '../../models/reader_theme_settings.dart';
import '../../providers/reader_provider.dart';
import '../../services/book_parser_service.dart';
import '../../theme/app_theme.dart';
import 'highlight_context_menu.dart';

class ChapterContentView extends StatefulWidget {
  final int chapterIndex;
  final String title;
  final String content;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousChapter;

  const ChapterContentView({
    super.key,
    required this.chapterIndex,
    required this.title,
    required this.content,
    this.onNextChapter,
    this.onPreviousChapter,
  });

  @override
  State<ChapterContentView> createState() => _ChapterContentViewState();
}


class _ChapterContentViewState extends State<ChapterContentView> {
  final ScrollController _scrollController = ScrollController();
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _handleTap(ReaderProvider reader) {
    reader.registerUserActivity();
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds > 300) {
      _lastTapTime = now;
      reader.toggleMenu();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Restore scroll position after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reader = context.read<ReaderProvider>();
      if (reader.book.currentChapterOrPage == widget.chapterIndex && reader.book.scrollProgress > 0) {
        if (_scrollController.hasClients) {
          final max = _scrollController.position.maxScrollExtent;
          final target = reader.book.scrollProgress.clamp(0.0, max);
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final reader = context.read<ReaderProvider>();
      if (reader.currentChapterIndex == widget.chapterIndex) {
        final max = _scrollController.position.maxScrollExtent;
        final frac = max > 0 ? (_scrollController.offset / max).clamp(0.0, 1.0) : 1.0;
        reader.saveScrollProgress(_scrollController.offset, fractional: frac);
      }
    }
  }


  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
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

  void _showHighlightActionSheet(
    BuildContext context,
    BookHighlight highlight,
    ReaderProvider reader,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(highlight.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Выделенный фрагмент', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Удалить маркер',
                    onPressed: () {
                      reader.deleteHighlight(highlight.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(highlight.colorValue).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  highlight.selectedText,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              if (highlight.note != null && highlight.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Заметка: ${highlight.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Копировать'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: highlight.selectedText));
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryPinkDark),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Заметка / Цвет'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddNoteDialog(context, highlight.selectedText, reader);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds TextSpans with inline highlights painted onto matching text
  List<TextSpan> _buildHighlightedSpans(
    BuildContext context,
    String fullText,
    List<BookHighlight> highlights,
    Color baseTextColor,
    ReaderProvider reader,
  ) {
    if (highlights.isEmpty) {
      return [TextSpan(text: fullText, style: TextStyle(color: baseTextColor))];
    }

    final spans = <TextSpan>[];
    int cursor = 0;

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
          highlight: h,
        ));
        searchFrom = found + h.selectedText.length;
      }
    }

    intervals.sort((a, b) => a.start.compareTo(b.start));

    for (final interval in intervals) {
      if (interval.start < cursor) continue;

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
          backgroundColor: Color(interval.highlight.colorValue).withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _showHighlightActionSheet(context, interval.highlight, reader);
          },
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

  Widget _buildBackgroundLayer(ReaderThemeSettings settings) {
    if (!settings.hasBackgroundImage) {
      return Container(color: settings.activeBackground);
    }

    final path = settings.backgroundImagePath!;
    final ImageProvider imageProvider = settings.isAssetBackground
        ? AssetImage(path)
        : FileImage(File(path)) as ImageProvider;

    BoxFit fit = BoxFit.cover;
    ImageRepeat repeat = ImageRepeat.noRepeat;

    switch (settings.backgroundFit) {
      case ReaderBackgroundFit.cover:
        fit = BoxFit.cover;
        repeat = ImageRepeat.noRepeat;
        break;
      case ReaderBackgroundFit.contain:
        fit = BoxFit.contain;
        repeat = ImageRepeat.noRepeat;
        break;
      case ReaderBackgroundFit.tile:
        fit = BoxFit.none;
        repeat = ImageRepeat.repeat;
        break;
      case ReaderBackgroundFit.fill:
        fit = BoxFit.fill;
        repeat = ImageRepeat.noRepeat;
        break;
    }

    Widget imageWidget = Image(
      image: imageProvider,
      fit: fit,
      repeat: repeat,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) => Container(color: settings.activeBackground),
    );

    if (settings.backgroundRotation != 0) {
      final quarterTurns = (settings.backgroundRotation ~/ 90) % 4;
      imageWidget = RotatedBox(
        quarterTurns: quarterTurns,
        child: imageWidget,
      );
    }

    if (settings.backgroundBlur > 0) {
      imageWidget = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: settings.backgroundBlur,
          sigmaY: settings.backgroundBlur,
        ),
        child: imageWidget,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: settings.activeBackground),
        imageWidget,
        if (settings.backgroundDimming > 0)
          Container(
            color: Colors.black.withValues(alpha: settings.backgroundDimming),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final settings = reader.themeSettings;
    final textColor = settings.activeText;

    final sanitizedContent = BookParserService.sanitizeReadingText(widget.content);
    final chapterHighlights = reader.highlights.where((h) => h.chapterIndex == widget.chapterIndex).toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _handleTap(reader),
      child: Container(
        color: settings.activeBackground,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackgroundLayer(settings),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.only(
                      left: settings.horizontalPadding,
                      right: settings.horizontalPadding,
                      top: MediaQuery.paddingOf(context).top + 20,
                      bottom: 50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Chapter Header (only show if not already present in content)
                      if (!sanitizedContent.trimLeft().toLowerCase().startsWith(widget.title.trim().toLowerCase()))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            widget.title,
                            textAlign: settings.textAlign,
                            style: TextStyle(
                              fontFamily: settings.fontFamily.fontFamily,
                              fontSize: settings.fontSize * 1.35,
                              fontWeight: FontWeight.bold,
                              letterSpacing: settings.letterSpacing,
                              color: AppTheme.primaryPinkDark,
                            ),
                          ),
                        ),

                      // Chapter Content with rich styling
                      SelectableText.rich(
                        TextSpan(
                          children: _buildHighlightedSpans(
                            context,
                            sanitizedContent,
                            chapterHighlights,
                            textColor,
                            reader,
                          ),
                        ),
                        onTap: () => _handleTap(reader),
                        textAlign: settings.textAlign,
                        style: TextStyle(
                          fontFamily: settings.fontFamily.fontFamily,
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          letterSpacing: settings.letterSpacing,
                          color: textColor,
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

                  // Bottom navigation for chapters
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: settings.hasBackgroundImage
                          ? Colors.black.withValues(alpha: 0.35)
                          : (settings.activeBackground == const Color(0xFF0F0E0F) || settings.activeBackground == const Color(0xFF242023)
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: settings.activeText.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.onPreviousChapter != null)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: settings.activeText.withValues(alpha: 0.8),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('Предыдущая глава', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            onPressed: widget.onPreviousChapter,
                          )
                        else
                          const SizedBox.shrink(),
                        if (widget.onNextChapter != null)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryPinkDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Следующая глава', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            onPressed: widget.onNextChapter,
                          )
                        else
                          Text(
                            'Конец книги',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: settings.activeText.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom spacer for comfortable reading
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}

class _HighlightInterval {
  final int start;
  final int end;
  final BookHighlight highlight;

  _HighlightInterval({
    required this.start,
    required this.end,
    required this.highlight,
  });
}
