import 'package:flutter/material.dart';
import '../../providers/reader_provider.dart';
import '../../theme/app_theme.dart';

class SleepTimerDialog extends StatelessWidget {
  final ReaderProvider reader;
  final VoidCallback onTimerFinished;

  const SleepTimerDialog({
    super.key,
    required this.reader,
    required this.onTimerFinished,
  });

  String _formatRemaining(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = reader.isSleepTimerActive;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bedtime_rounded, color: AppTheme.primaryPinkDark, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Таймер сна', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isActive) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryPink.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('Таймер активен', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    _formatRemaining(reader.sleepTimerRemainingSeconds),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryPinkDark,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Приложение автоматически сохранит позицию и закроет книгу по истечении времени.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Отключить таймер'),
              onPressed: () {
                reader.cancelSleepTimer();
                Navigator.pop(context);
              },
            ),
          ] else ...[
            Text(
              'Выберите время, через которое книга автоматически закроется с сохранением прогресса:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPresetButton(context, 15, '15 мин'),
                _buildPresetButton(context, 30, '30 мин'),
                _buildPresetButton(context, 45, '45 мин'),
                _buildPresetButton(context, 60, '1 час'),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(BuildContext context, int minutes, String label) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onPressed: () {
        reader.startSleepTimer(minutes, onExpire: onTimerFinished);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌙 Таймер сна установлен на $label'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
