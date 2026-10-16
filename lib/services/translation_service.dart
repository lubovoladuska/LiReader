import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'tts_service.dart';

class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final List<String> alternativeTranslations;
  final String? partOfSpeech;
  final String? definition;
  final List<String> examples;

  TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    this.alternativeTranslations = const [],
    this.partOfSpeech,
    this.definition,
    this.examples = const [],
  });
}

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'LiReader/1.2 (https://github.com/lubovoladuska/LiReader; contact@lireader.app)',
        'Accept': 'application/json',
      },
    ),
  );

  final Map<String, TranslationResult> _cache = {};

  /// Translates text with automatic language detection or explicit language pair
  Future<TranslationResult> translate(
    String rawText, {
    String? sourceLang,
    String? targetLang,
  }) async {
    final cleanText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) {
      return TranslationResult(
        originalText: '',
        translatedText: '',
        sourceLang: sourceLang ?? 'en',
        targetLang: targetLang ?? 'ru',
      );
    }

    final isCyrillic = RegExp(r'[\u0400-\u04FF]').hasMatch(cleanText);

    final resolvedSource = (sourceLang != null && sourceLang != 'auto')
        ? sourceLang.toLowerCase()
        : (isCyrillic ? 'ru' : 'en');

    final resolvedTarget = (targetLang != null && targetLang != 'auto')
        ? targetLang.toLowerCase()
        : (resolvedSource == 'ru' ? 'en' : 'ru');

    final cacheKey = '${resolvedSource}_${resolvedTarget}_${cleanText.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    String translatedText = '';
    final alternativeTranslations = <String>{};

    try {
      final url = 'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(cleanText)}&langpair=$resolvedSource|$resolvedTarget';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final resData = data['responseData'];
        if (resData is Map && resData['translatedText'] != null) {
          translatedText = _unescapeHtml(resData['translatedText'].toString().trim());
        }

        final matches = data['matches'];
        if (matches is List) {
          for (final m in matches) {
            if (m is Map && m['translation'] != null) {
              final tr = _unescapeHtml(m['translation'].toString().trim());
              if (tr.isNotEmpty &&
                  tr.toLowerCase() != cleanText.toLowerCase() &&
                  tr.toLowerCase() != translatedText.toLowerCase()) {
                alternativeTranslations.add(tr);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('MyMemory translation error: $e');
    }

    if (translatedText.isEmpty) {
      translatedText = cleanText;
    }

    // Attempt dictionary definition if it's a single word or short phrase
    String? partOfSpeech;
    String? definition;
    final words = cleanText.split(' ');

    if (words.length <= 2) {
      final cleanWord = cleanText.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
      if (cleanWord.isNotEmpty) {
        if (resolvedSource == 'en') {
          final dict = await _fetchEnglishDefinition(cleanWord);
          if (dict != null) {
            partOfSpeech = dict['partOfSpeech'];
            definition = dict['definition'];
          }
        } else if (resolvedSource == 'ru') {
          final dict = await _fetchRussianDefinition(cleanWord);
          if (dict != null) {
            partOfSpeech = dict['partOfSpeech'];
            definition = dict['definition'];
          }
        }
      }
    }

    final result = TranslationResult(
      originalText: cleanText,
      translatedText: translatedText,
      sourceLang: resolvedSource,
      targetLang: resolvedTarget,
      alternativeTranslations: alternativeTranslations.take(5).toList(),
      partOfSpeech: partOfSpeech,
      definition: definition,
    );

    _cache[cacheKey] = result;
    return result;
  }

  Future<Map<String, String>?> _fetchEnglishDefinition(String word) async {
    try {
      final url = 'https://en.wiktionary.org/api/rest_v1/page/definition/${Uri.encodeComponent(word)}';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data is Map) {
        final enEntries = response.data['en'];
        if (enEntries is List && enEntries.isNotEmpty) {
          final first = enEntries.first;
          if (first is Map) {
            final pos = first['partOfSpeech']?.toString();
            final defs = first['definitions'];
            if (defs is List && defs.isNotEmpty) {
              final firstDef = defs.first;
              if (firstDef is Map && firstDef['definition'] != null) {
                final rawDef = firstDef['definition'].toString();
                final cleanDef = rawDef.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                final map = <String, String>{'definition': cleanDef};
                if (pos != null) map['partOfSpeech'] = pos;
                return map;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>?> _fetchRussianDefinition(String word) async {
    try {
      final url = 'https://ru.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(word)}';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data is Map) {
        final desc = response.data['description']?.toString();
        final extract = response.data['extract']?.toString();
        if (extract != null && extract.isNotEmpty) {
          final firstSentence = extract.split(RegExp(r'\.|\n')).first.trim();
          final map = <String, String>{'definition': firstSentence.isNotEmpty ? '$firstSentence.' : extract};
          if (desc != null && desc.isNotEmpty) map['partOfSpeech'] = desc;
          return map;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> speak(String text, {String? lang}) async {
    await TtsService.instance.speakWord(text, lang: lang);
  }

  String _unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#8220;', '“')
        .replaceAll('&#8221;', '”')
        .replaceAll('&#8216;', '‘')
        .replaceAll('&#8217;', '’')
        .replaceAll('&nbsp;', ' ');
  }
}
