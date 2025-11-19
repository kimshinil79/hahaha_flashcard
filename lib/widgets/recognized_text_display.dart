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
                        final selectedText = widget.recognizedText.substring(
                          _lastSelection!.start,
                          _lastSelection!.end,
                        );
                        // 선택된 텍스트에서 단어만 추출 (공백, 구두점 제거)
                        final word = selectedText.trim().split(RegExp(r'[\s\p{P}]')).firstWhere(
                          (w) => w.isNotEmpty,
                          orElse: () => '',
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

