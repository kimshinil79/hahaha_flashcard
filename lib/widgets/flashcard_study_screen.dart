import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final List<Map<String, dynamic>> flashcards;

  const FlashcardStudyScreen({
    super.key,
    required this.flashcards,
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
  
  // 슬라이드 애니메이션
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 로컬 복사본 생성
    _flashcards = widget.flashcards.map((f) => Map<String, dynamic>.from(f)).toList();
    
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

    // 모든 단어의 별 개수를 0으로 초기화
    for (var flashcard in _flashcards) {
      final word = flashcard['word'] as String;
      _starCounts[word] = 0;
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

      // 모든 단어의 viewCount 증가
      for (int i = 0; i < flashcards.length; i++) {
        final card = flashcards[i] as Map<String, dynamic>;
        final word = card['word'] as String;
        
        // 별 2개를 받은 단어만 viewCount 증가
        if (_starCounts[word] == 2) {
          final currentViewCount = card['viewCount'] as int? ?? 0;
          card['viewCount'] = currentViewCount + 1;
          flashcards[i] = card;
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
  }

  void _addStar() {
    final currentFlashcard = _flashcards[_currentIndex];
    final word = currentFlashcard['word'] as String;
    final currentStars = _starCounts[word] ?? 0;

    if (currentStars < 2) {
      setState(() {
        _starCounts[word] = currentStars + 1;
      });

      // 별 2개를 받은 카드는 목록에서 제거
      if (_starCounts[word] == 2) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _flashcards.removeAt(_currentIndex);
              
              // 인덱스 조정 (제거된 카드가 마지막이었으면 처음으로)
              if (_currentIndex >= _flashcards.length && _flashcards.isNotEmpty) {
                _currentIndex = 0;
              } else if (_currentIndex >= _flashcards.length) {
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
  }

  Future<void> _onStudyComplete() async {
    // 모든 단어의 viewCount 업데이트
    await _updateAllViewCounts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('공부를 완료했습니다! 🎉'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // 잠시 후 이전 화면으로 돌아가기
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
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

  Widget _buildFrontCard(String word) {
    final starCount = _starCounts[word] ?? 0;
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
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
              children: List.generate(starCount, (index) {
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
      ],
    );
  }

  Widget _buildBackCard(String word, Map<String, dynamic> meaning) {
    final starCount = _starCounts[word] ?? 0;
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
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
              children: [
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
              children: List.generate(starCount, (index) {
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
      ],
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
                                  child: _buildBackCard(word, meaning),
                                ),
                        ),
                      );
                    },
                  ),
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
    _flipController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
