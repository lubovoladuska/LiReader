import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HighlightContextMenu extends StatelessWidget {
  final String selectedText;
  final Function(int colorValue) onColorSelected;
  final VoidCallback onAddNote;
  final VoidCallback onCopy;

  const HighlightContextMenu({
    super.key,
    required this.selectedText,
    required this.onColorSelected,
    required this.onAddNote,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C272A) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF453D41) : AppTheme.lightDivider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color circles
            ...AppTheme.highlightColors.map((color) {
              return InkWell(
                onTap: () => onColorSelected(color.value),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
              );
            }),
            Container(
              height: 18,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            IconButton(
              icon: const Icon(Icons.note_add_outlined, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Добавить заметку',
              onPressed: onAddNote,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 17),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Копировать',
              onPressed: onCopy,
            ),
          ],
        ),
      ),
    );
  }
}
