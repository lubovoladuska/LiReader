import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HighlightToolbar extends StatelessWidget {
  final VoidCallback onAddNote;
  final VoidCallback onCopy;
  final Function(int colorValue) onColorSelected;
  final VoidCallback? onClearHighlight;
  final VoidCallback? onShareQuote;
  final VoidCallback? onTranslate;

  const HighlightToolbar({
    super.key,
    required this.onAddNote,
    required this.onCopy,
    required this.onColorSelected,
    this.onClearHighlight,
    this.onShareQuote,
    this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242023) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF4A4247) : const Color(0xFFE5DCDE),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Color circles with soft glow
              ...AppTheme.highlightColors.map((color) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () => onColorSelected(color.toARGB32()),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              Container(
                height: 18,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: isDark ? Colors.white12 : Colors.black12,
              ),

              // Note button
              IconButton(
                icon: const Icon(Icons.note_alt_outlined, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Добавить заметку',
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                onPressed: onAddNote,
              ),

              // Copy button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Копировать',
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                onPressed: onCopy,
              ),

              if (onTranslate != null) ...[
                IconButton(
                  icon: const Icon(Icons.g_translate_rounded, size: 17, color: AppTheme.primaryPinkDark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Перевести / Словарь',
                  onPressed: onTranslate,
                ),
              ],

              if (onShareQuote != null) ...[
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17, color: AppTheme.primaryPinkDark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Создать карточку цитаты',
                  onPressed: onShareQuote,
                ),
              ],

              if (onClearHighlight != null) ...[
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                IconButton(
                  icon: const Icon(Icons.format_color_reset_rounded, size: 17, color: Colors.redAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Удалить маркер',
                  onPressed: onClearHighlight,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
