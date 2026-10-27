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
      subtitle: 'Мягкий шум дождя за окном',
      icon: Icons.water_drop_rounded,
      assetPath: 'assets/audio/ambient/rain.mp3',
    ),
    AmbientTrack(
      id: 'fireplace',
      title: 'Камин',
      subtitle: 'Потрескивание дров и тепло огня',
      icon: Icons.local_fire_department_rounded,
      assetPath: 'assets/audio/ambient/fireplace.mp3',
    ),
    AmbientTrack(
      id: 'forest',
      title: 'Ночной лес',
      subtitle: 'Шелест листвы и ночные сверчки',
      icon: Icons.forest_rounded,
      assetPath: 'assets/audio/ambient/forest.mp3',
    ),
    AmbientTrack(
      id: 'cafe',
      title: 'Кофейня',
      subtitle: 'Уютный фоновый гул и звон чашек',
      icon: Icons.coffee_rounded,
      assetPath: 'assets/audio/ambient/cafe.mp3',
    ),
  ];
}
