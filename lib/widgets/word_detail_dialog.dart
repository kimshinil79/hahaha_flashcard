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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: maxDialogHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // X 버튼 우측 상단
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  // 문장
                  _buildHighlightedSentence(context),
                ],
              ),
            ),
            // 내용 (나머지 공간 모두 사용)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // meanings 배열을 순회하며 각 의미 표시
                    ...(_wordData['meanings'] as List).asMap().entries.map((entry) {
                      final index = entry.key;
                      final meaning = entry.value as Map<String, dynamic>;
                      
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < (_wordData['meanings'] as List).length - 1 ? 16 : 0,
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
                              // 수정 버튼과 선택 버튼 (예문 밑)
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 수정 버튼
                                  TextButton(
                                    onPressed: () => _showEditDialog(index),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                                      ),
                                    ),
                                    child: Text(
                                      '수정',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 저장 대기하기 버튼
                                  TextButton(
                                    onPressed: () {
                                      if (widget.onMeaningSelected != null) {
                                        widget.onMeaningSelected!(widget.highlightedWord, meaning);
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                                      ),
                                    ),
                                    child: Text(
                                      '저장 대기하기',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 단어장 추가 버튼
                                  TextButton(
                                    onPressed: () => _addToFlashcardDirectly(meaning),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: const Color(0xFF6366F1), width: 1.5),
                                      ),
                                    ),
                                    child: const Text(
                                      '단어장 추가',
                                      style: TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
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
          ],
        ),
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

