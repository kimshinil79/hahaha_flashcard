import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'widgets/camera_screen.dart';
import 'widgets/camera_view_page.dart';
import 'widgets/searching_words.dart';
import 'widgets/login_screen.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HaHaHa Flashcard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF6366F1), // 인디고
          secondary: const Color(0xFF8B5CF6), // 퍼플
          tertiary: const Color(0xFFEC4899), // 핑크
          surface: Colors.white,
          background: const Color(0xFFF8FAFC), // 매우 연한 회색 배경
          error: const Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF1E293B), // 진한 슬레이트
          onBackground: const Color(0xFF1E293B),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: const Color(0xFF1E293B),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200.withOpacity(0.5), width: 1),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
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
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: AuthWrapper(cameras: cameras),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final List<CameraDescription> cameras;

  const AuthWrapper({super.key, required this.cameras});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 로그인 상태 확인
        if (snapshot.hasData && snapshot.data != null) {
          // 로그인 되어 있으면 메인 화면
          return MyHomePage(title: 'HaHaHa Flashcard', cameras: widget.cameras);
        } else {
          // 로그인 안 되어 있으면 로그인 화면
          return const LoginScreen();
        }
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});

  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _recognizedText;
  Offset? _fabOffset; // Stored relative to SafeArea coordinates
  bool _isDragging = false;
  static const double _fabSize = 56.0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _selectedWordData;
  Map<String, String>? _irregularWordsMap;

  @override
  void initState() {
    super.initState();
    _loadIrregularWords();
  }

  Future<void> _loadIrregularWords() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/irregular_words.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        _irregularWordsMap = jsonData.map((key, value) => MapEntry(key.toLowerCase(), value.toString().toLowerCase()));
      });
    } catch (e) {
      print('불규칙 단어 파일 로드 실패: $e');
      _irregularWordsMap = {};
    }
  }

  Future<void> _takePicture() async {
    if (widget.cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라를 사용할 수 없습니다.')),
      );
      return;
    }

    // 카메라 화면으로 이동
    if (!mounted) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(camera: widget.cameras.first),
      ),
    );

    // await 후 mounted 체크
    if (!mounted) return;

    if (result != null && result is String) {
      setState(() {
        _recognizedText = null;
      });
      
      // 사진 촬영 모드로 이동
      final cropResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraViewPage(imagePath: result),
        ),
      );

      // await 후 mounted 체크
      if (!mounted) return;

      if (cropResult is Map<String, dynamic>) {
        final extractedText = cropResult['text'] as String?;

        setState(() {
          if (extractedText != null && extractedText.trim().isNotEmpty) {
            _recognizedText = extractedText.trim();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: '로그아웃',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      extendBody: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeWidth = constraints.maxWidth;
            final safeHeight = constraints.maxHeight;
            final defaultOffset = Offset(
              safeWidth - _fabSize - 24,
              safeHeight - _fabSize - 24,
            );
            final fabOffset = _fabOffset ?? defaultOffset;

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SearchingWords(),
                        const SizedBox(height: 32),
                        // 선택된 단어 카드
                        if (_selectedWordData != null && _selectedWordData!['meanings'] != null) ...[
                          _buildWordCard(_selectedWordData!),
                          const SizedBox(height: 24),
                        ],
                        if (_recognizedText != null &&
                            _recognizedText!.isNotEmpty) ...[
                          Container(
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
                                Text(
                                  '인식된 텍스트',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Builder(
                                  builder: (context) {
                                    return GestureDetector(
                                      onDoubleTapDown: (details) async {
                                        await _handleWordDoubleTap(context, details, _recognizedText!);
                                      },
                                      child: SelectableText(
                                        _recognizedText!,
                                        textAlign: TextAlign.justify,
                                        textDirection: TextDirection.ltr,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              height: 1.6,
                                              fontSize: 15,
                                              color: Colors.grey.shade800,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_recognizedText == null) ...[
                          const SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '카메라 버튼을 눌러\n사진을 찍고 텍스트를 추출해보세요',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey.shade600,
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: fabOffset.dx,
                  top: fabOffset.dy,
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() => _isDragging = true);
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _isDragging = true;
                        final minX = 16.0;
                        final maxX = safeWidth - _fabSize - 16.0;
                        final minY = 16.0;
                        final maxY = safeHeight - _fabSize - 16.0;

                        final current = _fabOffset ?? fabOffset;
                        final newDx =
                            (current.dx + details.delta.dx).clamp(minX, maxX);
                        final newDy =
                            (current.dy + details.delta.dy).clamp(minY, maxY);
                        _fabOffset = Offset(newDx, newDy);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() => _isDragging = false);
                    },
                    child: Container(
                      width: _fabSize,
                      height: _fabSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1), // 인디고
                            Color(0xFF8B5CF6), // 퍼플
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isDragging ? null : _takePicture,
                          borderRadius: BorderRadius.circular(_fabSize / 2),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getWordAtPosition(BuildContext context, TapDownDetails details, String text) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return '';

    // 텍스트의 위치를 계산하여 단어 추출
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
      ),
      textAlign: TextAlign.justify,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(maxWidth: box.size.width);

    final localPosition = box.globalToLocal(details.globalPosition);
    final offset = textPainter.getPositionForOffset(localPosition);
    final textOffset = offset.offset;

    // 텍스트에서 해당 위치의 단어 추출
    if (textOffset >= 0 && textOffset < text.length) {
      int start = textOffset;
      int end = textOffset;

      // 단어의 시작 위치 찾기
      while (start > 0 && _isWordChar(text[start - 1])) {
        start--;
      }

      // 단어의 끝 위치 찾기
      while (end < text.length && _isWordChar(text[end])) {
        end++;
      }

      if (start < end) {
        return text.substring(start, end);
      }
    }

    return '';
  }

  bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    return RegExp(r'[a-zA-Z0-9]').hasMatch(char) || char == "'";
  }

  String _getWordBaseForm(String word) {
    if (word.isEmpty) return word;

    String base = word.toLowerCase().trim();
    
    // 특수문자 제거 (앞뒤)
    base = base.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '');
    
    // 먼저 불규칙 단어 사전에서 찾기
    if (_irregularWordsMap != null && _irregularWordsMap!.containsKey(base)) {
      return _irregularWordsMap![base]!;
    }
    
    if (base.length < 3) return base;

    // 복수형 처리
    if (base.endsWith('ies') && base.length > 3) {
      return base.substring(0, base.length - 3) + 'y';
    }
    if (base.endsWith('es') && base.length > 2) {
      // boxes -> box, catches -> catch
      final beforeEs = base.substring(0, base.length - 2);
      if (beforeEs.endsWith('ch') || beforeEs.endsWith('sh') || 
          beforeEs.endsWith('x') || beforeEs.endsWith('s') || beforeEs.endsWith('z')) {
        return beforeEs;
      }
    }
    if (base.endsWith('s') && !base.endsWith('ss') && base.length > 1) {
      base = base.substring(0, base.length - 1);
    }

    // 과거형 처리
    if (base.endsWith('ied') && base.length > 3) {
      return base.substring(0, base.length - 3) + 'y';
    }
    if (base.endsWith('ed') && base.length > 2) {
      final beforeEd = base.substring(0, base.length - 2);
      // doubled -> double (e로 끝나는 경우)
      if (beforeEd.endsWith('e')) {
        return beforeEd;
      }
      // stopped -> stop (자음이 두 번 반복되는 경우)
      if (beforeEd.length > 1 && 
          _isConsonant(beforeEd[beforeEd.length - 1]) &&
          beforeEd[beforeEd.length - 1] == beforeEd[beforeEd.length - 2]) {
        return beforeEd.substring(0, beforeEd.length - 1);
      }
      return beforeEd;
    }

    // 진행형 처리
    if (base.endsWith('ying') && base.length > 4) {
      return base.substring(0, base.length - 4) + 'y';
    }
    if (base.endsWith('ing') && base.length > 3) {
      final beforeIng = base.substring(0, base.length - 3);
      // coming -> come (e로 끝나는 경우)
      if (beforeIng.endsWith('e')) {
        return beforeIng;
      }
      // running -> run (자음이 두 번 반복되는 경우)
      if (beforeIng.length > 1 && 
          _isConsonant(beforeIng[beforeIng.length - 1]) &&
          beforeIng[beforeIng.length - 1] == beforeIng[beforeIng.length - 2]) {
        return beforeIng.substring(0, beforeIng.length - 1);
      }
      return beforeIng;
    }

    // 비교급/최상급
    if (base.endsWith('iest') && base.length > 4) {
      return base.substring(0, base.length - 4) + 'y';
    }
    if (base.endsWith('est') && base.length > 3) {
      final beforeEst = base.substring(0, base.length - 3);
      if (beforeEst.endsWith('e')) {
        return beforeEst;
      }
      return beforeEst;
    }
    if (base.endsWith('ier') && base.length > 3) {
      return base.substring(0, base.length - 3) + 'y';
    }
    if (base.endsWith('er') && base.length > 2) {
      final beforeEr = base.substring(0, base.length - 2);
      if (beforeEr.endsWith('e')) {
        return beforeEr;
      }
      return beforeEr;
    }

    return base;
  }

  bool _isConsonant(String char) {
    return !RegExp(r'[aeiouAEIOU]').hasMatch(char);
  }

  Future<void> _handleWordDoubleTap(BuildContext context, TapDownDetails details, String text) async {
    final word = _getWordAtPosition(context, details, text);
    if (word.isEmpty) return;

    final baseForm = _getWordBaseForm(word);
    print('선택된 단어: $word, 원형: $baseForm');

    try {
      // 원형으로 먼저 검색
      var docRef = _firestore.collection('words').doc(baseForm);
      var docSnapshot = await docRef.get();

      // 원형으로 찾지 못하면 원래 단어로도 시도
      if (!docSnapshot.exists && baseForm != word.toLowerCase()) {
        docRef = _firestore.collection('words').doc(word.toLowerCase());
        docSnapshot = await docRef.get();
      }

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (mounted) {
          setState(() {
            _selectedWordData = data;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedWordData = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$word" 단어를 찾을 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _buildWordCard(Map<String, dynamic> wordData) {
    if (wordData['meanings'] == null) return const SizedBox.shrink();

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 닫기 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '단어 검색 결과',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedWordData = null;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // meanings 배열을 순회하며 각 의미 표시
            ...(wordData['meanings'] as List).asMap().entries.map((entry) {
              final index = entry.key;
              final meaning = entry.value as Map<String, dynamic>;
              
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < (wordData['meanings'] as List).length - 1 ? 16 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Definition
                    if (meaning['definition'] != null) ...[
                      _buildDefinitionContent(meaning['definition']),
                      if (meaning['examples'] != null) const SizedBox(height: 16),
                    ],
                    // Examples
                    if (meaning['examples'] != null) ...[
                      _buildExampleContent(meaning['examples']),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
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
}

