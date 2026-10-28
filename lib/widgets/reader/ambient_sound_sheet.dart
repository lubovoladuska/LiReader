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
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
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
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: subText.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header & Master Controls
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
                          'Звуки уюта (Эмбиент-микшер)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        Text(
                          'Смешивайте атмосферу природы для чтения',
                          style: TextStyle(
                            fontSize: 11,
                            color: subText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reset all button (visible when tracks active)
                  ValueListenableBuilder<int>(
                    valueListenable: service.activeCountNotifier,
                    builder: (context, activeCount, _) {
                      if (activeCount == 0) return const SizedBox.shrink();
                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.grey),
                        label: const Text(
                          'Сброс',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          service.stopAll();
                        },
                      );
                    },
                  ),

                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: subText),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Master Play/Pause & Overall Volume
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Master Play/Pause FAB
                        ValueListenableBuilder<bool>(
                          valueListenable: service.isPlayingNotifier,
                          builder: (context, isPlaying, _) {
                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                service.togglePlay();
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPinkDark,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryPinkDark.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),

                        // Master Volume Slider
                        Expanded(
                          child: ValueListenableBuilder<double>(
                            valueListenable: service.masterVolumeNotifier,
                            builder: (context, masterVol, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Общая громкость:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textCol,
                                        ),
                                      ),
                                      Text(
                                        '${(masterVol * 100).round()}%',
                                        style: const TextStyle(
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
                                      thumbShape:
                                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    ),
                                    child: Slider(
                                      value: masterVol,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) => service.setMasterVolume(val),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Atmospheric Presets Bar
              Text(
                'Готовые сочетания (Пресеты):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: AmbientPreset.defaultPresets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = AmbientPreset.defaultPresets[index];
                    return ActionChip(
                      avatar: Text(preset.emoji, style: const TextStyle(fontSize: 13)),
                      label: Text(preset.title),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textCol,
                      ),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        service.applyPreset(preset);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Individual Sound Layers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Звуковые дорожки (Микшер):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: service.activeCountNotifier,
                    builder: (context, count, _) {
                      if (count == 0) return const SizedBox.shrink();
                      return Text(
                        'Активно: $count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPinkDark,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 10 Sound Cards with individual volume sliders
              ValueListenableBuilder<Map<String, double>>(
                valueListenable: service.activeVolumesNotifier,
                builder: (context, volumes, _) {
                  return Column(
                    children: AmbientTrack.defaultTracks.map((track) {
                      final vol = volumes[track.id] ?? 0.0;
                      final isActive = vol > 0.0;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryPinkDark.withValues(alpha: 0.12)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.primaryPinkDark
                                : (isDark ? Colors.white10 : Colors.black12),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Track Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.primaryPinkDark.withValues(alpha: 0.2)
                                        : (isDark ? Colors.white10 : Colors.black12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    track.icon,
                                    size: 20,
                                    color: isActive ? AppTheme.primaryPinkDark : subText,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Title & Subtitle
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      service.toggleTrack(track.id);
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight:
                                                isActive ? FontWeight.bold : FontWeight.w500,
                                            color: isActive ? AppTheme.primaryPinkDark : textCol,
                                          ),
                                        ),
                                        Text(
                                          track.subtitle,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: subText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Toggle Switch
                                Switch(
                                  value: isActive,
                                  activeThumbColor: AppTheme.primaryPinkDark,
                                  onChanged: (enabled) {
                                    HapticFeedback.selectionClick();
                                    service.toggleTrack(track.id);
                                  },
                                ),
                              ],
                            ),

                            // Volume slider if track is active
                            if (isActive) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.volume_down_rounded,
                                    size: 14,
                                    color: subText,
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: AppTheme.primaryPinkDark,
                                        thumbColor: AppTheme.primaryPinkDark,
                                        inactiveTrackColor: textCol.withValues(alpha: 0.12),
                                        trackHeight: 2.5,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 5),
                                      ),
                                      child: Slider(
                                        value: vol,
                                        min: 0.0,
                                        max: 1.0,
                                        onChanged: (newVol) {
                                          service.setTrackVolume(track.id, newVol);
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${(vol * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryPinkDark,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
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
