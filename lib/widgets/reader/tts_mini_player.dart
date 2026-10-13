import 'package:flutter/material.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';

class TtsMiniPlayer extends StatelessWidget {
  final int totalParagraphs;
  final VoidCallback onClose;

  const TtsMiniPlayer({
    super.key,
    required this.totalParagraphs,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tts = TtsService.instance;

    return ValueListenableBuilder<TtsPlaybackState>(
      valueListenable: tts.stateNotifier,
      builder: (context, state, _) {
        if (state == TtsPlaybackState.stopped) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF221F23) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF4A4247) : const Color(0xFFE2D7DA),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Headphone / Audio indicator icon
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  state == TtsPlaybackState.playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                  size: 18,
                  color: AppTheme.primaryPinkDark,
                ),
              ),
              const SizedBox(width: 10),

              // Paragraph counter & info
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: tts.currentParagraphNotifier,
                  builder: (context, currentIdx, _) {
                    final displayNum = currentIdx >= 0 ? currentIdx + 1 : 1;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state == TtsPlaybackState.playing ? 'Озвучка текста' : 'Пауза',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Абзац $displayNum из $totalParagraphs',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Speech Rate Cycle Button
              ValueListenableBuilder<double>(
                valueListenable: tts.rateNotifier,
                builder: (context, rate, _) {
                  return InkWell(
                    onTap: () => tts.cycleSpeechRate(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}x',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),

              // Previous Paragraph
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Предыдущий абзац',
                onPressed: () => tts.previousParagraph(),
              ),

              // Play / Pause Toggle Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryPinkDark,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    state == TtsPlaybackState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: state == TtsPlaybackState.playing ? 'Пауза' : 'Слушать',
                  onPressed: () {
                    if (state == TtsPlaybackState.playing) {
                      tts.pause();
                    } else {
                      tts.resume();
                    }
                  },
                ),
              ),

              // Next Paragraph
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Следующий абзац',
                onPressed: () => tts.nextParagraph(),
              ),

              // Close / Stop Player
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: 'Остановить озвучку',
                onPressed: () {
                  tts.stop();
                  onClose();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
