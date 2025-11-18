import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class SearchingWords extends StatefulWidget {
  const SearchingWords({super.key});

  @override
  State<SearchingWords> createState() => _SearchingWordsState();
}

class _SearchingWordsState extends State<SearchingWords> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  String? _currentWord;

  Future<void> _searchWord(String word) async {
    if (word.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResult = null;
    });

    try {
      final docRef = _firestore.collection('words').doc(word.trim().toLowerCase());
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _searchResult = data;
          _currentWord = word.trim().toLowerCase();
        });
        // meanings 값을 JSON 형태로 보기 좋게 출력
        if (data?['meanings'] != null) {
          final meanings = data!['meanings'];
          const encoder = JsonEncoder.withIndent('  ');
          final jsonString = encoder.convert(meanings);
          print('=' * 60);
          print('검색된 단어: ${word.trim().toLowerCase()}');
          print('meanings (JSON):');
          print(jsonString);
          print('=' * 60);
        }
      } else {
        setState(() {
          _searchResult = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"{word.trim()}" 단어를 찾을 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Widget _buildDefinitionContent(dynamic definition) {
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

  Widget _buildExampleContent(dynamic example) {
    Widget buildExampleText(String text) {
      final List<TextSpan> spans = [];
      final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
      int lastIndex = 0;

      for (final match in boldRegex.allMatches(text)) {
        // 일반 텍스트 추가
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
        // 강조된 텍스트 추가
        spans.add(TextSpan(
          text: match.group(1),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
        ));
        lastIndex = match.end;
      }
      // 남은 텍스트 추가
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

  Future<void> _showEditDialog(
      BuildContext parentContext, int meaningIndex, Map<String, dynamic> meaning) async {
    final TextEditingController definitionController =
        TextEditingController(text: _getTextFromDynamic(meaning['definition']));
    final TextEditingController examplesController =
        TextEditingController(text: _getTextFromDynamic(meaning['examples']));

    try {
      // 다이얼로그 표시
      final result = await showDialog<Map<String, String>?>(
        context: parentContext,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                '단어 편집',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
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
                          borderSide: const BorderSide(color: Colors.black, width: 1.5),
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
                          borderSide: const BorderSide(color: Colors.black, width: 1.5),
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
                    // 텍스트 값 저장 후 다이얼로그 닫기
                    Navigator.of(dialogContext).pop({
                      'definition': definitionController.text.trim(),
                      'examples': examplesController.text.trim(),
                    });
                  },
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
        },
      );

      // 다이얼로그가 닫힌 후 업데이트 실행
      if (result != null && mounted) {
        await _updateMeaning(
          meaningIndex,
          result['definition'] ?? '',
          result['examples'] ?? '',
        );
      }

      // 다이얼로그가 완전히 닫힌 후에 컨트롤러 정리
      await Future.delayed(const Duration(milliseconds: 100));
      definitionController.dispose();
      examplesController.dispose();
    } catch (e) {
      // 에러 발생 시에도 컨트롤러 정리
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

  String _getTextFromDynamic(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join('\n');
    }
    return value.toString();
  }

  Future<void> _updateMeaning(
      int meaningIndex, String definition, String examples) async {
    if (_currentWord == null || _searchResult == null) return;

    try {
      final meanings = List<Map<String, dynamic>>.from(_searchResult!['meanings']);
      
      if (meaningIndex < meanings.length) {
        // 원래 데이터 형식 확인 및 변환
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

        // 업데이트된 meaning 객체 생성
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
        await _firestore.collection('words').doc(_currentWord).update({
          'meanings': meanings,
        });

        // 로컬 상태 업데이트 (mounted 체크 후)
        if (mounted) {
          setState(() {
            _searchResult!['meanings'] = meanings;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('단어가 성공적으로 업데이트되었습니다.'),
              backgroundColor: Colors.black,
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '단어를 검색하세요',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (value) {
                    _searchWord(value);
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSearching
                        ? null
                        : () => _searchWord(_searchController.text),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_searchResult != null && _searchResult!['meanings'] != null) ...[
          const SizedBox(height: 16),
          // meanings 배열을 순회하며 각 의미 표시
          ...(_searchResult!['meanings'] as List).asMap().entries.map((entry) {
            final index = entry.key;
            final meaning = entry.value as Map<String, dynamic>;
            
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < (_searchResult!['meanings'] as List).length - 1 ? 16 : 0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 편집 아이콘
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showEditDialog(context, index, meaning),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Definition 섹션
                      if (meaning['definition'] != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.book_outlined,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '정의',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDefinitionContent(meaning['definition']),
                        if (meaning['examples'] != null) const SizedBox(height: 24),
                      ],
                      // Examples 섹션
                      if (meaning['examples'] != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.lightbulb_outline,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '예문',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildExampleContent(meaning['examples']),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}

