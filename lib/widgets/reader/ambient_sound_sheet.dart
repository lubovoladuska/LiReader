import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ambient_track.dart';
import '../../services/ambient_sound_service.dart';
import '../../theme/app_theme.dart';

class AmbientSoundSheet extends StatelessWidget {
  const AmbientSoundSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AmbientSoundSheet(),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1B1E) : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;
    final subText = textCol.withValues(alpha: 0.6);
    final service = AmbientSoundService.instance;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    color: subText.withValues(alpha: 0.25),
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
                      Icons.graphic_eq_rounded,
                      size: 22,
                      color: AppTheme.primaryPinkDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Звуки уюта (Эмбиент)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        Text(
                          'Фоновая атмосфера для чтения',
                          style: TextStyle(
                            fontSize: 11,
                            color: subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: subText),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Track Grid
              Text(
                'Выберите атмосферу:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 10),

              ValueListenableBuilder<AmbientTrack?>(
                valueListenable: service.currentTrackNotifier,
                builder: (context, currentTrack, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: service.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: AmbientTrack.defaultTracks.length,
                        itemBuilder: (context, index) {
                          final track = AmbientTrack.defaultTracks[index];
                          final isCurrent = currentTrack?.id == track.id;
                          final isTrackActive = isCurrent && isPlaying;

                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              service.playTrack(track);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isTrackActive
                                    ? AppTheme.primaryPinkDark.withValues(alpha: 0.16)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isTrackActive
                                      ? AppTheme.primaryPinkDark
                                      : (isCurrent
                                          ? AppTheme.primaryPinkDark.withValues(alpha: 0.4)
                                          : textCol.withValues(alpha: 0.1)),
                                  width: isTrackActive ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    track.icon,
                                    size: 22,
                                    color: isTrackActive ? AppTheme.primaryPinkDark : subText,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isTrackActive ? FontWeight.bold : FontWeight.w500,
                                            color: isTrackActive ? AppTheme.primaryPinkDark : textCol,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          isTrackActive ? 'Играет...' : 'Нажмите для запуска',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isTrackActive ? AppTheme.primaryPinkDark.withValues(alpha: 0.8) : subText,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isTrackActive)
                                    const Icon(
                                      Icons.pause_circle_filled_rounded,
                                      size: 18,
                                      color: AppTheme.primaryPinkDark,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              // Volume Slider
              ValueListenableBuilder<double>(
                valueListenable: service.volumeNotifier,
                builder: (context, volume, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                volume == 0
                                    ? Icons.volume_off_rounded
                                    : (volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                                size: 18,
                                color: subText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Громкость фона:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textCol,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(volume * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPinkDark,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.primaryPinkDark,
                          thumbColor: AppTheme.primaryPinkDark,
                          inactiveTrackColor: textCol.withValues(alpha: 0.12),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) => service.setVolume(val),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Sleep Timer Presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bedtime_outlined, size: 17, color: subText),
                      const SizedBox(width: 8),
                      Text(
                        'Таймер сна:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textCol,
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: service.sleepTimerSecondsNotifier,
                    builder: (context, seconds, _) {
                      if (seconds <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Завершение через ${_formatTime(seconds)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ValueListenableBuilder<int>(
                valueListenable: service.sleepTimerSecondsNotifier,
                builder: (context, seconds, _) {
                  final activeMinutes = (seconds / 60).round();
                  final presets = [0, 15, 30, 45, 60];

                  return Wrap(
                    spacing: 8,
                    children: presets.map((mins) {
                      final isSelected = mins == 0 ? seconds == 0 : activeMinutes == mins;
                      final label = mins == 0 ? 'Выкл' : '$mins мин';

                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryPinkDark : textCol,
                        ),
                        selectedColor: AppTheme.primaryPinkDark.withValues(alpha: 0.18),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          service.setSleepTimer(mins);
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
