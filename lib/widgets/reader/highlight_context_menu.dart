import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HighlightToolbar extends StatelessWidget {
  final VoidCallback onAddNote;
  final VoidCallback onCopy;
  final Function(int colorValue) onColorSelected;

  const HighlightToolbar({
    super.key,
    required this.onAddNote,
    required this.onCopy,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      color: isDark ? const Color(0xFF2E292C) : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF453D41) : AppTheme.lightDivider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...AppTheme.highlightColors.map((color) {
              return InkWell(
                onTap: () => onColorSelected(color.toARGB32()),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.15),
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
              tooltip: 'Заметка',
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
