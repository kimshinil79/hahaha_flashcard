import 'package:flutter/material.dart';

class WordDetailDialog extends StatelessWidget {
  final Map<String, dynamic> wordData;
  final String sentence;
  final String highlightedWord;

  const WordDetailDialog({
    super.key,
    required this.wordData,
    required this.sentence,
    required this.highlightedWord,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> wordData, String sentence, String highlightedWord) {
    return showDialog(
      context: context,
      builder: (context) => WordDetailDialog(
        wordData: wordData,
        sentence: sentence,
        highlightedWord: highlightedWord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (wordData['meanings'] == null) {
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildHighlightedSentence(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // 내용
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // meanings 배열을 순회하며 각 의미 표시
                    ...(wordData['meanings'] as List).asMap().entries.map((entry) {
                      final index = entry.key;
                      final meaning = entry.value as Map<String, dynamic>;
                      
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < (wordData['meanings'] as List).length - 1 ? 16 : 0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200.withOpacity(0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Definition
                              if (meaning['definition'] != null) ...[
                                _buildDefinitionContent(context, meaning['definition']),
                                if (meaning['examples'] != null) const SizedBox(height: 16),
                              ],
                              // Examples
                              if (meaning['examples'] != null) ...[
                                _buildExampleContent(context, meaning['examples']),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedSentence(BuildContext context) {
    final List<TextSpan> spans = [];
    final String lowerSentence = sentence.toLowerCase();
    final String lowerWord = highlightedWord.toLowerCase();
    
    // 단어의 위치 찾기 (대소문자 구분 없이)
    int wordIndex = lowerSentence.indexOf(lowerWord);
    
    if (wordIndex == -1) {
      // 단어를 찾지 못하면 전체 문장을 일반 스타일로
      return Text(
        sentence,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade800,
            ),
      );
    }
    
    // 단어 앞부분
    if (wordIndex > 0) {
      spans.add(TextSpan(
        text: sentence.substring(0, wordIndex),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade800,
            ),
      ));
    }
    
    // 강조할 단어 (원본 문장에서의 정확한 대소문자 유지)
    final int wordLength = highlightedWord.length;
    spans.add(TextSpan(
      text: sentence.substring(wordIndex, wordIndex + wordLength),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6366F1), // 인디고 색상
          ),
    ));
    
    // 단어 뒷부분
    if (wordIndex + wordLength < sentence.length) {
      spans.add(TextSpan(
        text: sentence.substring(wordIndex + wordLength),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade800,
            ),
      ));
    }
    
    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildDefinitionContent(BuildContext context, dynamic definition) {
    if (definition is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: definition.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < definition.length - 1 ? 12 : 0),
            child: Text(
              item.toString(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    fontSize: 15,
                    color: Colors.grey.shade800,
                  ),
              textAlign: TextAlign.justify,
            ),
          );
        }).toList(),
      );
    } else {
      return Text(
        definition.toString(),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
        textAlign: TextAlign.justify,
      );
    }
  }

  Widget _buildExampleContent(BuildContext context, dynamic example) {
    Widget buildExampleText(String text) {
      final List<TextSpan> spans = [];
      final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
      int lastIndex = 0;

      for (final match in boldRegex.allMatches(text)) {
        if (match.start > lastIndex) {
          spans.add(TextSpan(
            text: text.substring(lastIndex, match.start),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
          ));
        }
        spans.add(TextSpan(
          text: match.group(1),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: 14,
                color: const Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
        ));
        lastIndex = match.end;
      }
      if (lastIndex < text.length) {
        spans.add(TextSpan(
          text: text.substring(lastIndex),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
        ));
      }

      return Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
      );
    }

    if (example is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: example.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < example.length - 1 ? 12 : 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: buildExampleText(item.toString()),
            ),
          );
        }).toList(),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: buildExampleText(example.toString()),
      );
    }
  }
}

