import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/reader_theme_settings.dart';
import '../../providers/reader_provider.dart';
import '../../screens/wallpaper_customization_screen.dart';
import '../../theme/app_theme.dart';

class ReaderThemeSettingsSheet extends StatelessWidget {
  final ReaderProvider reader;

  const ReaderThemeSettingsSheet({super.key, required this.reader});

  static const List<({String path, String label})> builtinTextures = [
    (path: 'assets/backgrounds/parchment.jpg', label: 'Пергамент'),
    (path: 'assets/backgrounds/linen.jpg', label: 'Лён'),
    (path: 'assets/backgrounds/graphite_canvas.jpg', label: 'Холст'),
    (path: 'assets/backgrounds/marble_mist.jpg', label: 'Дымка'),
    (path: 'assets/backgrounds/night_stars.jpg', label: 'Звёзды'),
  ];

  static const List<Color> customBgOptions = [
    Color(0xFFFAF8F7), // Pure Light
    Color(0xFFF7F1E5), // Warm Sepia
    Color(0xFFF0EBE1), // Antique Paper
    Color(0xFFE8EEF5), // Soft Blue
    Color(0xFFEFF5F0), // Mint Calming
    Color(0xFFF5F0F8), // Lavender
    Color(0xFF332D30), // Dark Rose/Grey
    Color(0xFF242023), // Soft Graphite
    Color(0xFF191617), // Deep Dark
    Color(0xFF0F0E0F), // True Black OLED
  ];

  static const List<Color> customTextOptions = [
    Color(0xFF191617), // Deep Black
    Color(0xFF2C2527), // Charcoal
    Color(0xFF3E332A), // Warm Brown
    Color(0xFF20322B), // Forest Dark
    Color(0xFF262C38), // Navy Dark
    Color(0xFFD6C8C3), // Soft Beige
    Color(0xFFE5DEE1), // Warm Light
    Color(0xFFFAF8F7), // Pure White
    Color(0xFFF2A7B5), // Pastel Pink
    Color(0xFFFDC8B7), // Peach Soft
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: reader,
      builder: (context, _) {
        final settings = reader.themeSettings;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppTheme.primaryPinkDark, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Оформление для чтения',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live Real-Time Typography & Theme Preview Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildPreviewBackground(settings),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: (settings.horizontalPadding * 0.6).clamp(12.0, 32.0),
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF443D41) : const Color(0xFFE2D9DC),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Живой предпросмотр',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: settings.activeText.withValues(alpha: 0.7),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPinkDark.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    settings.hasBackgroundImage
                                        ? (settings.isAssetBackground ? 'Текстура' : 'Своё фото')
                                        : (settings.isCustomColors ? 'Своя палитра' : settings.colorPreset.label),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryPinkDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '«Книга — это мечта, которую вы держите в руках.»',
                              textAlign: settings.textAlign,
                              style: TextStyle(
                                fontFamily: settings.fontFamily.fontFamily,
                                fontSize: settings.fontSize * 0.95,
                                height: settings.lineHeight,
                                letterSpacing: settings.letterSpacing,
                                color: settings.activeText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 1. Color Presets
              const Text('ЦВЕТОВЫЕ ТЕМЫ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReaderColorPreset.values.map((preset) {
                  final isSelected = !settings.isCustomColors && settings.colorPreset == preset;
                  return InkWell(
                    onTap: () => reader.setColorPreset(preset),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: preset.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryPinkDark : Colors.black12,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryPinkDark.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        preset.label,
                        style: TextStyle(
                          color: preset.textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),


              const SizedBox(height: 20),
              // Custom Color Pickers
              Row(
                children: [
                  const Text('Пользовательский цвет фона:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (settings.isCustomColors)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Сбросить к пресету', style: TextStyle(fontSize: 12)),
                      onPressed: () => reader.setColorPreset(settings.colorPreset),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: customBgOptions.map((color) {
                  final isSelected = settings.isCustomColors && settings.activeBackground.toARGB32() == color.toARGB32();
                  return InkWell(
                    onTap: () => reader.setCustomColors(background: color),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryPinkDark : Colors.black26,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),
              const Text('Пользовательский цвет текста:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: customTextOptions.map((color) {
                  final isSelected = settings.isCustomColors && settings.activeText.toARGB32() == color.toARGB32();
                  return InkWell(
                    onTap: () => reader.setCustomColors(text: color),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryPinkDark : Colors.black26,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),


              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // Background Texture & Custom Image Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ФОН И ТЕКСТУРА СТРАНИЦЫ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.grey,
                    ),
                  ),
                  if (settings.hasBackgroundImage)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.primaryPinkDark,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Сбросить фон', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => reader.clearBackgroundImage(),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Full-screen WhatsApp-style editor banner button
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  WallpaperCustomizationScreen.show(context, reader);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryPink.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wallpaper_rounded, size: 18, color: AppTheme.primaryPinkDark),
                      SizedBox(width: 8),
                      Text(
                        'Настроить фон на весь экран',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPinkDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Horizontal Texture Selector
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 1. None (Solid Color)
                    _buildTextureCard(
                      label: 'Без фона',
                      isSelected: !settings.hasBackgroundImage,
                      onTap: () => reader.clearBackgroundImage(),
                      child: Container(
                        color: settings.activeBackground,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.texture_rounded,
                          size: 24,
                          color: settings.hasBackgroundImage ? Colors.grey : AppTheme.primaryPinkDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Builtin textures
                    ...builtinTextures.map((tex) {
                      final isSelected = settings.hasBackgroundImage &&
                          settings.isAssetBackground &&
                          settings.backgroundImagePath == tex.path;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildTextureCard(
                          label: tex.label,
                          isSelected: isSelected,
                          onTap: () => reader.setBackgroundAsset(tex.path),
                          child: Image.asset(
                            tex.path,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      );
                    }),

                    // 3. Custom Image Picker
                    _buildTextureCard(
                      label: settings.hasBackgroundImage && !settings.isAssetBackground ? 'Своё фото' : '+ Своё фото',
                      isSelected: settings.hasBackgroundImage && !settings.isAssetBackground,
                      onTap: () async {
                        final success = await reader.pickCustomBackgroundImage();
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          WallpaperCustomizationScreen.show(context, reader);
                        }
                      },
                      child: Container(
                        color: AppTheme.primaryPink.withValues(alpha: 0.1),
                        alignment: Alignment.center,
                        child: settings.hasBackgroundImage && !settings.isAssetBackground
                            ? Image.file(
                                File(settings.backgroundImagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: AppTheme.primaryPinkDark,
                                size: 26,
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Background image adjustments
              if (settings.hasBackgroundImage) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.025),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF3B3438) : const Color(0xFFE8E0E3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fit Mode & Rotate 90
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Подгонка изображения:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.rotate_right_rounded, size: 16),
                            label: Text(
                              'Повернуть 90° (${settings.backgroundRotation}°)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => reader.rotateBackground(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ReaderBackgroundFit>(
                          segments: ReaderBackgroundFit.values.map((fit) {
                            return ButtonSegment(
                              value: fit,
                              label: Text(fit.label, style: const TextStyle(fontSize: 11)),
                            );
                          }).toList(),
                          selected: {settings.backgroundFit},
                          onSelectionChanged: (set) => reader.setBackgroundFit(set.first),
                        ),
                      ),

                      const SizedBox(height: 14),
                      // Dimming slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Затемнение фона',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${(settings.backgroundDimming * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.backgroundDimming,
                        min: 0.0,
                        max: 0.90,
                        divisions: 18,
                        activeColor: AppTheme.primaryPinkDark,
                        onChanged: (val) => reader.setBackgroundDimming(val),
                      ),

                      // Blur slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Размытие фона (Блюр)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${settings.backgroundBlur.toStringAsFixed(1)} px',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.backgroundBlur,
                        min: 0.0,
                        max: 15.0,
                        divisions: 15,
                        activeColor: AppTheme.primaryPinkDark,
                        onChanged: (val) => reader.setBackgroundBlur(val),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // 2. Font Family
              const Text('ШРИФТОВАЯ ГАРНИТУРА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey)),
              const SizedBox(height: 10),
              SegmentedButton<ReaderFontFamily>(
                segments: ReaderFontFamily.values.map((f) {
                  return ButtonSegment(
                    value: f,
                    label: Text(f.label, style: TextStyle(fontFamily: f.fontFamily, fontSize: 13)),
                  );
                }).toList(),
                selected: {settings.fontFamily},
                onSelectionChanged: (set) => reader.setFontFamily(set.first),
              ),

              const SizedBox(height: 20),
              // 3. Font Size Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Размер текста', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${settings.fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark)),
                ],
              ),
              Slider(
                value: settings.fontSize,
                min: 12.0,
                max: 34.0,
                divisions: 22,
                activeColor: AppTheme.primaryPinkDark,
                onChanged: (val) => reader.setFontSize(val),
              ),

              // 4. Line Height Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Межстрочный интервал', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(settings.lineHeight.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark)),
                ],
              ),
              Slider(
                value: settings.lineHeight,
                min: 1.2,
                max: 2.6,
                divisions: 14,
                activeColor: AppTheme.primaryPinkDark,
                onChanged: (val) => reader.setLineHeight(val),
              ),

              // 5. Letter Spacing Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Межбуквенный интервал', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${settings.letterSpacing.toStringAsFixed(1)} px', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark)),
                ],
              ),
              Slider(
                value: settings.letterSpacing,
                min: -0.5,
                max: 3.0,
                divisions: 14,
                activeColor: AppTheme.primaryPinkDark,
                onChanged: (val) => reader.setLetterSpacing(val),
              ),

              // 6. Horizontal Margin / Padding Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Поля страницы (отступы)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${settings.horizontalPadding.toInt()} px', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark)),
                ],
              ),
              Slider(
                value: settings.horizontalPadding,
                min: 12.0,
                max: 72.0,
                divisions: 15,
                activeColor: AppTheme.primaryPinkDark,
                onChanged: (val) => reader.setHorizontalPadding(val),
              ),

              // 7. Text Alignment
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Выравнивание текста', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.format_align_left_rounded),
                        color: settings.textAlign == TextAlign.left ? AppTheme.primaryPinkDark : Colors.grey,
                        onPressed: () => reader.setTextAlign(TextAlign.left),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_align_justify_rounded),
                        color: settings.textAlign == TextAlign.justify ? AppTheme.primaryPinkDark : Colors.grey,
                        onPressed: () => reader.setTextAlign(TextAlign.justify),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_align_center_rounded),
                        color: settings.textAlign == TextAlign.center ? AppTheme.primaryPinkDark : Colors.grey,
                        onPressed: () => reader.setTextAlign(TextAlign.center),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildPreviewBackground(ReaderThemeSettings settings) {
    if (!settings.hasBackgroundImage) {
      return Container(color: settings.activeBackground);
    }

    final path = settings.backgroundImagePath!;
    final ImageProvider imageProvider = settings.isAssetBackground
        ? AssetImage(path)
        : FileImage(File(path)) as ImageProvider;

    BoxFit fit = BoxFit.cover;
    ImageRepeat repeat = ImageRepeat.noRepeat;

    switch (settings.backgroundFit) {
      case ReaderBackgroundFit.cover:
        fit = BoxFit.cover;
        repeat = ImageRepeat.noRepeat;
        break;
      case ReaderBackgroundFit.contain:
        fit = BoxFit.contain;
        repeat = ImageRepeat.noRepeat;
        break;
      case ReaderBackgroundFit.tile:
        fit = BoxFit.none;
        repeat = ImageRepeat.repeat;
        break;
      case ReaderBackgroundFit.fill:
        fit = BoxFit.fill;
        repeat = ImageRepeat.noRepeat;
        break;
    }

    Widget imageWidget = Image(
      image: imageProvider,
      fit: fit,
      repeat: repeat,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) => Container(color: settings.activeBackground),
    );

    if (settings.backgroundRotation != 0) {
      final quarterTurns = (settings.backgroundRotation ~/ 90) % 4;
      imageWidget = RotatedBox(
        quarterTurns: quarterTurns,
        child: imageWidget,
      );
    }

    if (settings.backgroundBlur > 0) {
      imageWidget = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: settings.backgroundBlur * 0.4,
          sigmaY: settings.backgroundBlur * 0.4,
        ),
        child: imageWidget,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: settings.activeBackground),
        imageWidget,
        if (settings.backgroundDimming > 0)
          Container(
            color: Colors.black.withValues(alpha: settings.backgroundDimming),
          ),
      ],
    );
  }

  Widget _buildTextureCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPinkDark : Colors.black12,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPinkDark.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: SizedBox(
                  width: double.infinity,
                  child: child,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryPinkDark : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

