import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'word_detail_dialog.dart';

class FlashcardListDialog extends StatelessWidget {
  const FlashcardListDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const FlashcardListDialog(),
      barrierDismissible: true,
    );
  }

  /// viewCount에 따라 단일 색상 그레디언트 진하기를 반환
  /// 공부한 횟수가 많을수록 진한 색상
  Color _getGradientStartColor(int viewCount, int maxViewCount) {
    // 최대 viewCount를 기준으로 0~1 사이의 비율 계산
    final ratio = maxViewCount > 0 
        ? (viewCount / maxViewCount).clamp(0.0, 1.0) 
        : 0.0;
    
    // 보라색 계열로 단일 색상 사용 (진하기만 조절)
    // ratio가 0 (공부 안 함) -> 매우 연한 회색
    // ratio가 높을수록 (많이 공부함) -> 진한 보라색
    if (ratio == 0) {
      return Colors.grey.shade200; // 공부 안 함: 매우 연한 회색
    } else if (ratio <= 0.2) {
      return const Color(0xFFE0D5FF); // 연한 보라색
    } else if (ratio <= 0.4) {
      return const Color(0xFFC4B5FD); // 중간 연한 보라색
    } else if (ratio <= 0.6) {
      return const Color(0xFFA78BFA); // 중간 보라색
    } else if (ratio <= 0.8) {
      return const Color(0xFF8B5CF6); // 진한 보라색
    } else {
      return const Color(0xFF6366F1); // 매우 진한 보라색
    }
  }

  Color _getGradientEndColor(int viewCount, int maxViewCount) {
    // 시작 색상보다 약간 더 진한 색상
    final ratio = maxViewCount > 0 
        ? (viewCount / maxViewCount).clamp(0.0, 1.0) 
        : 0.0;
    
    if (ratio == 0) {
      return Colors.grey.shade300;
    } else if (ratio <= 0.2) {
      return const Color(0xFFC4B5FD);
    } else if (ratio <= 0.4) {
      return const Color(0xFFA78BFA);
    } else if (ratio <= 0.6) {
      return const Color(0xFF8B5CF6);
    } else if (ratio <= 0.8) {
      return const Color(0xFF7C3AED);
    } else {
      return const Color(0xFF5B21B6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '단어장',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 단어 목록
            Expanded(
              child: user == null
                  ? const Center(
                      child: Text('로그인이 필요합니다.'),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: firestore
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        final flashcards = (userData?['flashcards'] as List<dynamic>? ?? [])
                            .map((item) => item as Map<String, dynamic>)
                            .toList();

                        if (flashcards.isEmpty) {
                          return const Center(
                            child: Text('저장된 단어가 없습니다.'),
                          );
                        }

                        // viewCount로 정렬 (가장 적게 공부한 순서, 오름차순)
                        flashcards.sort((a, b) {
                          final viewCountA = a['viewCount'] as int? ?? 0;
                          final viewCountB = b['viewCount'] as int? ?? 0;
                          return viewCountA.compareTo(viewCountB);
                        });

                        // 최대 viewCount 계산 (그레디언트 진하기 기준점)
                        final maxViewCount = flashcards.fold<int>(
                          0,
                          (max, flashcard) {
                            final viewCount = flashcard['viewCount'] as int? ?? 0;
                            return viewCount > max ? viewCount : max;
                          },
                        );

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: flashcards.length,
                          itemBuilder: (context, index) {
                            final flashcard = flashcards[index];
                            final word = flashcard['word'] as String? ?? '';
                            final viewCount = flashcard['viewCount'] as int? ?? 0;

                            return GestureDetector(
                              onTap: () => _showWordDetail(context, word, flashcard),
                              child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _getGradientStartColor(viewCount, maxViewCount),
                                    _getGradientEndColor(viewCount, maxViewCount),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    word,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.visibility,
                                        size: 12,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$viewCount',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 단어 상세 정보를 표시하는 함수
  Future<void> _showWordDetail(
    BuildContext context,
    String word,
    Map<String, dynamic> flashcard,
  ) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // words 컬렉션에서 단어 정보 가져오기
      final wordDoc = await firestore.collection('words').doc(word.toLowerCase()).get();
      
      if (wordDoc.exists) {
        final wordData = wordDoc.data();
        if (wordData != null) {
          // WordDetailDialog 표시
          await WordDetailDialog.show(
            context,
            wordData,
            '', // 문장 없음
            word,
            word.toLowerCase(),
            onMeaningSelected: null, // 단어장에서는 선택 기능 없음
          );
          return;
        }
      }
      
      // words 컬렉션에 없으면 플래시카드의 meaning을 사용해서 표시
      final meaning = flashcard['meaning'] as Map<String, dynamic>?;
      if (meaning != null) {
        // 플래시카드의 meaning을 words 컬렉션 형식으로 변환
        final wordData = {
          'word': word,
          'meanings': [meaning],
          'pos': meaning['pos'] as List<dynamic>? ?? [],
          if (flashcard['pronunciation'] != null) 
            'pronunciation': flashcard['pronunciation'],
        };
        
        await WordDetailDialog.show(
          context,
          wordData,
          '',
          word,
          word.toLowerCase(),
          onMeaningSelected: null,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$word" 단어 정보를 찾을 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 정보를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
      print('단어 상세 정보 표시 오류: $e');
    }
  }
}

