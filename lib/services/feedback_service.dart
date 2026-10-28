import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'changelog_service.dart';

class FeedbackService {
  static const String developerPhoneNumber = '+77087153537';
  static const String whatsappNumberDigits = '77087153537';
  static String get defaultFeedbackMessage =>
      'Здравствуйте! Я пользуюсь приложением LiReader (v${ChangelogService.currentVersion}). Хочу поделиться отзывом: ';

  /// Opens developer's WhatsApp with a pre-filled greeting message.
  static Future<void> openDeveloperWhatsApp(
    BuildContext context, {
    String? message,
  }) async {
    final effectiveMessage = message ?? defaultFeedbackMessage;
    final encodedMessage = Uri.encodeComponent(effectiveMessage);
    final waMeUrl = 'https://wa.me/$whatsappNumberDigits?text=$encodedMessage';
    final waUri = Uri.parse(waMeUrl);

    try {
      final launched = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showFallbackDialog(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showFallbackDialog(context);
      }
    }
  }

  static void _showFallbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 10),
            Text('Связь в WhatsApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Не удалось автоматически открыть WhatsApp. Вы можете написать напрямую по номеру:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    developerPhoneNumber,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF128C7E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF128C7E)),
                    tooltip: 'Скопировать номер',
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: developerPhoneNumber));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Номер скопирован в буфер обмена'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(milliseconds: 1500),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
