import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'group_selection_dialog.dart';

enum StudyContinuationOption {
  lowFrequency,
  hardWords,
  mix,
  goHome,
}

class FlashcardStudyScreen extends StatefulWidget {
  final List<Map<String, dynamic>> flashcards;
  final VoidCallback? onStudyComplete; // 공부 완료 콜백 추가

  const FlashcardStudyScreen({
    super.key,
    required this.flashcards,
    this.onStudyComplete,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late List<Map<String, dynamic>> _flashcards; // 로컬 복사본
  bool _isFlipped = false; // 카드가 뒤집혔는지 여부
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  final Map<String, int> _starCounts = {}; // 단어별 별 개수 (word -> star count)
  final Set<String> _viewedWords = {};
  
  // 슬라이드 애니메이션
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // TTS (Text-to-Speech)
  FlutterTts? _flutterTts; // nullable로 변경하여 초기화 실패 대비
  bool _isSpeaking = false;
  bool _isTtsInitialized = false; // TTS 초기화 성공 여부 추적

  @override
  void initState() {
    super.initState();
    // 로컬 복사본 생성
    _flashcards = widget.flashcards.map((f) => Map<String, dynamic>.from(f)).toList();
    _initializeStarCounts();
    
    // 카드 뒤집기 애니메이션 초기화
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // 슬라이드 애니메이션 초기화
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    // TTS 초기화
    _initializeTts();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _flashcards.isNotEmpty) {
        _updateViewCount(0);
      }
    });
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      // TTS 설정
      await _flutterTts!.setLanguage("en-US"); // 영어 (미국)
      await _flutterTts!.setSpeechRate(0.5); // 속도 (0.0 ~ 1.0)
      await _flutterTts!.setVolume(1.0); // 볼륨 (0.0 ~ 1.0)
      await _flutterTts!.setPitch(1.0); // 음높이 (0.5 ~ 2.0)
      
      // 완료 콜백 설정
      _flutterTts!.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });
      
      // 에러 핸들러 설정
      _flutterTts!.setErrorHandler((msg) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
          print('TTS 오류: $msg');
        }
      });
      
      // 초기화 성공 플래그 설정
      _isTtsInitialized = true;
    } catch (e) {
      print('TTS 초기화 실패: $e');
      print('앱을 완전히 재빌드해주세요: flutter run');
      _isTtsInitialized = false;
      _flutterTts = null; // 실패 시 null로 설정
    }
  }
  
  Future<void> _speakWord(String word) async {
    // TTS가 초기화되지 않았으면 스킵
    if (!_isTtsInitialized || _flutterTts == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('발음 기능을 사용할 수 없습니다. 앱을 재빌드해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    try {
      if (_isSpeaking) {
        // 이미 재생 중이면 중지
        await _flutterTts!.stop();
        setState(() {
          _isSpeaking = false;
        });
        return;
      }
      
      setState(() {
        _isSpeaking = true;
      });
      
      await _flutterTts!.speak(word);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        print('단어 발음 재생 오류: $e');
        // TTS가 사용 불가능한 경우 사용자에게 알림
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('발음 기능을 사용할 수 없습니다. 앱을 재빌드해주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
  

  void _initializeStarCounts() {
    _starCounts.clear();
    for (var flashcard in _flashcards) {
      final word = flashcard['word'] as String;
      _starCounts[word] = 0;
    }
  }

  Future<void> _resetForNewSession(List<Map<String, dynamic>> newFlashcards) async {
    if (newFlashcards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로운 학습 카드가 없습니다.')),
        );
        Navigator.of(context).pop(true);
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _flashcards = newFlashcards;
      _currentIndex = 0;
      _isFlipped = false;
      _flipController.reset();
      _initializeStarCounts();
      _viewedWords.clear();
    });

    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted && _flashcards.isNotEmpty) {
      _updateViewCount(0);
    }
  }

  Future<List<Map<String, dynamic>>> _loadFlashcardsByOption(
    StudyContinuationOption option,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() ?? {};
      final allFlashcards = (userData['flashcards'] as List<dynamic>? ?? [])
          .map((f) => Map<String, dynamic>.from(f as Map<String, dynamic>))
          .toList();

      if (allFlashcards.isEmpty) return [];

      List<Map<String, dynamic>> result = [];

      int viewCountOf(Map<String, dynamic> card) =>
          card['viewCount'] as int? ?? 0;

      switch (option) {
        case StudyContinuationOption.lowFrequency:
          allFlashcards.sort((a, b) => viewCountOf(a).compareTo(viewCountOf(b)));
          result = allFlashcards.take(10).map((c) => Map<String, dynamic>.from(c)).toList();
          break;
        case StudyContinuationOption.hardWords:
          final hardList = allFlashcards
              .where((card) => (card['difficulty'] as String?) == 'hard')
              .toList()
            ..sort((a, b) => viewCountOf(a).compareTo(viewCountOf(b)));
          result = hardList.take(10).map((c) => Map<String, dynamic>.from(c)).toList();
          break;
        case StudyContinuationOption.mix:
          final lowList = [...allFlashcards]
            ..sort((a, b) => viewCountOf(a).compareTo(viewCountOf(b)));
          final hardList = allFlashcards
              .where((card) => (card['difficulty'] as String?) == 'hard')
              .toList()
            ..sort((a, b) => viewCountOf(a).compareTo(viewCountOf(b)));

          final combined = <Map<String, dynamic>>[];
          final seen = <String>{};

          void addCards(List<Map<String, dynamic>> source) {
            for (final card in source) {
              final word = card['word'] as String? ?? '';
              if (word.isEmpty) continue;
              if (seen.add(word)) {
                combined.add(Map<String, dynamic>.from(card));
                if (combined.length >= 10) break;
              }
            }
          }

          addCards(lowList.take(5).toList());
          if (combined.length < 10) {
            addCards(hardList.take(5).toList());
          }
          if (combined.length < 10) {
            addCards(lowList.skip(5).toList());
          }
          result = combined;
          break;
        case StudyContinuationOption.goHome:
          // handled separately
          break;
      }

      return result;
    } catch (e) {
      print('새로운 학습 카드 로드 실패: $e');
      return [];
    }
  }

  Future<void> _showNextStudyOptions() async {
    if (!mounted) return;

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const Text(
                  '공부 must go on....',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F39),
                  ),
                ),
                const SizedBox(height: 20),
                _buildNextStudyButton(
                  icon: Icons.visibility,
                  color: const Color(0xFF4ADE80),
                  title: '공부 빈도 낮은 단어',
                  description: 'viewCount가 가장 낮은 10개의 단어',
                  option: StudyContinuationOption.lowFrequency,
                ),
                const SizedBox(height: 12),
                _buildNextStudyButton(
                  icon: Icons.bolt,
                  color: const Color(0xFFFB7185),
                  title: '어려운 단어',
                  description: '난이도가 어려움으로 표시된 단어',
                  option: StudyContinuationOption.hardWords,
                ),
                const SizedBox(height: 12),
                _buildNextStudyButton(
                  icon: Icons.layers,
                  color: const Color(0xFF6366F1),
                  title: '1번과 2번 믹스',
                  description: '빈도 낮은 단어와 어려운 단어를 조합',
                  option: StudyContinuationOption.mix,
                ),
                const SizedBox(height: 12),
                _buildGroupWordsButton(),
                const SizedBox(height: 12),
                _buildNextStudyButton(
                  icon: Icons.home,
                  color: Colors.grey.shade500,
                  title: 'main 화면으로 가기',
                  description: '홈 화면으로 돌아갑니다',
                  option: StudyContinuationOption.goHome,
                ),
              ],
            ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    // 그룹 선택 케이스 처리
    if (result == 'groupSelection') {
      // 그룹 선택 다이얼로그 표시
      final selectedGroupId = await GroupSelectionDialog.show(context);
      
      if (!mounted) return;

      // 그룹 선택 취소 시 옵션 메뉴로 다시 돌아감
      if (selectedGroupId == null) {
        await _showNextStudyOptions();
        return;
      }

      // 선택된 그룹의 단어들 로드
      final newFlashcards = await _loadFlashcardsByGroup(selectedGroupId);
      
      if (!mounted) return;

      // 선택한 그룹에 단어가 없으면 옵션 메뉴로 다시 돌아감
      if (newFlashcards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('해당 그룹에 단어가 없습니다. 다른 옵션을 선택해주세요.')),
          );
        }
        await _showNextStudyOptions();
        return;
      }

      await _resetForNewSession(newFlashcards);
      return;
    }

    // 기존 옵션 처리
    final option = result as StudyContinuationOption?;

    if (option == null || option == StudyContinuationOption.goHome) {
      Navigator.of(context).pop(true);
      return;
    }

    final newFlashcards = await _loadFlashcardsByOption(option);
    if (newFlashcards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로운 학습 카드가 없습니다.')),
        );
        Navigator.of(context).pop(true);
      }
      return;
    }

    await _resetForNewSession(newFlashcards);
  }

  Widget _buildNextStudyButton({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required StudyContinuationOption option,
  }) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(option),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB8B6C4)),
        ],
      ),
    );
  }

  Widget _buildGroupWordsButton() {
    return ElevatedButton(
      onPressed: () {
        // 다이얼로그를 닫고 특별한 값 반환 (그룹 선택 플래그)
        Navigator.of(context).pop('groupSelection');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: const Color(0xFFF59E0B).withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '그룹별 단어',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '그룹을 선택하여 해당 그룹의 단어 학습',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB8B6C4)),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadFlashcardsByGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() ?? {};
      final allFlashcards = (userData['flashcards'] as List<dynamic>? ?? [])
          .map((f) => Map<String, dynamic>.from(f as Map<String, dynamic>))
          .toList();

      if (allFlashcards.isEmpty) return [];

      // 선택된 그룹 ID가 포함된 단어들 필터링
      final groupFlashcards = allFlashcards.where((card) {
        final groups = card['groups'] as List<dynamic>? ?? [];
        return groups.contains(groupId);
      }).toList();

      // viewCount 순으로 정렬
      groupFlashcards.sort((a, b) {
        final viewCountA = a['viewCount'] as int? ?? 0;
        final viewCountB = b['viewCount'] as int? ?? 0;
        return viewCountA.compareTo(viewCountB);
      });

      // 최대 10개까지만 반환
      return groupFlashcards.take(10).map((c) => Map<String, dynamic>.from(c)).toList();
    } catch (e) {
      print('그룹별 단어 로드 실패: $e');
      return [];
    }
  }

  Widget _buildDifficultySelector() {
    final currentFlashcard = _flashcards[_currentIndex];
    final currentDifficulty = currentFlashcard['difficulty'] as String? ?? 'normal';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['easy', 'normal', 'hard'].map((difficulty) {
        final isSelected = currentDifficulty == difficulty;
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => _updateDifficulty(difficulty),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: color!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _updateViewCount(int index) async {
    if (index < 0 || index >= _flashcards.length) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final flashcard = _flashcards[index];
    final word = flashcard['word'] as String;
    if (_viewedWords.contains(word)) return;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final flashcards = (userData['flashcards'] as List<dynamic>?) ?? [];

      for (int i = 0; i < flashcards.length; i++) {
        final card = flashcards[i] as Map<String, dynamic>;
        if (card['word'] == word) {
          final currentViewCount = card['viewCount'] as int? ?? 0;
          card['viewCount'] = currentViewCount + 1;
          flashcards[i] = card;

          await userDocRef.set({
            'flashcards': flashcards,
          }, SetOptions(merge: true));

          if (mounted) {
            setState(() {
              _flashcards[index]['viewCount'] = currentViewCount + 1;
              _viewedWords.add(word);
            });
          } else {
            _viewedWords.add(word);
          }
          break;
        }
      }
    } catch (e) {
      print('viewCount 업데이트 실패: $e');
    }
  }

  Future<void> _showEditDialog(String word, Map<String, dynamic> meaning) async {
    final wordController = TextEditingController(text: word);
    final definitionController = TextEditingController(
      text: meaning['definition'] is String 
          ? meaning['definition'] 
          : (meaning['definition'] is List && (meaning['definition'] as List).isNotEmpty)
              ? (meaning['definition'] as List).join('\n')
              : '',
    );
    
    // 예문을 리스트로 변환
    List<String> examples = [];
    if (meaning['examples'] != null) {
      if (meaning['examples'] is List) {
        examples = (meaning['examples'] as List).map((e) => e.toString()).toList();
      } else if (meaning['examples'] is String) {
        examples = [meaning['examples']];
      }
    }
    
    final exampleControllers = examples.map((e) => TextEditingController(text: e)).toList();
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async {
                // 다이얼로그가 닫힐 때 컨트롤러 정리
                wordController.dispose();
                definitionController.dispose();
                for (var controller in exampleControllers) {
                  controller.dispose();
                }
                return true;
              },
              child: AlertDialog(
              title: const Text('단어 수정'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 단어 스펠링
                      TextField(
                        controller: wordController,
                        decoration: const InputDecoration(
                          labelText: '단어',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 정의
                      TextField(
                        controller: definitionController,
                        decoration: const InputDecoration(
                          labelText: '정의',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // 예문
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '예문',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setDialogState(() {
                                exampleControllers.add(TextEditingController());
                              });
                            },
                          ),
                        ],
                      ),
                      ...exampleControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: '예문 ${index + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setDialogState(() {
                                    controller.dispose();
                                    exampleControllers.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // WillPopScope가 컨트롤러를 정리하므로 Navigator.pop만 호출
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newWord = wordController.text.trim();
                    final newDefinition = definitionController.text.trim();
                    final newExamples = exampleControllers
                        .map((c) => c.text.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    
                    if (newWord.isEmpty || newDefinition.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('단어와 정의는 필수입니다.')),
                        );
                      }
                      // 검증 실패 시 다이얼로그는 열려있으므로 컨트롤러는 유지
                      // WillPopScope가 다이얼로그가 닫힐 때 dispose 처리
                      return;
                    }
                    
                    await _updateFlashcard(word, newWord, newDefinition, newExamples);
                    
                    if (mounted) {
                      // WillPopScope가 컨트롤러를 정리하므로 Navigator.pop만 호출
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장'),
                ),
              ],
            ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateFlashcard(
    String oldWord,
    String newWord,
    String newDefinition,
    List<String> newExamples,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final flashcards = (userData['flashcards'] as List<dynamic>? ?? [])
          .map((f) => Map<String, dynamic>.from(f as Map<String, dynamic>))
          .toList();

      // 현재 단어 찾기
      final cardIndex = flashcards.indexWhere((card) => card['word'] == oldWord);
      if (cardIndex == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단어를 찾을 수 없습니다.')),
          );
        }
        return;
      }

      // 단어 업데이트
      final updatedMeaning = {
        'definition': newDefinition,
        if (newExamples.isNotEmpty) 'examples': newExamples,
      };

      flashcards[cardIndex]['word'] = newWord;
      flashcards[cardIndex]['meaning'] = updatedMeaning;
      flashcards[cardIndex]['updatedAt'] = Timestamp.fromDate(DateTime.now());

      // Firestore 업데이트
      await userDocRef.set({
        'flashcards': flashcards,
      }, SetOptions(merge: true));

      // 로컬 상태 업데이트
      if (mounted) {
        setState(() {
          final localIndex = _flashcards.indexWhere((c) => c['word'] == oldWord);
          if (localIndex != -1) {
            _flashcards[localIndex]['word'] = newWord;
            _flashcards[localIndex]['meaning'] = updatedMeaning;
            
            // 별 카운트도 새 단어로 업데이트
            if (_starCounts.containsKey(oldWord)) {
              final starCount = _starCounts[oldWord] ?? 0;
              _starCounts.remove(oldWord);
              _starCounts[newWord] = starCount;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 수정되었습니다.')),
        );
      }
    } catch (e) {
      print('단어 수정 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _updateDifficulty(String difficulty) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentFlashcard = _flashcards[_currentIndex];
    final word = currentFlashcard['word'] as String;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final flashcards = (userData['flashcards'] as List<dynamic>?) ?? [];

      // 해당 단어 찾아서 난이도 업데이트
      for (int i = 0; i < flashcards.length; i++) {
        final card = flashcards[i] as Map<String, dynamic>;
        if (card['word'] == word) {
          card['difficulty'] = difficulty;
          flashcards[i] = card;

          // Firestore 업데이트
          await userDocRef.set({
            'flashcards': flashcards,
          }, SetOptions(merge: true));

          // 로컬 상태 업데이트
          if (mounted) {
            setState(() {
              _flashcards[_currentIndex]['difficulty'] = difficulty;
            });
          }
          break;
        }
      }
    } catch (e) {
      print('난이도 업데이트 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('난이도 업데이트 실패: $e')),
        );
      }
    }
  }

  Future<void> _updateAllViewCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final flashcards = (userData['flashcards'] as List<dynamic>?) ?? [];
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);

      // 모든 단어의 viewCount 증가
      for (int i = 0; i < flashcards.length; i++) {
        final card = flashcards[i] as Map<String, dynamic>;
        final word = card['word'] as String;
        
        // 별 2개를 받은 단어만 viewCount 증가
        if (_starCounts[word] == 2) {
          final currentViewCount = card['viewCount'] as int? ?? 0;
          final newViewCount = currentViewCount + 1;
          card['viewCount'] = newViewCount;
          card['lastStudiedAt'] = timestamp;
          flashcards[i] = card;

          if (mounted) {
            setState(() {
              final localIndex = _flashcards.indexWhere((c) => c['word'] == word);
              if (localIndex != -1) {
                _flashcards[localIndex]['viewCount'] = newViewCount;
                _flashcards[localIndex]['lastStudiedAt'] = timestamp;
              }
            });
          }
        }
      }

      // Firestore 업데이트
      await userDocRef.set({
        'flashcards': flashcards,
      }, SetOptions(merge: true));
    } catch (e) {
      print('viewCount 업데이트 실패: $e');
    }
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _nextWord() {
    if (_flashcards.isEmpty) return;
    
    // 우측에서 슬라이드 애니메이션 설정
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // 우측에서 시작
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _slideController.forward(from: 0.0);
    
    setState(() {
      // 끝에 도달하면 처음으로 돌아가기
      if (_currentIndex >= _flashcards.length - 1) {
        _currentIndex = 0;
      } else {
        _currentIndex++;
      }
      _isFlipped = false;
      _flipController.reset();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateViewCount(_currentIndex);
      }
    });
  }

  void _previousWord() {
    if (_flashcards.isEmpty) return;
    
    // 좌측에서 슬라이드 애니메이션 설정
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // 좌측에서 시작
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _slideController.forward(from: 0.0);
    
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else {
        // 처음이면 마지막으로
        _currentIndex = _flashcards.length - 1;
      }
      _isFlipped = false;
      _flipController.reset();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateViewCount(_currentIndex);
      }
    });
  }

  void _addStar() {
    // 현재 카드가 유효한지 확인
    if (_currentIndex >= _flashcards.length || _flashcards.isEmpty) {
      return;
    }

    final currentFlashcard = _flashcards[_currentIndex];
    final word = currentFlashcard['word'] as String;
    final currentStars = _starCounts[word] ?? 0;

    // 이미 별 2개를 받았으면 아무것도 하지 않음
    if (currentStars >= 2) {
      return;
    }

    // 별 추가 (최대 2개까지만)
    final newStarCount = (currentStars + 1).clamp(0, 2);
    
    setState(() {
      _starCounts[word] = newStarCount;
    });

    // 별 2개를 받은 카드는 목록에서 제거
    if (newStarCount == 2) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        
        // 카드가 아직 리스트에 있는지 확인
        final cardIndex = _flashcards.indexWhere((c) => c['word'] == word);
        if (cardIndex == -1) return; // 이미 제거됨

        setState(() {
          _flashcards.removeAt(cardIndex);
          
          // 인덱스 조정
          if (_currentIndex >= _flashcards.length && _flashcards.isNotEmpty) {
            _currentIndex = 0;
          } else if (_currentIndex >= _flashcards.length || _flashcards.isEmpty) {
            _currentIndex = 0;
          }
          
          _isFlipped = false;
          _flipController.reset();
        });

        // 모든 카드가 별 2개를 받았는지 확인
        if (_flashcards.isEmpty) {
          _onStudyComplete();
        } else {
          // 다음 카드로 이동 (끝이면 처음으로)
          _nextWord();
        }
      });
    } else {
      // 별 1개만 받았으면 0.5초 후 다음 카드로 이동 (끝이면 처음으로)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _nextWord();
        }
      });
    }
  }

  Future<void> _onStudyComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 공부한 단어 목록 수집 (별 2개를 받은 단어들)
    final studiedWords = <String>[];
    _starCounts.forEach((word, stars) {
      if (stars == 2) {
        studiedWords.add(word);
      }
    });

    // 공부 세션 기록 저장
    if (studiedWords.isNotEmpty) {
      try {
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final studyHistory = Map<String, dynamic>.from(userData['studyHistory'] as Map<String, dynamic>? ?? {});

          // 해당 날짜의 세션 목록 가져오기
          final dateData = Map<String, dynamic>.from(studyHistory[dateStr] as Map<String, dynamic>? ?? {});
          final sessions = List<dynamic>.from(dateData['sessions'] as List<dynamic>? ?? []);

          // 새 세션 추가
          sessions.add({
            'time': timeStr,
            'words': studiedWords,
          });

          // 날짜별 데이터 업데이트
          studyHistory[dateStr] = {
            'sessions': sessions,
            'count': sessions.length,
          };

          // Firestore 업데이트
          await userDocRef.set({
            'studyHistory': studyHistory,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        print('공부 세션 저장 실패: $e');
      }
    }

    // 모든 단어의 viewCount 업데이트
    await _updateAllViewCounts();

    // Firestore 업데이트 완료 후 콜백 호출 (달력 새로고침용)
    if (mounted && widget.onStudyComplete != null) {
      widget.onStudyComplete!();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('공부를 완료했습니다! 🎉'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      await _showNextStudyOptions();
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
                    fontSize: 16,
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
              fontSize: 16,
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
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
          ));
        }
        spans.add(TextSpan(
          text: match.group(1),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: 15,
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
                fontSize: 15,
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
            padding: EdgeInsets.only(bottom: index < example.length - 1 ? 16 : 0),
            child: buildExampleText(item.toString()),
          );
        }).toList(),
      );
    } else {
      return buildExampleText(example.toString());
    }
  }

  Widget _buildFrontCard(String word) {
    final starCount = _starCounts[word] ?? 0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: constraints.maxHeight > 0 ? constraints.maxHeight : null,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    word,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            // 별 표시 (우측 상단)
            if (starCount > 0)
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(starCount.clamp(0, 2), (index) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 28,
                      ),
                    );
                  }),
                ),
              ),
            // 스피커 아이콘 (우측 하단)
            Positioned(
              bottom: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _speakWord(word),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                    color: const Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 단어의 발음기호를 Firebase에서 가져와서 플래시카드 데이터에 추가
  Future<void> _loadPronunciationIfNeeded(String word, int index) async {
    // 인덱스가 유효한지 확인
    if (index >= _flashcards.length || index < 0) return;
    
    // 이미 발음기호가 있으면 스킵
    if (_flashcards[index]['pronunciation'] != null &&
        (_flashcards[index]['pronunciation'] as String).trim().isNotEmpty) {
      return;
    }
    
    try {
      // words 컬렉션에서 발음기호 가져오기
      final wordDoc = await _firestore.collection('words').doc(word.toLowerCase()).get();
      
      if (wordDoc.exists) {
        final wordData = wordDoc.data();
        final pronunciation = wordData?['pronunciation'] as String?;
        
        if (pronunciation != null && pronunciation.trim().isNotEmpty && mounted) {
          // 플래시카드 데이터에 발음기호 추가
          if (index < _flashcards.length) {
            setState(() {
              _flashcards[index]['pronunciation'] = pronunciation.trim();
            });
          }
        }
      }
    } catch (e) {
      // 에러는 무시 (발음기호가 없어도 학습은 계속 가능)
      print('발음기호 가져오기 실패: $word - $e');
    }
  }

  Widget _buildBackCard(String word, Map<String, dynamic> meaning, Map<String, dynamic> flashcardData) {
    final starCount = _starCounts[word] ?? 0;
    final pronunciation = flashcardData['pronunciation'] as String?;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: constraints.maxHeight > 0 ? constraints.maxHeight : null,
              padding: const EdgeInsets.all(48), // 앞면과 동일한 padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 단어 표시 (제일 위)
                    Text(
                      word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    // 발음기호 표시 (단어 아래)
                    if (pronunciation != null && pronunciation.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        pronunciation.trim(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Definition
                    if (meaning['definition'] != null) ...[
                      Text(
                        '정의',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDefinitionContent(context, meaning['definition']),
                      if (meaning['examples'] != null) const SizedBox(height: 24),
                    ],
                    // Examples
                    if (meaning['examples'] != null) ...[
                      Text(
                        '예문',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildExampleContent(context, meaning['examples']),
                    ],
                  ],
                ),
              ),
            ),
            // 별 표시 (우측 상단)
            if (starCount > 0)
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(starCount.clamp(0, 2), (index) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 28,
                      ),
                    );
                  }),
                ),
              ),
            // 수정 버튼 (우측 상단)
            Positioned(
              top: 16,
              right: starCount > 0 ? 64 : 16, // 별이 있으면 오른쪽으로 더 이동
              child: FloatingActionButton(
                mini: true,
                onPressed: () => _showEditDialog(word, meaning),
                backgroundColor: const Color(0xFF6366F1),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
            // 스피커 아이콘 (우측 하단)
            Positioned(
              bottom: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _speakWord(word),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                    color: const Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_flashcards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('단어 공부'),
        ),
        body: const Center(
          child: Text('학습할 단어가 없습니다.'),
        ),
      );
    }

    final currentFlashcard = _flashcards[_currentIndex];
    final word = currentFlashcard['word'] as String;
    final meaning = currentFlashcard['meaning'] as Map<String, dynamic>? ?? {};
    
    // 발음기호가 플래시카드 데이터에 없으면 words 컬렉션에서 가져오기
    if (currentFlashcard['pronunciation'] == null || 
        (currentFlashcard['pronunciation'] as String?).toString().trim().isEmpty) {
      // 백그라운드에서 발음기호 가져오기 (비동기)
      _loadPronunciationIfNeeded(word, _currentIndex);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('단어 공부 (${_currentIndex + 1}/${_flashcards.length})'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 진행 표시줄
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _flashcards.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ),
            ),
            // Flashcard
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _flipCard,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_flipAnimation, _slideAnimation]),
                          builder: (context, child) {
                            final angle = _flipAnimation.value * 3.14159; // π
                            final isFront = (_flipAnimation.value < 0.5);
                            
                            // 슬라이드 애니메이션 적용
                            return SlideTransition(
                              position: _slideAnimation,
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: isFront
                                    ? _buildFrontCard(word)
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..rotateY(3.14159), // 180도 뒤집기
                                        child: _buildBackCard(word, meaning, currentFlashcard),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // 난이도 선택 버튼
                    const SizedBox(height: 16),
                    _buildDifficultySelector(),
                  ],
                ),
              ),
            ),
            // 네비게이션 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentIndex > 0 ? _previousWord : null,
                    color: _currentIndex > 0 ? const Color(0xFF6366F1) : Colors.grey,
                  ),
                  ElevatedButton(
                    onPressed: _addStar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.thumb_up, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Good Job!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _flashcards.isNotEmpty ? _nextWord : null,
                    color: _flashcards.isNotEmpty ? const Color(0xFF6366F1) : Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // TTS가 초기화되었을 때만 정리
    if (_isTtsInitialized && _flutterTts != null) {
      try {
        _flutterTts!.stop();
      } catch (e) {
        print('TTS 정리 중 오류: $e');
      }
    }
    _flipController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
