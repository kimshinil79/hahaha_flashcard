import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddToFlashcardDialog extends StatefulWidget {
  final List<Map<String, dynamic>> selectedWords;

  const AddToFlashcardDialog({
    super.key,
    required this.selectedWords,
  });

  static Future<bool?> show(
    BuildContext context,
    List<Map<String, dynamic>> selectedWords,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AddToFlashcardDialog(
        selectedWords: selectedWords,
      ),
    );
  }

  @override
  State<AddToFlashcardDialog> createState() => _AddToFlashcardDialogState();
}

class _AddToFlashcardDialogState extends State<AddToFlashcardDialog> {
  late List<Map<String, dynamic>> _wordsData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;
  
  // 그룹 관련
  String? _selectedGroupId;
  String _groupName = '';
  bool _isCreatingNewGroup = false;
  List<Map<String, dynamic>> _existingGroups = [];
  
  // 날짜 관련
  DateTime _selectedDate = DateTime.now();
  
  // 난이도 관련 (각 단어별)
  final Map<int, String> _wordDifficulties = {}; // index -> difficulty

  @override
  void initState() {
    super.initState();
    _wordsData = widget.selectedWords.map((word) {
      return {
        'word': word['word'],
        'meaning': Map<String, dynamic>.from(word['meaning']),
      };
    }).toList();
    
    // 기본 난이도 설정
    for (int i = 0; i < _wordsData.length; i++) {
      _wordDifficulties[i] = 'normal'; // 기본값: normal
    }
    
    _loadExistingGroups();
  }

  Future<void> _loadExistingGroups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && userDoc.exists) {
        final userData = userDoc.data();
        final groups = userData?['groups'] as List<dynamic>? ?? [];
        
        setState(() {
          _existingGroups = groups.map((group) {
            if (group is Map<String, dynamic>) {
              return {
                'id': group['id'] ?? '',
                'name': group['name'] ?? '',
                'date': group['date'] ?? '',
              };
            }
            return {'id': '', 'name': '', 'date': ''};
          }).where((g) => g['id'] != '').toList()
            ..sort((a, b) {
              final dateA = a['date'] as String? ?? '';
              final dateB = b['date'] as String? ?? '';
              return dateB.compareTo(dateA); // 최신순
            });
        });
      }
    } catch (e) {
      print('그룹 로드 실패: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getTextFromDynamic(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join('\n');
    }
    return value.toString();
  }

  Future<void> _showEditDialog(int wordIndex) async {
    final wordData = _wordsData[wordIndex];
    final meaning = wordData['meaning'] as Map<String, dynamic>;
    
    final wordController = TextEditingController(
      text: wordData['word'] as String,
    );
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
          title: const Text('단어 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '단어',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: wordController,
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
                if (wordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('단어를 입력해주세요.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop({
                  'word': wordController.text.trim(),
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
        setState(() {
          // 단어 업데이트
          final updatedWord = result['word'] ?? wordData['word'] as String;
          _wordsData[wordIndex]['word'] = updatedWord;
          
          final updatedMeaning = Map<String, dynamic>.from(meaning);
          
          // definition 처리
          if (result['definition']?.isNotEmpty ?? false) {
            if (meaning['definition'] is List) {
              updatedMeaning['definition'] = result['definition']!
                  .split('\n')
                  .where((e) => e.trim().isNotEmpty)
                  .toList();
            } else {
              updatedMeaning['definition'] = result['definition']!;
            }
          } else {
            updatedMeaning.remove('definition');
          }
          
          // examples 처리
          if (result['examples']?.isNotEmpty ?? false) {
            if (meaning['examples'] is List) {
              updatedMeaning['examples'] = result['examples']!
                  .split('\n')
                  .where((e) => e.trim().isNotEmpty)
                  .toList();
            } else {
              updatedMeaning['examples'] = result['examples']!;
            }
          } else {
            updatedMeaning.remove('examples');
          }
          
          _wordsData[wordIndex]['meaning'] = updatedMeaning;
        });
      }

      await Future.delayed(const Duration(milliseconds: 100));
      wordController.dispose();
      definitionController.dispose();
      examplesController.dispose();
    } catch (e) {
      wordController.dispose();
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

  Future<void> _saveToFlashcard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    // 그룹 선택 확인
    if (_isCreatingNewGroup && _groupName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹 이름을 입력해주세요.')),
      );
      return;
    }

    // 새 그룹 생성 또는 기존 그룹 선택
    String? groupId = _selectedGroupId;
    if (_isCreatingNewGroup) {
      final dateString = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      
      // 새 그룹 ID 생성
      groupId = _firestore.collection('_').doc().id; // ID 생성용 (실제 저장 안 함)
      
      // 사용자 문서 가져오기
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      final userData = userDoc.data() ?? {};
      
      // 기존 groups 배열 가져오기
      final existingGroups = (userData['groups'] as List<dynamic>?) ?? [];
      
      // 새 그룹 추가 (배열 안에는 FieldValue.serverTimestamp() 사용 불가)
      final now = DateTime.now();
      final newGroup = {
        'id': groupId,
        'name': _groupName.trim(),
        'date': dateString,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };
      
      existingGroups.add(newGroup);
      
      // 사용자 문서 업데이트 (문서가 없으면 생성)
      await userDocRef.set({
        'groups': existingGroups,
      }, SetOptions(merge: true));
    }

    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹을 선택하거나 생성해주세요.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 배열 안에는 FieldValue.serverTimestamp() 사용 불가하므로 Timestamp.fromDate 사용
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      final userData = userDoc.data() ?? {};
      
      // 기존 flashcards 배열 가져오기
      final existingFlashcards = (userData['flashcards'] as List<dynamic>?) ?? [];
      
      for (int i = 0; i < _wordsData.length; i++) {
        final wordData = _wordsData[i];
        final word = wordData['word'] as String;
        final meaning = wordData['meaning'] as Map<String, dynamic>;
        final difficulty = _wordDifficulties[i] ?? 'normal';
        
        // embedding 데이터 제거한 meaning 생성
        final meaningWithoutEmbedding = Map<String, dynamic>.from(meaning);
        meaningWithoutEmbedding.remove('embedding');
        
        // 기존 단어 찾기 (word로)
        int existingIndex = -1;
        Map<String, dynamic>? existingWordData;
        
        for (int j = 0; j < existingFlashcards.length; j++) {
          final flashcard = existingFlashcards[j] as Map<String, dynamic>;
          if (flashcard['word'] == word) {
            existingIndex = j;
            existingWordData = Map<String, dynamic>.from(flashcard);
            break;
          }
        }
        
        // groups 배열 처리
        List<String> groups = [];
        if (existingWordData != null && existingWordData['groups'] != null) {
          groups = List<String>.from(existingWordData['groups']);
        }
        if (!groups.contains(groupId)) {
          groups.add(groupId);
        }
        
        // viewCount 처리
        final viewCount = existingWordData?['viewCount'] ?? 0;
        
        // createdAt 처리 (기존 값이 있으면 유지, 없으면 새로 생성)
        dynamic createdAt;
        if (existingWordData != null && existingWordData['createdAt'] != null) {
          createdAt = existingWordData['createdAt'];
        } else {
          createdAt = timestamp;
        }
        
        final flashcardData = {
          'word': word,
          'meaning': meaningWithoutEmbedding, // embedding 제외한 meaning 사용
          'groups': groups,
          'difficulty': difficulty,
          'viewCount': viewCount,
          'createdAt': createdAt,
          'updatedAt': timestamp,
        };
        
        if (existingIndex >= 0) {
          // 기존 단어 업데이트
          existingFlashcards[existingIndex] = flashcardData;
        } else {
          // 새 단어 추가
          existingFlashcards.add(flashcardData);
        }
      }
      
      // 사용자 문서에 flashcards 배열 업데이트 (문서가 없으면 생성)
      await userDocRef.set({
        'flashcards': existingFlashcards,
      }, SetOptions(merge: true));
      
      // 그룹 목록 새로고침
      if (_isCreatingNewGroup) {
        await _loadExistingGroups();
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('단어장에 성공적으로 추가되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final maxDialogHeight = screenHeight * 0.90;

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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '단어장에 추가',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                    ),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 그룹 선택 섹션
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '그룹',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _isCreatingNewGroup
                                    ? TextField(
                                        onChanged: (value) {
                                          setState(() {
                                            _groupName = value;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: '그룹 이름 입력',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      )
                                    : DropdownButtonFormField<String>(
                                        value: _selectedGroupId,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        hint: const Text('그룹 선택'),
                                        items: _existingGroups.map((group) {
                                          return DropdownMenuItem<String>(
                                            value: group['id'] as String,
                                            child: Text(group['name'] as String),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedGroupId = value;
                                            _isCreatingNewGroup = false;
                                          });
                                        },
                                      ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isCreatingNewGroup = !_isCreatingNewGroup;
                                    if (!_isCreatingNewGroup) {
                                      _groupName = '';
                                    }
                                  });
                                },
                                child: Text(_isCreatingNewGroup ? '취소' : '새 그룹'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 날짜 선택 섹션
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '날짜',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today, size: 20),
                            onPressed: _selectDate,
                            color: const Color(0xFF6366F1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 단어 목록
                    ..._wordsData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final wordData = entry.value;
                      final word = wordData['word'] as String;
                      final meaning = wordData['meaning'] as Map<String, dynamic>;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < _wordsData.length - 1 ? 16 : 0,
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
                              // 단어 제목
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      word,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: const Color(0xFF6366F1),
                                          ),
                                    ),
                                  ),
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
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 난이도 선택
                              Row(
                                children: [
                                  Text(
                                    '난이도: ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ...['easy', 'normal', 'hard'].map((difficulty) {
                                    final isSelected = _wordDifficulties[index] == difficulty;
                                    Color? color;
                                    String label;
                                    switch (difficulty) {
                                      case 'easy':
                                        color = Colors.green;
                                        label = '쉬움';
                                        break;
                                      case 'normal':
                                        color = Colors.orange;
                                        label = '보통';
                                        break;
                                      case 'hard':
                                        color = Colors.red;
                                        label = '어려움';
                                        break;
                                      default:
                                        label = difficulty;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _wordDifficulties[index] = difficulty;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected ? color : Colors.transparent,
                                            border: Border.all(
                                              color: color!,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? Colors.white : color,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                              const SizedBox(height: 12),
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
            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      '취소',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveToFlashcard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '저장',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

