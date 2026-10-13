import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reader_theme_settings.dart';
import '../../theme/app_theme.dart';
import '../common/app_logo.dart';

enum QuoteCardStyle {
  darkMinimal,
  vintagePaper,
  readerWallpaper,
  twilightGradient,
}

enum QuoteCardRatio {
  square, // 1:1 for posts (VK, Telegram, Instagram)
  story,  // 9:16 for Stories & status
}

class QuoteCardDialog extends StatefulWidget {
  final String quoteText;
  final String bookTitle;
  final String author;
  final ReaderThemeSettings themeSettings;

  const QuoteCardDialog({
    super.key,
    required this.quoteText,
    required this.bookTitle,
    required this.author,
    required this.themeSettings,
  });

  static Future<void> show(
    BuildContext context, {
    required String quoteText,
    required String bookTitle,
    required String author,
    required ReaderThemeSettings themeSettings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuoteCardDialog(
        quoteText: quoteText,
        bookTitle: bookTitle,
        author: author,
        themeSettings: themeSettings,
      ),
    );
  }

  @override
  State<QuoteCardDialog> createState() => _QuoteCardDialogState();
}

class _QuoteCardDialogState extends State<QuoteCardDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  QuoteCardStyle _selectedStyle = QuoteCardStyle.darkMinimal;
  QuoteCardRatio _selectedRatio = QuoteCardRatio.square;
  bool _isSharing = false;

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Не удалось захватить изображение карточки');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Ошибка конвертации изображения');

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, 'lireader_quote_${DateTime.now().millisecondsSinceEpoch}.png');
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      final shareText = '«${widget.quoteText}»\n— ${widget.bookTitle} (${widget.author})\n\nЧитаю в LiReader';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: 'Цитата из книги «${widget.bookTitle}»',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1B1D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.format_quote_rounded, color: AppTheme.primaryPinkDark, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Карточка цитаты',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Controls row: Ratio & Style
              Row(
                children: [
                  // Ratio toggles
                  SegmentedButton<QuoteCardRatio>(
                    segments: const [
                      ButtonSegment(value: QuoteCardRatio.square, label: Text('1:1')),
                      ButtonSegment(value: QuoteCardRatio.story, label: Text('9:16')),
                    ],
                    selected: {_selectedRatio},
                    onSelectionChanged: (val) {
                      setState(() => _selectedRatio = val.first);
                    },
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const Spacer(),
                  // Style Chips
                  PopupMenuButton<QuoteCardStyle>(
                    initialValue: _selectedStyle,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tooltip: 'Выбрать стиль',
                    onSelected: (style) => setState(() => _selectedStyle = style),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStyleIcon(_selectedStyle), size: 16, color: AppTheme.primaryPinkDark),
                          const SizedBox(width: 6),
                          Text(
                            _getStyleName(_selectedStyle),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: QuoteCardStyle.darkMinimal,
                        child: Text('🖤 Тёмный минимал'),
                      ),
                      const PopupMenuItem(
                        value: QuoteCardStyle.vintagePaper,
                        child: Text('📜 Книжная бумага'),
                      ),
                      const PopupMenuItem(
                        value: QuoteCardStyle.readerWallpaper,
                        child: Text('🖼 Обои читалки'),
                      ),
                      const PopupMenuItem(
                        value: QuoteCardStyle.twilightGradient,
                        child: Text('🌅 Ночной градиент'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Card Preview Area
              Flexible(
                child: SingleChildScrollView(
                  child: Center(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: _buildCardContent(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Share CTA button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryPinkDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share_rounded, size: 20),
                  label: Text(
                    _isSharing ? 'Подготовка...' : 'Поделиться цитатой',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSharing ? null : _shareCard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStyleIcon(QuoteCardStyle style) {
    switch (style) {
      case QuoteCardStyle.darkMinimal:
        return Icons.dark_mode_rounded;
      case QuoteCardStyle.vintagePaper:
        return Icons.menu_book_rounded;
      case QuoteCardStyle.readerWallpaper:
        return Icons.wallpaper_rounded;
      case QuoteCardStyle.twilightGradient:
        return Icons.gradient_rounded;
    }
  }

  String _getStyleName(QuoteCardStyle style) {
    switch (style) {
      case QuoteCardStyle.darkMinimal:
        return 'Тёмный';
      case QuoteCardStyle.vintagePaper:
        return 'Бумага';
      case QuoteCardStyle.readerWallpaper:
        return 'Обои';
      case QuoteCardStyle.twilightGradient:
        return 'Градиент';
    }
  }

  Widget _buildCardContent() {
    final isSquare = _selectedRatio == QuoteCardRatio.square;
    final cardWidth = isSquare ? 320.0 : 270.0;
    final cardHeight = isSquare ? 320.0 : 480.0;

    // Palette per style
    Color textColor;
    Color subTextColor;
    Color quoteMarkColor;
    Decoration decoration;

    switch (_selectedStyle) {
      case QuoteCardStyle.vintagePaper:
        textColor = const Color(0xFF231B15);
        subTextColor = const Color(0xFF6B5848);
        quoteMarkColor = const Color(0xFFC49A6C);
        decoration = BoxDecoration(
          color: const Color(0xFFFBF6EB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DAC7), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        );
        break;

      case QuoteCardStyle.readerWallpaper:
        textColor = Colors.white;
        subTextColor = Colors.white70;
        quoteMarkColor = AppTheme.primaryPink;
        decoration = BoxDecoration(
          color: const Color(0xFF141214),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        );
        break;

      case QuoteCardStyle.twilightGradient:
        textColor = Colors.white;
        subTextColor = const Color(0xFFD4C2F0);
        quoteMarkColor = const Color(0xFFFF8DA1);
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C1635), Color(0xFF151833)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        );
        break;

      case QuoteCardStyle.darkMinimal:
        textColor = const Color(0xFFF0EDF0);
        subTextColor = const Color(0xFFA59EA4);
        quoteMarkColor = AppTheme.primaryPink;
        decoration = BoxDecoration(
          color: const Color(0xFF161517),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF332F34), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        );
        break;
    }

    Widget contentInner = Container(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isSquare ? 22 : 32),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large Quote Mark
          Text(
            '“',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: isSquare ? 42 : 48,
              height: 0.8,
              fontWeight: FontWeight.w900,
              color: quoteMarkColor,
            ),
          ),
          const SizedBox(height: 6),

          // Quote Text
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  widget.quoteText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: widget.quoteText.length > 250 ? 12.5 : (widget.quoteText.length > 120 ? 14.5 : 16.5),
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Divider
          Container(
            width: 40,
            height: 1.5,
            decoration: BoxDecoration(
              color: quoteMarkColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Book Title
          Text(
            widget.bookTitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),

          // Author
          Text(
            widget.author,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 12),

          // Watermark badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 14, borderRadius: 3),
              const SizedBox(width: 5),
              Text(
                'LiReader',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: quoteMarkColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // If reader wallpaper style is selected and user has a wallpaper image, show it under dark blur
    if (_selectedStyle == QuoteCardStyle.readerWallpaper &&
        widget.themeSettings.hasBackgroundImage &&
        widget.themeSettings.backgroundImagePath != null) {
      final imgPath = widget.themeSettings.backgroundImagePath!;
      final imageProvider = widget.themeSettings.isAssetBackground
          ? AssetImage(imgPath) as ImageProvider
          : FileImage(File(imgPath));

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
            contentInner,
          ],
        ),
      );
    }

    return contentInner;
  }
}
