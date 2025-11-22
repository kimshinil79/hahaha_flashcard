import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_to_flashcard_dialog.dart';

class WordDetailDialog extends StatefulWidget {
  final Map<String, dynamic> wordData;
  final String sentence;
  final String highlightedWord;
  final String wordKey; // Firestore 문서 키
  final Function(String word, Map<String, dynamic> meaning)? onMeaningSelected;

  const WordDetailDialog({
    super.key,
    required this.wordData,
    required this.sentence,
    required this.highlightedWord,
    required this.wordKey,
    this.onMeaningSelected,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> wordData,
    String sentence,
    String highlightedWord,
    String wordKey, {
    Function(String word, Map<String, dynamic> meaning)? onMeaningSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => WordDetailDialog(
        wordData: wordData,
        sentence: sentence,
        highlightedWord: highlightedWord,
        wordKey: wordKey,
        onMeaningSelected: onMeaningSelected,
      ),
    );
  }

  @override
  State<WordDetailDialog> createState() => _WordDetailDialogState();
}

class _WordDetailDialogState extends State<WordDetailDialog> {
  late Map<String, dynamic> _wordData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _wordData = Map<String, dynamic>.from(widget.wordData);
  }

  String _getTextFromDynamic(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join('\n');
    }
    return value.toString();
  }

  Future<void> _showEditDialog(int meaningIndex) async {
    final meaning = _wordData['meanings'][meaningIndex] as Map<String, dynamic>;
    
    final definitionController = TextEditingController(
      text: _getTextFromDynamic(meaning['definition']),
    );
    final examplesController = TextEditingController(
      text: _getTextFromDynamic(meaning['examples']),
    );

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('의미 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '정의',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: definitionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '예문',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: examplesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    hintText: '예: I like **apples**.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: Text(
                '취소',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop({
                  'definition': definitionController.text.trim(),
                  'examples': examplesController.text.trim(),
                });
              },
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (result != null && mounted) {
        await _updateMeaning(
          meaningIndex,
          result['definition'] ?? '',
          result['examples'] ?? '',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
      definitionController.dispose();
      examplesController.dispose();
    } catch (e) {
      definitionController.dispose();
      examplesController.dispose();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('편집 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToFlashcardDirectly(Map<String, dynamic> meaning) async {
    // 단어장 추가 다이얼로그를 바로 열어서 저장
    final result = await AddToFlashcardDialog.show(
      context,
      [
        {
          'word': widget.wordKey,
          'meaning': meaning,
        },
      ],
    );

    // 저장 성공 시 WordDetailDialog 닫기 (성공 메시지는 main.dart에서 표시)
    if (result == true && mounted) {
      Navigator.of(context).pop(); // WordDetailDialog 닫기
    }
  }

  Future<void> _updateMeaning(
      int meaningIndex, String definition, String examples) async {
    try {
      final meanings = List<Map<String, dynamic>>.from(_wordData['meanings']);
      
      if (meaningIndex < meanings.length) {
        final originalMeaning = meanings[meaningIndex];
        dynamic updatedDefinition;
        dynamic updatedExamples;

        // definition 처리: 원래 배열이었다면 배열로, 아니면 문자열로
        if (originalMeaning['definition'] is List) {
          updatedDefinition = definition.isEmpty 
              ? null 
              : definition.split('\n').where((e) => e.trim().isNotEmpty).toList();
        } else {
          updatedDefinition = definition.isEmpty ? null : definition;
        }

        // examples 처리: 원래 배열이었다면 배열로, 아니면 문자열로
        if (originalMeaning['examples'] is List) {
          updatedExamples = examples.isEmpty 
              ? null 
              : examples.split('\n').where((e) => e.trim().isNotEmpty).toList();
        } else {
          updatedExamples = examples.isEmpty ? null : examples;
        }

        final updatedMeaning = Map<String, dynamic>.from(originalMeaning);
        
        if (updatedDefinition != null) {
          updatedMeaning['definition'] = updatedDefinition;
        } else {
          updatedMeaning.remove('definition');
        }
        
        if (updatedExamples != null) {
          updatedMeaning['examples'] = updatedExamples;
        } else {
          updatedMeaning.remove('examples');
        }
        
        meanings[meaningIndex] = updatedMeaning;

        // Firebase에 업데이트
        await _firestore.collection('words').doc(widget.wordKey).update({
          'meanings': meanings,
        });

        // 로컬 상태 업데이트
        if (mounted) {
          setState(() {
            _wordData['meanings'] = meanings;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('단어가 성공적으로 업데이트되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_wordData['meanings'] == null) {
      return const SizedBox.shrink();
    }

    // 화면 크기에 맞춰 동적으로 높이 계산
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final maxDialogHeight = screenHeight * 0.90; // 화면 높이의 90% 사용

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: maxDialogHeight,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 내용에 맞춰 크기 조정
          children: [
            // 헤더 (그라디언트 배경)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6366F1),
                    const Color(0xFF818CF8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // X 버튼 우측 상단과 단어 제목
                  Row(
                    children: [
                      // 단어 표시 (굵게, 흰색)
                      Expanded(
                        child: Text(
                          widget.highlightedWord,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      // X 버튼 (흰색)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 문장 (흰색 반투명 배경)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildHighlightedSentenceForHeader(context),
                  ),
                ],
              ),
            ),
            // 내용 (내용이 많으면 스크롤 가능)
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.grey.shade50,
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // meanings 배열을 순회하며 각 의미 표시
                      ...(_wordData['meanings'] as List).asMap().entries.map((entry) {
                        final index = entry.key;
                        final meaning = entry.value as Map<String, dynamic>;
                        
                        // 의미별 색상 (순환)
                        final colors = [
                          const Color(0xFF6366F1), // Indigo
                          const Color(0xFF8B5CF6), // Purple
                          const Color(0xFFEC4899), // Pink
                          const Color(0xFFF59E0B), // Amber
                          const Color(0xFF10B981), // Emerald
                        ];
                        final primaryColor = colors[index % colors.length];
                        
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < (_wordData['meanings'] as List).length - 1 ? 20 : 0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 의미 번호 헤더
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        '의미',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 내용
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Definition
                                      if (meaning['definition'] != null) ...[
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.book_outlined,
                                              size: 18,
                                              color: primaryColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildDefinitionContent(context, meaning['definition']),
                                            ),
                                          ],
                                        ),
                                        if (meaning['examples'] != null) const SizedBox(height: 18),
                                      ],
                                      // Examples
                                      if (meaning['examples'] != null) ...[
                                        _buildExampleContent(context, meaning['examples'], primaryColor),
                                      ],
                                      // 수정 버튼과 선택 버튼 (예문 밑)
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // 수정 버튼 (항상 표시)
                                          _buildActionButton(
                                            icon: Icons.edit_outlined,
                                            label: '수정',
                                            color: Colors.grey.shade600,
                                            onPressed: () => _showEditDialog(index),
                                          ),
                                          // 저장 대기하기, 단어장 추가 버튼은 onMeaningSelected가 있을 때만 표시
                                          if (widget.onMeaningSelected != null) ...[
                                            const SizedBox(width: 10),
                                            _buildActionButton(
                                              icon: Icons.bookmark_border,
                                              label: '저장 대기하기',
                                              color: Colors.grey.shade600,
                                              onPressed: () {
                                                widget.onMeaningSelected!(widget.highlightedWord, meaning);
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            const SizedBox(width: 10),
                                            _buildActionButton(
                                              icon: Icons.add_circle_outline,
                                              label: '단어장 추가',
                                              color: primaryColor,
                                              onPressed: () => _addToFlashcardDirectly(meaning),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 헤더용 문장 빌더 (흰색 텍스트)
  Widget _buildHighlightedSentenceForHeader(BuildContext context) {
    final List<TextSpan> spans = [];
    final String lowerSentence = widget.sentence.toLowerCase();
    final String lowerWord = widget.highlightedWord.toLowerCase();
    
    int wordIndex = lowerSentence.indexOf(lowerWord);
    
    if (wordIndex == -1) {
      return Text(
        widget.sentence,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.white,
        ),
      );
    }
    
    if (wordIndex > 0) {
      spans.add(TextSpan(
        text: widget.sentence.substring(0, wordIndex),
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.white70,
        ),
      ));
    }
    
    final int wordLength = widget.highlightedWord.length;
    spans.add(TextSpan(
      text: widget.sentence.substring(wordIndex, wordIndex + wordLength),
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ));
    
    if (wordIndex + wordLength < widget.sentence.length) {
      spans.add(TextSpan(
        text: widget.sentence.substring(wordIndex + wordLength),
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.white70,
        ),
      ));
    }
    
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  Widget _buildHighlightedSentence(BuildContext context) {
    final List<TextSpan> spans = [];
    final String lowerSentence = widget.sentence.toLowerCase();
    final String lowerWord = widget.highlightedWord.toLowerCase();
    
    // 단어의 위치 찾기 (대소문자 구분 없이)
    int wordIndex = lowerSentence.indexOf(lowerWord);
    
    if (wordIndex == -1) {
      // 단어를 찾지 못하면 전체 문장을 일반 스타일로
      return Text(
        widget.sentence,
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
        text: widget.sentence.substring(0, wordIndex),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade800,
            ),
      ));
    }
    
    // 강조할 단어 (원본 문장에서의 정확한 대소문자 유지)
    final int wordLength = widget.highlightedWord.length;
    spans.add(TextSpan(
      text: widget.sentence.substring(wordIndex, wordIndex + wordLength),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6366F1), // 인디고 색상
          ),
    ));
    
    // 단어 뒷부분
    if (wordIndex + wordLength < widget.sentence.length) {
      spans.add(TextSpan(
        text: widget.sentence.substring(wordIndex + wordLength),
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

  Widget _buildExampleContent(BuildContext context, dynamic example, Color accentColor) {
    Widget buildExampleText(String text) {
      final List<TextSpan> spans = [];
      final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
      int lastIndex = 0;

      for (final match in boldRegex.allMatches(text)) {
        if (match.start > lastIndex) {
          spans.add(TextSpan(
            text: text.substring(lastIndex, match.start),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.7,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
          ));
        }
        spans.add(TextSpan(
          text: match.group(1),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.7,
                fontSize: 14,
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
        ));
        lastIndex = match.end;
      }
      if (lastIndex < text.length) {
        spans.add(TextSpan(
          text: text.substring(lastIndex),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.7,
                fontSize: 14,
                color: Colors.grey.shade700,
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.08),
                    accentColor.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 20,
                    color: accentColor.withOpacity(0.6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildExampleText(item.toString()),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.08),
              accentColor.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.format_quote,
              size: 20,
              color: accentColor.withOpacity(0.6),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildExampleText(example.toString()),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


