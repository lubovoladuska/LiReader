import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/reader_provider.dart';
import '../../services/translation_service.dart';
import '../../theme/app_theme.dart';

class TranslationSheet extends StatefulWidget {
  final String text;
  final String? contextSnippet;
  final ReaderProvider reader;

  const TranslationSheet({
    super.key,
    required this.text,
    this.contextSnippet,
    required this.reader,
  });

  static Future<void> show(
    BuildContext context, {
    required String text,
    String? contextSnippet,
    required ReaderProvider reader,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TranslationSheet(
        text: text,
        contextSnippet: contextSnippet,
        reader: reader,
      ),
    );
  }

  @override
  State<TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<TranslationSheet> {
  final TranslationService _service = TranslationService.instance;

  bool _isLoading = true;
  String? _errorMessage;
  TranslationResult? _result;
  late String _sourceLang;
  late String _targetLang;
  bool _isSaved = false;
  bool _showContext = false;

  static const Map<String, String> _languages = {
    'ru': 'Русский',
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'ja': '日本語',
    'zh': '中文',
  };

  @override
  void initState() {
    super.initState();
    final clean = widget.text.trim();
    final isCyrillic = RegExp(r'[\u0400-\u04FF]').hasMatch(clean);
    _sourceLang = isCyrillic ? 'ru' : 'en';
    _targetLang = isCyrillic ? 'en' : 'ru';
    _isSaved = widget.reader.isWordInVocabulary(clean);
    _fetchTranslation();
  }

  Future<void> _fetchTranslation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _service.translate(
        widget.text,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось загрузить перевод. Проверьте интернет-соединение.';
          _isLoading = false;
        });
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
    });
    _fetchTranslation();
  }

  void _speak() {
    _service.speak(widget.text, lang: _sourceLang);
  }

  Future<void> _toggleSaveVocabulary() async {
    final cleanWord = widget.text.trim();
    if (_isSaved) {
      final existing = widget.reader.vocabulary.where((v) => v.word.toLowerCase() == cleanWord.toLowerCase()).toList();
      for (final item in existing) {
        await widget.reader.removeVocabularyWord(item.id);
      }
      setState(() => _isSaved = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Удалено из словаря'),
            duration: Duration(milliseconds: 900),
          ),
        );
      }
    } else {
      final translation = _result?.translatedText ?? '';
      await widget.reader.saveVocabularyWord(
        word: cleanWord,
        translation: translation,
        definition: _result?.definition,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        contextSnippet: widget.contextSnippet,
      );
      setState(() => _isSaved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранено в личный словарь ✨'),
            duration: Duration(milliseconds: 900),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1A1D) : Colors.white;
    final cardColor = isDark ? const Color(0xFF282327) : const Color(0xFFF7F4F5);
    final borderColor = isDark ? const Color(0xFF3D343B) : const Color(0xFFE8DFE2);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPinkDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      size: 20,
                      color: AppTheme.primaryPinkDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Перевод и словарь',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  // Language Pair Selector Pill
                  _buildLanguageSelectorPill(isDark),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Original Selected Text Box
                    _buildOriginalTextBox(cardColor, borderColor, isDark),

                    const SizedBox(height: 12),

                    // Context snippet if provided
                    if (widget.contextSnippet != null && widget.contextSnippet!.isNotEmpty)
                      _buildContextSnippetBox(cardColor, borderColor, isDark),

                    if (widget.contextSnippet != null && widget.contextSnippet!.isNotEmpty)
                      const SizedBox(height: 12),

                    // Translation Result Box
                    _buildTranslationResultBox(cardColor, borderColor, isDark),

                    // Dictionary / Wiktionary Definition (if available)
                    if (_result?.definition != null && _result!.definition!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDefinitionBox(cardColor, borderColor, isDark),
                    ],

                    // Alternative Translations / Synonyms
                    if (_result != null && _result!.alternativeTranslations.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildAlternativesBox(isDark),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelectorPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Язык оригинала',
            initialValue: _sourceLang,
            onSelected: (val) {
              setState(() => _sourceLang = val);
              _fetchTranslation();
            },
            itemBuilder: (ctx) => _languages.entries.map((e) {
              return PopupMenuItem(
                value: e.key,
                child: Text('${e.value} (${e.key.toUpperCase()})'),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                _sourceLang.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          InkWell(
            onTap: _swapLanguages,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Icon(Icons.swap_horiz_rounded, size: 16, color: AppTheme.primaryPinkDark),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Язык перевода',
            initialValue: _targetLang,
            onSelected: (val) {
              setState(() => _targetLang = val);
              _fetchTranslation();
            },
            itemBuilder: (ctx) => _languages.entries.map((e) {
              return PopupMenuItem(
                value: e.key,
                child: Text('${e.value} (${e.key.toUpperCase()})'),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                _targetLang.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPinkDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalTextBox(Color cardColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Оригинал (${_languages[_sourceLang] ?? _sourceLang})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              // Speak button
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Прослушать произношение',
                color: AppTheme.primaryPinkDark,
                onPressed: _speak,
              ),
              // Copy button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Копировать оригинал',
                color: isDark ? Colors.white60 : Colors.black54,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.text.trim()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Оригинал скопирован'), duration: Duration(milliseconds: 700)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            widget.text.trim(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextSnippetBox(Color cardColor, Color borderColor, bool isDark) {
    final snippet = widget.contextSnippet!.trim();
    return Container(
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _showContext = !_showContext),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.format_quote_rounded, size: 16, color: AppTheme.primaryPinkDark.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Text(
                    'Контекст из книги',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showContext ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (_showContext) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                snippet,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranslationResultBox(Color cardColor, Color borderColor, bool isDark) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryPinkDark),
            ),
            SizedBox(height: 12),
            Text(
              'Переводим...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1),
        ),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 28, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Повторить'),
              onPressed: _fetchTranslation,
            ),
          ],
        ),
      );
    }

    final translation = _result?.translatedText ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryPinkDark.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Перевод (${_languages[_targetLang] ?? _targetLang})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryPinkDark,
                ),
              ),
              const Spacer(),
              // Save to Vocabulary toggle button
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: _isSaved
                      ? AppTheme.primaryPinkDark
                      : AppTheme.primaryPinkDark.withValues(alpha: 0.15),
                  foregroundColor: _isSaved ? Colors.white : AppTheme.primaryPinkDark,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  _isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                  size: 16,
                ),
                label: Text(
                  _isSaved ? 'В словаре' : 'Сохранить',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _toggleSaveVocabulary,
              ),
              const SizedBox(width: 4),
              // Copy translation button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Копировать перевод',
                color: isDark ? Colors.white60 : Colors.black54,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: translation));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Перевод скопирован'), duration: Duration(milliseconds: 700)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            translation,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionBox(Color cardColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 15, color: AppTheme.primaryPinkDark),
              const SizedBox(width: 6),
              const Text(
                'Толковый словарь',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              if (_result?.partOfSpeech != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPinkDark.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _result!.partOfSpeech!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPinkDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            _result!.definition!,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesBox(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Другие значения и варианты:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _result!.alternativeTranslations.map((alt) {
            return ActionChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(alt, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: alt));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Скопировано: $alt'), duration: const Duration(milliseconds: 700)),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
