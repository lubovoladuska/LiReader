import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reader_theme_settings.dart';
import '../providers/reader_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/reader/reader_theme_settings_sheet.dart';

class WallpaperCustomizationScreen extends StatefulWidget {
  final ReaderProvider reader;

  const WallpaperCustomizationScreen({super.key, required this.reader});

  static Future<void> show(BuildContext context, ReaderProvider reader) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChangeNotifierProvider.value(
            value: reader,
            child: WallpaperCustomizationScreen(reader: reader),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<WallpaperCustomizationScreen> createState() => _WallpaperCustomizationScreenState();
}

class _WallpaperCustomizationScreenState extends State<WallpaperCustomizationScreen> {
  bool _showControls = true;

  Widget _buildWallpaperBackground(ReaderThemeSettings settings) {
    if (!settings.hasBackgroundImage) {
      return Container(color: settings.activeBackground);
    }

    final path = settings.backgroundImagePath!;
    final ImageProvider rawProvider = settings.isAssetBackground
        ? AssetImage(path)
        : FileImage(File(path)) as ImageProvider;

    final ImageProvider imageProvider = ResizeImage(
      rawProvider,
      width: 1440,
      policy: ResizeImagePolicy.fit,
    );

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
          sigmaX: settings.backgroundBlur,
          sigmaY: settings.backgroundBlur,
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

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final settings = reader.themeSettings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chapterTitle = reader.parsedData?.chapters.isNotEmpty == true
        ? reader.parsedData!.chapters[reader.currentChapterIndex.clamp(0, reader.parsedData!.chapters.length - 1)].title
        : reader.book.title;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-Screen Live Wallpaper Background
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: _buildWallpaperBackground(settings),
            ),
          ),

          // 2. Realistic Book Page Content Layer
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: settings.horizontalPadding,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 54),
                      Text(
                        chapterTitle,
                        textAlign: settings.textAlign,
                        style: TextStyle(
                          fontFamily: settings.fontFamily.fontFamily,
                          fontSize: settings.fontSize * 1.3,
                          fontWeight: FontWeight.bold,
                          letterSpacing: settings.letterSpacing,
                          color: AppTheme.primaryPinkDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Чтение — это путешествие в другие миры, не выходя из комнаты. Каждая страница открывает новые горизонты мысли и вдохновения.',
                        textAlign: settings.textAlign,
                        style: TextStyle(
                          fontFamily: settings.fontFamily.fontFamily,
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          letterSpacing: settings.letterSpacing,
                          color: settings.activeText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Настройте контраст, размытие и ориентацию обоев прямо сейчас, чтобы ваши глаза отдыхали во время чтения любимых книг.',
                        textAlign: settings.textAlign,
                        style: TextStyle(
                          fontFamily: settings.fontFamily.fontFamily,
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          letterSpacing: settings.letterSpacing,
                          color: settings.activeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Top Navigation & Action Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: _showControls ? Offset.zero : const Offset(0, -1),
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Настройка фона',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Живой предпросмотр книги',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryPinkDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. WhatsApp-style Bottom Floating Control Card
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: _showControls ? Offset.zero : const Offset(0, 1.3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1E1A1C) : Colors.white).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action Buttons (Pick Photo, Clear)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                label: const Text('Выбрать фото', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                onPressed: () => reader.pickCustomBackgroundImage(),
                              ),
                            ),
                            if (settings.hasBackgroundImage) ...[
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Убрать фон',
                                onPressed: () => reader.clearBackgroundImage(),
                              ),
                            ],
                          ],
                        ),

                        if (settings.hasBackgroundImage) ...[
                          const SizedBox(height: 10),
                          // Precise Angle Selector & Step Controls
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.rotate_90_degrees_cw_rounded, size: 18, color: AppTheme.primaryPinkDark),
                                const SizedBox(width: 8),
                                const Text('Поворот:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                for (final deg in [0, 90, 180, 270])
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('$deg°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      selected: settings.backgroundRotation == deg,
                                      selectedColor: AppTheme.primaryPinkDark.withValues(alpha: 0.25),
                                      onSelected: (_) => reader.setBackgroundRotation(deg),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.rotate_right_rounded, size: 18),
                                  tooltip: 'Повернуть +90°',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => reader.rotateBackground(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Textures horizontal selector
                        SizedBox(
                          height: 52,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildMiniTextureChip(
                                label: 'Без фона',
                                isSelected: !settings.hasBackgroundImage,
                                onTap: () => reader.clearBackgroundImage(),
                                child: Container(
                                  color: settings.activeBackground,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.texture_rounded,
                                    size: 16,
                                    color: !settings.hasBackgroundImage ? AppTheme.primaryPinkDark : Colors.grey,
                                  ),
                                ),
                              ),
                              ...ReaderThemeSettingsSheet.builtinTextures.map((tex) {
                                final isSelected = settings.hasBackgroundImage &&
                                    settings.isAssetBackground &&
                                    settings.backgroundImagePath == tex.path;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildMiniTextureChip(
                                    label: tex.label,
                                    isSelected: isSelected,
                                    onTap: () => reader.setBackgroundAsset(tex.path),
                                    child: Image.asset(tex.path, fit: BoxFit.cover),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Fit Mode Segmented Switcher
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

                        const SizedBox(height: 12),

                        // Live Dimming Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.brightness_medium_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Затемнение обоев', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPinkDark.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(settings.backgroundDimming * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryPinkDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: settings.backgroundDimming,
                            min: 0.0,
                            max: 0.90,
                            divisions: 18,
                            activeColor: AppTheme.primaryPinkDark,
                            onChanged: (val) => reader.setBackgroundDimming(val),
                          ),
                        ),

                        // Live Blur Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.blur_on_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Размытие (Блюр)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPinkDark.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${settings.backgroundBlur.toStringAsFixed(1)} px',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryPinkDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: settings.backgroundBlur,
                            min: 0.0,
                            max: 15.0,
                            divisions: 15,
                            activeColor: AppTheme.primaryPinkDark,
                            onChanged: (val) => reader.setBackgroundBlur(val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTextureChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPinkDark : Colors.black12,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
