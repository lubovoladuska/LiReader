import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HighlightToolbar extends StatelessWidget {
  final VoidCallback onAddNote;
  final VoidCallback onCopy;
  final Function(int colorValue) onColorSelected;
  final VoidCallback? onClearHighlight;

  const HighlightToolbar({
    super.key,
    required this.onAddNote,
    required this.onCopy,
    required this.onColorSelected,
    this.onClearHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242023) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
              blurRadius: 18,
              offset: const Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF423B3F) : const Color(0xFFEBE3E5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Color circles with soft glow on tap
            ...AppTheme.highlightColors.map((color) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => onColorSelected(color.toARGB32()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),

            Container(
              height: 20,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: isDark ? Colors.white12 : Colors.black12,
            ),

            // Note button
            IconButton(
              icon: const Icon(Icons.note_alt_outlined, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Добавить заметку',
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              onPressed: onAddNote,
            ),

            // Copy button
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 17),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Копировать',
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              onPressed: onCopy,
            ),

            if (onClearHighlight != null) ...[
              Container(
                height: 20,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              IconButton(
                icon: const Icon(Icons.format_color_reset_rounded, size: 18, color: Colors.redAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Удалить маркер',
                onPressed: onClearHighlight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
