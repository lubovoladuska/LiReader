import 'package:flutter/material.dart';
import '../../models/search_result.dart';
import '../../providers/reader_provider.dart';
import '../../theme/app_theme.dart';

class BookSearchSheet extends StatefulWidget {
  final ReaderProvider reader;
  final Function(int chapterIndex) onJumpToChapter;

  const BookSearchSheet({
    super.key,
    required this.reader,
    required this.onJumpToChapter,
  });

  @override
  State<BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<BookSearchSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reader.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      widget.reader.searchInBook(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reader = widget.reader;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Sheet Grabber
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Clear Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppTheme.primaryPinkDark, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Поиск по книге',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (reader.searchResults.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _controller.clear();
                          reader.clearSearch();
                        },
                        child: const Text('Сбросить'),
                      ),
                  ],
                ),
              ),

              // Search Input Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _controller,
                  autofocus: reader.searchResults.isEmpty,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Введите слово или фразу...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _controller.clear();
                              reader.clearSearch();
                              setState(() {});
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryPinkDark),
                          onPressed: _performSearch,
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              // Search Status or Loading
              if (reader.isSearching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Ищем совпадения в книге...', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (reader.searchQuery.isNotEmpty && reader.searchResults.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Ничего не найдено по запросу «${reader.searchQuery}»',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (reader.searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Найдено совпадений: ${reader.searchResults.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),

                // Results List
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: reader.searchResults.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = reader.searchResults[idx];
                      final isSelected = reader.currentSearchIndex == idx;

                      return _buildResultTile(context, item, idx, isSelected, isDark);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultTile(
    BuildContext context,
    SearchResultItem item,
    int index,
    bool isSelected,
    bool isDark,
  ) {
    return Material(
      color: isSelected
          ? AppTheme.primaryPink.withValues(alpha: isDark ? 0.25 : 0.15)
          : (isDark ? AppTheme.darkCard : Colors.white),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          widget.reader.goToSearchResult(index);
          widget.onJumpToChapter(item.chapterIndex);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryPinkDark
                  : (isDark ? AppTheme.darkDivider : const Color(0xFFECE5E7)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.chapterTitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryPinkDark,
                    ),
                  ),
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  children: [
                    TextSpan(text: item.snippetBefore),
                    TextSpan(
                      text: item.matchedText,
                      style: TextStyle(
                        backgroundColor: isDark
                            ? Colors.amber.withValues(alpha: 0.35)
                            : Colors.yellow.withValues(alpha: 0.45),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amberAccent : Colors.black,
                      ),
                    ),
                    TextSpan(text: item.snippetAfter),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
