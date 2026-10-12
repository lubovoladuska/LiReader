import 'package:flutter/material.dart';
import '../../services/feedback_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import 'app_logo.dart';
import 'update_dialog.dart';

class AboutLiReaderDialog extends StatelessWidget {
  const AboutLiReaderDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const AboutLiReaderDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Logo
          const AppLogo(size: 72, borderRadius: 18),
          const SizedBox(height: 16),

          // App Name
          const Text(
            'LiReader',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Версия 1.0.0 (Release)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryPinkDark,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            'Элегантная, быстрая читалка книг без рекламы. Поддерживает форматы EPUB, FB2, PDF и TXT с богатыми настройками оформления и умной статистикой.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),

          // Compatibility info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Поддержка Android',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Android 5.0 (Lollipop) — Android 15 (99.5%+ устройств)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Check for Updates CTA Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.system_update_rounded, size: 20, color: AppTheme.primaryPinkDark),
              label: const Text(
                'Проверить обновления (GitHub)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final info = await UpdateService.checkForUpdate();
                if (context.mounted) {
                  if (info.hasUpdate) {
                    UpdateDialog.show(context, info);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('У вас установлена последняя версия (v${info.currentVersion}) 👍'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 10),

          // Developer WhatsApp CTA Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Написать разработчику (WhatsApp)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(context);
                FeedbackService.openDeveloperWhatsApp(context);
              },
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
