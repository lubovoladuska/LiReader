import 'package:flutter/material.dart';

class AmbientTrack {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String assetPath;

  const AmbientTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assetPath,
  });

  static const List<AmbientTrack> defaultTracks = [
    AmbientTrack(
      id: 'rain',
      title: 'Тихий дождь',
      subtitle: 'Шорох капель по стеклу',
      icon: Icons.water_drop_rounded,
      assetPath: 'assets/audio/ambient/rain.mp3',
    ),
    AmbientTrack(
      id: 'thunder',
      title: 'Гроза',
      subtitle: 'Раскаты грома и шум ливня',
      icon: Icons.thunderstorm_rounded,
      assetPath: 'assets/audio/ambient/thunder.mp3',
    ),
    AmbientTrack(
      id: 'fireplace',
      title: 'Камин',
      subtitle: 'Потрескивание тёплых дров',
      icon: Icons.local_fire_department_rounded,
      assetPath: 'assets/audio/ambient/fireplace.mp3',
    ),
    AmbientTrack(
      id: 'forest',
      title: 'Утренний лес',
      subtitle: 'Пение птиц и шелест крон',
      icon: Icons.forest_rounded,
      assetPath: 'assets/audio/ambient/forest.mp3',
    ),
    AmbientTrack(
      id: 'night',
      title: 'Ночные сверчки',
      subtitle: 'Стрекот цикад под луной',
      icon: Icons.nights_stay_rounded,
      assetPath: 'assets/audio/ambient/night.mp3',
    ),
    AmbientTrack(
      id: 'waves',
      title: 'Морской прибой',
      subtitle: 'Ритмичный накат волн',
      icon: Icons.waves_rounded,
      assetPath: 'assets/audio/ambient/waves.mp3',
    ),
    AmbientTrack(
      id: 'wind',
      title: 'Ветер и метель',
      subtitle: 'Завывание ветра за окном',
      icon: Icons.air_rounded,
      assetPath: 'assets/audio/ambient/wind.mp3',
    ),
    AmbientTrack(
      id: 'cafe',
      title: 'Кофейня',
      subtitle: 'Приглушённый гул и чашки',
      icon: Icons.coffee_rounded,
      assetPath: 'assets/audio/ambient/cafe.mp3',
    ),
    AmbientTrack(
      id: 'train',
      title: 'Поезд',
      subtitle: 'Мерный перестук колёс в пути',
      icon: Icons.train_rounded,
      assetPath: 'assets/audio/ambient/train.mp3',
    ),
    AmbientTrack(
      id: 'stream',
      title: 'Лесной ручей',
      subtitle: 'Журчание прозрачной воды',
      icon: Icons.water_rounded,
      assetPath: 'assets/audio/ambient/stream.mp3',
    ),
  ];
}

class AmbientPreset {
  final String id;
  final String title;
  final String emoji;
  final Map<String, double> trackVolumes;

  const AmbientPreset({
    required this.id,
    required this.title,
    required this.emoji,
    required this.trackVolumes,
  });

  static const List<AmbientPreset> defaultPresets = [
    AmbientPreset(
      id: 'rainy_fireplace',
      title: 'У камина в дождь',
      emoji: '🔥🌧️',
      trackVolumes: {'fireplace': 0.85, 'rain': 0.65},
    ),
    AmbientPreset(
      id: 'thunderstorm',
      title: 'Гроза за окном',
      emoji: '⚡🌧️',
      trackVolumes: {'thunder': 0.8, 'rain': 0.7, 'wind': 0.4},
    ),
    AmbientPreset(
      id: 'rainy_cafe',
      title: 'Кофейня в ливень',
      emoji: '☕🌧️',
      trackVolumes: {'cafe': 0.75, 'rain': 0.55},
    ),
    AmbientPreset(
      id: 'night_train',
      title: 'Ночной экспресс',
      emoji: '🚂🌙',
      trackVolumes: {'train': 0.8, 'wind': 0.35, 'rain': 0.3},
    ),
    AmbientPreset(
      id: 'ocean_breeze',
      title: 'Морской бриз',
      emoji: '🌊💨',
      trackVolumes: {'waves': 0.8, 'wind': 0.35},
    ),
    AmbientPreset(
      id: 'forest_creek',
      title: 'Лесной ручей',
      emoji: '🌲💧',
      trackVolumes: {'forest': 0.75, 'stream': 0.65},
    ),
    AmbientPreset(
      id: 'summer_night',
      title: 'Летняя ночь',
      emoji: '🌙🦗',
      trackVolumes: {'night': 0.8, 'wind': 0.25},
    ),
  ];
}
