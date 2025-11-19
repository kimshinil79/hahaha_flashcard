import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WordSearchDialog extends StatefulWidget {
  const WordSearchDialog({super.key});

  @override
  State<WordSearchDialog> createState() => _WordSearchDialogState();
}

class _WordSearchDialogState extends State<WordSearchDialog> {
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
      } else {
        setState(() {
          _searchResult = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${word.trim()}" 단어를 찾을 수 없습니다.')),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '단어 검색',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          letterSpacing: -0.3,
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
            // 검색 입력창
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSearching
                              ? null
                              : () {
                                  _searchWord(_searchController.text);
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: _isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
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
            ),
            // 검색 결과
            if (_searchResult != null && _searchResult!['meanings'] != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentWord != null) ...[
                        Text(
                          _currentWord!,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: const Color(0xFF6366F1),
                              ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...(_searchResult!['meanings'] as List).asMap().entries.map((entry) {
                        final index = entry.key;
                        final meaning = entry.value as Map<String, dynamic>;
                        
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < (_searchResult!['meanings'] as List).length - 1 ? 16 : 0,
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
                                if (meaning['definition'] != null) ...[
                                  _buildDefinitionContent(meaning['definition']),
                                  if (meaning['examples'] != null) const SizedBox(height: 16),
                                ],
                                if (meaning['examples'] != null) ...[
                                  _buildExampleContent(meaning['examples']),
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
          ],
        ),
      ),
    );
  }
}

