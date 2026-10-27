import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class SmartFootnoteSheet extends StatelessWidget {
  final String title;
  final String content;
  final Color backgroundColor;
  final Color textColor;

  const SmartFootnoteSheet({
    super.key,
    required this.title,
    required this.content,
    required this.backgroundColor,
    required this.textColor,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
    required Color backgroundColor,
    required Color textColor,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartFootnoteSheet(
        title: title,
        content: content,
        backgroundColor: backgroundColor,
        textColor: textColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B1E) : Colors.white;
    final cardText = isDark ? Colors.white : Colors.black87;
    final subtitleColor = cardText.withValues(alpha: 0.6);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: subtitleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPinkDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: AppTheme.primaryPinkDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cardText,
                          ),
                        ),
                        Text(
                          'Сноска из текста книги',
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: subtitleColor),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Footnote Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: cardText,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: subtitleColor,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Копировать'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Текст сноски скопирован в буфер обмена'),
                          duration: Duration(milliseconds: 1200),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryPinkDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Понятно'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
