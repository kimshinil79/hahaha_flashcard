import 'dart:async';
import 'package:flutter/material.dart';

class RecognizedTextDisplay extends StatefulWidget {
  final String recognizedText;
  final Function(String selectedText) onWordSelected;
  final VoidCallback onClose;

  const RecognizedTextDisplay({
    super.key,
    required this.recognizedText,
    required this.onWordSelected,
    required this.onClose,
  });

  @override
  State<RecognizedTextDisplay> createState() => _RecognizedTextDisplayState();
}

class _RecognizedTextDisplayState extends State<RecognizedTextDisplay> {
  double _fontSize = 15.0;
  static const double _minFontSize = 10.0;
  static const double _maxFontSize = 24.0;
  static const double _fontSizeStep = 1.0;
  final ScrollController _scrollController = ScrollController();
  Timer? _selectionTimer;
  TextSelection? _lastSelection;

  // 선택된 위치를 기반으로 전체 단어를 추출하는 함수
  String _extractWordAtPosition(String text, int start, int end) {
    if (text.isEmpty || start < 0 || end > text.length || start >= end) {
      return '';
    }

    // 단어 문자인지 확인하는 함수
    bool isWordChar(String char) {
      if (char.isEmpty) return false;
      return RegExp(r'[a-zA-Z0-9]').hasMatch(char);
    }

    // 선택된 범위 내에서 단어 문자 찾기
    int searchPosition = -1;
    
    // 먼저 centerPosition 확인
    final centerPosition = (start + end) ~/ 2;
    if (centerPosition < text.length && isWordChar(text[centerPosition])) {
      searchPosition = centerPosition;
    } else {
      // centerPosition이 단어 문자가 아니면, 선택 범위 내에서 가장 가까운 단어 문자 찾기
      // centerPosition에서 양쪽으로 확장하며 검색
      int offset = 0;
      while (searchPosition == -1 && (centerPosition + offset < end || centerPosition - offset >= start)) {
        // 앞으로 검색
        if (centerPosition + offset < end && centerPosition + offset < text.length) {
          if (isWordChar(text[centerPosition + offset])) {
            searchPosition = centerPosition + offset;
            break;
          }
        }
        
        // 뒤로 검색
        if (centerPosition - offset >= start && centerPosition - offset >= 0) {
          if (isWordChar(text[centerPosition - offset])) {
            searchPosition = centerPosition - offset;
            break;
          }
        }
        
        offset++;
      }
    }
    
    // 선택 범위 내에 단어 문자가 없으면 빈 문자열 반환
    if (searchPosition == -1) {
      return '';
    }

    // 선택된 위치에서 앞으로 가며 단어의 시작 위치 찾기
    int wordStart = searchPosition;
    while (wordStart > 0 && isWordChar(text[wordStart - 1])) {
      wordStart--;
    }

    // 선택된 위치에서 뒤로 가며 단어의 끝 위치 찾기
    int wordEnd = searchPosition;
    while (wordEnd < text.length && isWordChar(text[wordEnd])) {
      wordEnd++;
    }

    // 단어 추출
    if (wordStart < wordEnd) {
      return text.substring(wordStart, wordEnd);
    }

    return '';
  }

  void _increaseFontSize() {
    setState(() {
      if (_fontSize < _maxFontSize) {
        _fontSize = (_fontSize + _fontSizeStep).clamp(_minFontSize, _maxFontSize);
      }
    });
  }

  void _decreaseFontSize() {
    setState(() {
      if (_fontSize > _minFontSize) {
        _fontSize = (_fontSize - _fontSizeStep).clamp(_minFontSize, _maxFontSize);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF6366F1).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 헤더 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                // 닫기 버튼
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: '닫기',
                    onPressed: widget.onClose,
                    color: Colors.grey.shade700,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 12),
                // 제목
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '인식된 텍스트',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '단어를 길게 눌러 선택하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // 폰트 크기 조절 버튼
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.1),
                        const Color(0xFF8B5CF6).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _decreaseFontSize,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(),
                        color: const Color(0xFF6366F1),
                        tooltip: '폰트 크기 줄이기',
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${_fontSize.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _increaseFontSize,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(),
                        color: const Color(0xFF6366F1),
                        tooltip: '폰트 크기 키우기',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 구분선
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF6366F1).withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // 스크롤 가능한 본문
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: SelectableText.rich(
                TextSpan(
                  text: widget.recognizedText,
                  style: TextStyle(
                    fontSize: _fontSize,
                    height: 1.8, // 줄 간격 증가
                    letterSpacing: 0.3, // 자간
                    wordSpacing: 1.5, // 단어 간격
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                textAlign: TextAlign.justify,
                textDirection: TextDirection.ltr,
                selectionControls: MaterialTextSelectionControls(),
                onSelectionChanged: (selection, cause) {
                  // 이전 타이머 취소
                  _selectionTimer?.cancel();
                  
                  // 선택이 유효하고 비어있지 않으면 타이머 시작
                  if (selection.isValid && !selection.isCollapsed) {
                    _lastSelection = selection;
                    // 500ms 후에 선택이 완료된 것으로 간주
                    _selectionTimer = Timer(const Duration(milliseconds: 500), () {
                      if (mounted && _lastSelection != null && 
                          _lastSelection!.isValid && !_lastSelection!.isCollapsed) {
                        // 선택된 위치를 기반으로 전체 단어 추출
                        final word = _extractWordAtPosition(
                          widget.recognizedText,
                          _lastSelection!.start,
                          _lastSelection!.end,
                        );
                        if (word.isNotEmpty) {
                          widget.onWordSelected(word);
                        }
                        _lastSelection = null;
                      }
                    });
                  } else {
                    _lastSelection = null;
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _selectionTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

