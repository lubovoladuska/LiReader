import 'package:flutter/material.dart';

enum ReaderFontFamily {
  sansSerif('Без засечек (Sans)', 'Segoe UI'),
  serif('С засечками (Serif)', 'Georgia'),
  monospace('Код / Моноширинный', 'Consolas');

  final String label;
  final String fontFamily;
  const ReaderFontFamily(this.label, this.fontFamily);
}

enum ReaderColorPreset {
  paper('Тёплая бумага (Sepia)', Color(0xFFF7F1E5), Color(0xFF2E2620)),
  white('Светлый (Дневной)', Color(0xFFFAF8F7), Color(0xFF221E20)),
  graphite('Графит (Мягкий тёмный)', Color(0xFF242023), Color(0xFFEDE6E8)),
  night('Глубокий чёрный (OLED)', Color(0xFF0F0E0F), Color(0xFFE5DEE1)),
  mint('Мятный релакс', Color(0xFFEFF5F0), Color(0xFF1E2B21)),
  lavender('Пастельная лаванда', Color(0xFFF5F0F8), Color(0xFF2B2032));

  final String label;
  final Color backgroundColor;
  final Color textColor;
  const ReaderColorPreset(this.label, this.backgroundColor, this.textColor);
}

class ReaderThemeSettings {
  final ReaderFontFamily fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final TextAlign textAlign;
  final double horizontalPadding;
  final ReaderColorPreset colorPreset;
  final Color customBackgroundColor;
  final Color customTextColor;
  final bool isCustomColors;

  const ReaderThemeSettings({
    this.fontFamily = ReaderFontFamily.serif,
    this.fontSize = 18.0,
    this.lineHeight = 1.65,
    this.letterSpacing = 0.2,
    this.paragraphSpacing = 16.0,
    this.textAlign = TextAlign.left,
    this.horizontalPadding = 32.0,
    this.colorPreset = ReaderColorPreset.paper,
    this.customBackgroundColor = const Color(0xFFF7F1E5),
    this.customTextColor = const Color(0xFF2E2620),
    this.isCustomColors = false,
  });

  Color get activeBackground => isCustomColors ? customBackgroundColor : colorPreset.backgroundColor;
  Color get activeText => isCustomColors ? customTextColor : colorPreset.textColor;

  Map<String, dynamic> toMap() {
    return {
      'fontFamily': fontFamily.name,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'paragraphSpacing': paragraphSpacing,
      'textAlign': textAlign.name,
      'horizontalPadding': horizontalPadding,
      'colorPreset': colorPreset.name,
      'customBackgroundColor': customBackgroundColor.toARGB32(),
      'customTextColor': customTextColor.toARGB32(),
      'isCustomColors': isCustomColors ? 1 : 0,
    };
  }

  factory ReaderThemeSettings.fromMap(Map<String, dynamic> map) {
    return ReaderThemeSettings(
      fontFamily: ReaderFontFamily.values.firstWhere(
        (e) => e.name == map['fontFamily'],
        orElse: () => ReaderFontFamily.serif,
      ),
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.65,
      letterSpacing: (map['letterSpacing'] as num?)?.toDouble() ?? 0.2,
      paragraphSpacing: (map['paragraphSpacing'] as num?)?.toDouble() ?? 16.0,
      textAlign: TextAlign.values.firstWhere(
        (e) => e.name == map['textAlign'],
        orElse: () => TextAlign.left,
      ),
      horizontalPadding: (map['horizontalPadding'] as num?)?.toDouble() ?? 32.0,
      colorPreset: ReaderColorPreset.values.firstWhere(
        (e) => e.name == map['colorPreset'],
        orElse: () => ReaderColorPreset.paper,
      ),
      customBackgroundColor: map['customBackgroundColor'] != null
          ? Color(map['customBackgroundColor'])
          : const Color(0xFFF7F1E5),
      customTextColor: map['customTextColor'] != null
          ? Color(map['customTextColor'])
          : const Color(0xFF2E2620),
      isCustomColors: map['isCustomColors'] == 1,
    );
  }

  ReaderThemeSettings copyWith({
    ReaderFontFamily? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    TextAlign? textAlign,
    double? horizontalPadding,
    ReaderColorPreset? colorPreset,
    Color? customBackgroundColor,
    Color? customTextColor,
    bool? isCustomColors,
  }) {
    return ReaderThemeSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      textAlign: textAlign ?? this.textAlign,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      colorPreset: colorPreset ?? this.colorPreset,
      customBackgroundColor: customBackgroundColor ?? this.customBackgroundColor,
      customTextColor: customTextColor ?? this.customTextColor,
      isCustomColors: isCustomColors ?? this.isCustomColors,
    );
  }
}
