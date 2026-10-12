class SearchResultItem {
  final int chapterIndex;
  final String chapterTitle;
  final int matchCharOffset;
  final String snippetBefore;
  final String matchedText;
  final String snippetAfter;

  const SearchResultItem({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.matchCharOffset,
    required this.snippetBefore,
    required this.matchedText,
    required this.snippetAfter,
  });

  String get fullSnippet => '$snippetBefore$matchedText$snippetAfter';
}
