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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 글씨 크기 조절 버튼 (고정 위치)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '닫기',
                onPressed: widget.onClose,
                color: Colors.grey.shade600,
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _decreaseFontSize,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      color: Colors.grey.shade700,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.grey.shade300,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _increaseFontSize,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 스크롤 가능한 본문 (나머지 공간 모두 사용)
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SelectableText.rich(
                TextSpan(
                  text: widget.recognizedText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        fontSize: _fontSize,
                        color: Colors.grey.shade800,
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

