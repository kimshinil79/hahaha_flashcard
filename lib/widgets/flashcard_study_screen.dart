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
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<int> _viewedIndices = {}; // 본 단어 인덱스 추적
  late List<Map<String, dynamic>> _flashcards; // 로컬 복사본
  bool _isFlipped = false; // 카드가 뒤집혔는지 여부
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

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

    // 첫 번째 단어를 볼 때 viewCount 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateViewCount(0);
    });
  }

  Future<void> _updateViewCount(int index) async {
    if (_viewedIndices.contains(index)) return; // 이미 본 단어는 제외

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final flashcard = _flashcards[index];
    final word = flashcard['word'] as String;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final flashcards = (userData['flashcards'] as List<dynamic>?) ?? [];

      // 해당 단어 찾아서 viewCount 증가
      for (int i = 0; i < flashcards.length; i++) {
        final card = flashcards[i] as Map<String, dynamic>;
        if (card['word'] == word) {
          final currentViewCount = card['viewCount'] as int? ?? 0;
          card['viewCount'] = currentViewCount + 1;
          flashcards[i] = card;

          // Firestore 업데이트
          await userDocRef.set({
            'flashcards': flashcards,
          }, SetOptions(merge: true));

          // 로컬 상태 업데이트
          if (mounted) {
            setState(() {
              _flashcards[index]['viewCount'] = currentViewCount + 1;
              _viewedIndices.add(index);
            });
          }
          break;
        }
      }
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
    if (_currentIndex < _flashcards.length - 1) {
      // 현재 단어의 viewCount 업데이트
      _updateViewCount(_currentIndex);

      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _flipController.reset();
      });

      // 다음 단어의 viewCount도 업데이트 (현재 보고 있는 단어)
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateViewCount(_currentIndex);
      });
    }
  }

  void _previousWord() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
        _flipController.reset();
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
    return Container(
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
    );
  }

  Widget _buildBackCard(Map<String, dynamic> meaning) {
    return Container(
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
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * 3.14159; // π
                      final isFront = (_flipAnimation.value < 0.5);

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: isFront
                            ? _buildFrontCard(word)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(3.14159), // 180도 뒤집기
                                child: _buildBackCard(meaning),
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
                  TextButton(
                    onPressed: _flipCard,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFlipped ? Icons.refresh : Icons.flip,
                          color: const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isFlipped ? '다시 뒤집기' : '카드 뒤집기',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentIndex < _flashcards.length - 1 ? _nextWord : null,
                    color: _currentIndex < _flashcards.length - 1 ? const Color(0xFF6366F1) : Colors.grey,
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
    super.dispose();
  }
}
