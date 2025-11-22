import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'widgets/camera_screen.dart';
import 'widgets/camera_view_page.dart';
import 'widgets/login_screen.dart';
import 'widgets/recognized_text_display.dart';
import 'widgets/word_detail_dialog.dart';
import 'widgets/word_search_dialog.dart';
import 'widgets/selected_word_list.dart';
import 'widgets/add_to_flashcard_dialog.dart';
import 'widgets/flashcard_study_screen.dart';
import 'widgets/study_calendar_widget.dart';
import 'widgets/word_addition_chart.dart';
import 'services/chatgpt_service.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env 파일 로드
  await dotenv.load(fileName: ".env");
  
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
  Map<String, String>? _irregularWordsMap;
  // 선택된 단어와 뜻 정보 저장 (리스트로 관리)
  List<Map<String, dynamic>> _selectedWordMeanings = [];
  // 학습할 단어 목록 (viewCount 낮은 순)
  List<Map<String, dynamic>> _studyFlashcards = [];
  bool _isLoadingFlashcards = false;
  int _calendarRefreshKey = 0;
  StreamSubscription? _intentDataStreamSubscription;
  static const Map<String, Duration> _difficultyIntervals = {
    'easy': Duration(days: 5),
    'normal': Duration(days: 3),
    'hard': Duration(days: 1),
  };

  Duration _getDifficultyInterval(String? difficulty) {
    return _difficultyIntervals[difficulty] ?? const Duration(days: 3);
  }

  DateTime _computeDueDate(Map<String, dynamic> flashcard) {
    final lastStudiedTimestamp = flashcard['lastStudiedAt'] as Timestamp?;
    final lastStudied = lastStudiedTimestamp?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final interval = _getDifficultyInterval(flashcard['difficulty'] as String?);
    return lastStudied.add(interval);
  }

  static const MethodChannel _channel = MethodChannel('com.example.hahaha_flashcard/text');

  @override
  void initState() {
    super.initState();
    _loadIrregularWords();
    _printCurrentUserDocumentId();
    _loadStudyFlashcards();
    _listenToSharedImages();
    _listenToSharedText();
  }

  void _listenToSharedImages() {
    // 공유된 이미지를 받는 스트림 구독
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty && value[0].path.isNotEmpty) {
        _handleSharedImage(value[0].path);
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // 앱 시작 시 이미 공유된 이미지가 있는지 확인
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty && value[0].path.isNotEmpty) {
        _handleSharedImage(value[0].path);
      }
    });
  }

  void _listenToSharedText() {
    // 플랫폼 채널을 통해 텍스트 수신
    _channel.setMethodCallHandler((call) async {
      if (call.method == "processText" && call.arguments != null) {
        final text = call.arguments as String;
        if (text.trim().isNotEmpty) {
          _handleSharedText(text.trim());
        }
      }
    });
  }

  Future<void> _handleSharedText(String text) async {
    if (text.isEmpty) return;

    // 텍스트에서 단어 추출 (공백으로 분리, 첫 번째 단어 사용)
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return;

    // 첫 번째 단어를 검색
    final word = words[0].trim();
    if (word.isEmpty) return;

    // 특수문자 제거 (알파벳과 숫자만)
    final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleanWord.isEmpty) return;

    if (!mounted) return;

    // 단어 검색 실행
    final baseForm = _getWordBaseForm(cleanWord);
    await _searchWordFromExternal(cleanWord, baseForm);
  }

  Future<void> _addPronunciationToWords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    // 진행 상황을 보여주는 다이얼로그
    if (!mounted) return;
    
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return const _PronunciationProgressDialog();
      },
    );

    try {
      // 전체 단어 개수 추정 (최대한 정확하게 계산하기 어려우므로 대략적인 추정)
      // 실제로는 배치를 처리하면서 추적
      
      int processedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;
      final startTime = DateTime.now();
      Duration? lastDelay = const Duration(milliseconds: 500); // 초기 딜레이: 500ms
      
      // 페이징 처리를 위한 설정
      const int batchSize = 50; // 한 번에 처리할 단어 수 (메모리 절약)
      DocumentSnapshot? lastDoc; // 마지막으로 처리한 문서 (페이징용)
      bool hasMore = true;
      
      while (hasMore && mounted) {
        // 배치 단위로 단어 가져오기 (메모리 절약)
        QuerySnapshot wordsSnapshot;
        if (lastDoc == null) {
          // 첫 번째 배치
          wordsSnapshot = await _firestore
              .collection('words')
              .limit(batchSize)
              .get();
        } else {
          // 다음 배치 (커서 기반 페이징)
          wordsSnapshot = await _firestore
              .collection('words')
              .startAfterDocument(lastDoc)
              .limit(batchSize)
              .get();
        }
        
        final words = wordsSnapshot.docs;
        
        // 더 이상 가져올 단어가 없으면 종료
        if (words.isEmpty) {
          hasMore = false;
          break;
        }
        
        // 마지막 문서 저장 (다음 배치를 위한 커서)
        lastDoc = words.last;
        
        // 이번 배치의 단어 수가 batchSize보다 적으면 마지막 배치
        if (words.length < batchSize) {
          hasMore = false;
        }
        
        // 배치 내의 각 단어 처리
        for (var doc in words) {
          if (!mounted) {
            hasMore = false;
            break;
          }
          
          final wordData = doc.data() as Map<String, dynamic>;
          final word = doc.id;
          
          // 이미 발음기호가 있는 단어는 스킵
          if (wordData['pronunciation'] != null && 
              (wordData['pronunciation'] as String).trim().isNotEmpty) {
            skippedCount++;
            processedCount++;
            continue;
          }

          try {
            final wordStartTime = DateTime.now();
            
            // ChatGPT API로 발음기호 가져오기
            final pronunciation = await ChatGPTService.getPronunciation(word);
            
            final apiCallTime = DateTime.now().difference(wordStartTime);
            
            if (pronunciation != null && pronunciation.trim().isNotEmpty) {
              try {
                // Firebase에 발음기호 저장
                await doc.reference.update({
                  'pronunciation': pronunciation.trim(),
                });
                updatedCount++;
                print('✅ "$word" 발음기호 추가 완료: $pronunciation (소요시간: ${apiCallTime.inMilliseconds}ms)');
              } catch (saveError) {
                // 발음기호는 가져왔지만 저장 실패한 경우
                errorCount++;
                await _savePronunciationFailure(word, saveError.toString());
                print('❌ 단어 "$word"의 발음기호 저장 실패: $saveError');
              }
            } else {
              // 발음기호를 가져오지 못한 경우
              errorCount++;
              await _savePronunciationFailure(word, '발음기호를 가져올 수 없음 (null 또는 빈 문자열)');
              print('❌ 단어 "$word"의 발음기호를 가져올 수 없음');
            }
            
            // API 호출 시간에 따라 딜레이 조정
            // API 호출이 빠르면(500ms 이하) 딜레이를 늘리고, 느리면(2초 이상) 딜레이를 줄임
            if (apiCallTime.inMilliseconds < 500) {
              // 빠른 응답은 Rate Limit 회피를 위해 딜레이 증가
              lastDelay = const Duration(milliseconds: 800);
            } else if (apiCallTime.inMilliseconds > 2000) {
              // 느린 응답은 이미 자연스러운 딜레이 역할을 하므로 최소 딜레이
              lastDelay = const Duration(milliseconds: 300);
            } else {
              // 적당한 응답 시간은 중간 딜레이
              lastDelay = const Duration(milliseconds: 500);
            }
            
            // API 호출 제한을 피하기 위해 딜레이
            await Future.delayed(lastDelay);
          } catch (e) {
            errorCount++;
            final errorMsg = e.toString();
            
            // Rate Limit 오류 감지
            if (errorMsg.contains('rate limit') || 
                errorMsg.contains('429') ||
                errorMsg.contains('too many requests')) {
              print('⚠️ Rate Limit 감지됨. 10초 대기 후 계속...');
              await Future.delayed(const Duration(seconds: 10));
              lastDelay = const Duration(milliseconds: 1500); // Rate Limit 후 딜레이 증가
            }
            
            // 실패한 단어를 Firebase에 저장
            await _savePronunciationFailure(word, errorMsg);
            
            print('❌ 단어 "$word"의 발음기호 가져오기 실패: $e');
            // 에러가 발생해도 다음 단어로 계속 진행
          }
          
          processedCount++;
          
          // 진행 상황 표시 (콘솔) - 10개마다 또는 배치 처리 후
          if (processedCount % 10 == 0) {
            final elapsed = DateTime.now().difference(startTime);
            
            print('📊 발음기호 추가 진행: $processedCount개 처리됨 '
                '(업데이트: $updatedCount, 스킵: $skippedCount, 오류: $errorCount) '
                '(경과: ${elapsed.inMinutes}분 ${elapsed.inSeconds % 60}초)');
          }
        }
        
        // 배치 처리 후 메모리 정리 힌트 (Garbage Collection)
        // Dart의 GC는 자동이지만, 명시적으로 힌트를 줄 수 있음
        if (processedCount % 100 == 0) {
          // 주기적으로 짧은 딜레이를 두어 GC 시간 확보
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      // 마지막 진행 상황 표시
      if (processedCount > 0) {
        final elapsed = DateTime.now().difference(startTime);
        print('📊 발음기호 추가 완료: 총 $processedCount개 처리됨 '
            '(업데이트: $updatedCount, 스킵: $skippedCount, 오류: $errorCount) '
            '(총 소요 시간: ${elapsed.inMinutes}분 ${elapsed.inSeconds % 60}초)');
      }
      
      final totalTime = DateTime.now().difference(startTime);

      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!).pop(); // 다이얼로그 닫기
        
        final totalMinutes = totalTime.inMinutes;
        final totalSeconds = totalTime.inSeconds % 60;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '완료! 총 $processedCount개 처리 (업데이트: $updatedCount, 스킵: $skippedCount, 오류: $errorCount)\n'
              '총 소요 시간: ${totalMinutes}분 ${totalSeconds}초',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

    } catch (e) {
      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!).pop(); // 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('발음기호 추가 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('발음기호 추가 오류: $e');
    }
  }

  /// 발음기호 저장 실패한 단어를 Firebase에 별도로 저장
  Future<void> _savePronunciationFailure(String word, String errorMessage) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // pronunciation_failures 컬렉션에 실패 정보 저장
      await _firestore.collection('pronunciation_failures').doc(word).set({
        'word': word,
        'error': errorMessage,
        'failedAt': FieldValue.serverTimestamp(),
        'retryCount': 0, // 나중에 재시도 기능 추가 시 사용
      }, SetOptions(merge: true)); // 이미 존재하면 업데이트, 없으면 생성
      
      print('💾 실패한 단어 저장: "$word" - $errorMessage');
    } catch (e) {
      // 실패 저장 자체가 실패해도 메인 프로세스는 계속 진행
      print('⚠️ 실패한 단어 저장 중 오류 발생: $e');
    }
  }

  Future<void> _searchWordFromExternal(String word, String baseForm) async {
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
        if (mounted && data != null) {
          // 사용할 단어 키 결정 (원형 우선, 없으면 원래 단어)
          final wordKey = baseForm.isNotEmpty ? baseForm : word.toLowerCase();
          WordDetailDialog.show(
            context,
            data,
            '', // 외부에서 온 텍스트이므로 문장 없음
            word,
            wordKey,
            onMeaningSelected: (selectedWord, meaning) {
              if (mounted) {
                setState(() {
                  _selectedWordMeanings.add({
                    'word': wordKey,
                    'meaning': meaning,
                  });
                });
              }
            },
          );
        }
      } else {
        // 단어를 찾지 못하면 ChatGPT API 호출
        if (mounted) {
          _fetchWordFromChatGPT(word, '', baseForm);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _handleSharedImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('공유된 이미지 파일이 존재하지 않습니다: $imagePath');
        return;
      }

      // 공유된 이미지를 바로 크롭 화면으로 전달
      if (!mounted) return;

      final cropResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraViewPage(imagePath: imagePath),
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
    } catch (e) {
      print('공유된 이미지 처리 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _loadStudyFlashcards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingFlashcards = true;
    });

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && userDoc.exists) {
        final userData = userDoc.data();
        final flashcards = (userData?['flashcards'] as List<dynamic>?) ?? [];
        final now = DateTime.now();

        final sortedFlashcards = flashcards
            .map((f) => Map<String, dynamic>.from(f as Map<String, dynamic>))
            .toList()
          ..sort((a, b) {
            final dueA = _computeDueDate(a);
            final dueB = _computeDueDate(b);
            final isDueA = now.isAfter(dueA);
            final isDueB = now.isAfter(dueB);

            if (isDueA != isDueB) {
              return isDueA ? -1 : 1;
            }

            final dueComparison = dueA.compareTo(dueB);
            if (dueComparison != 0) {
              return dueComparison;
            }

            final viewCountA = a['viewCount'] as int? ?? 0;
            final viewCountB = b['viewCount'] as int? ?? 0;
            return viewCountA.compareTo(viewCountB);
          });

        if (mounted) {
          setState(() {
            _studyFlashcards = sortedFlashcards.take(10).toList();
            _isLoadingFlashcards = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _studyFlashcards = [];
            _isLoadingFlashcards = false;
          });
        }
      }
    } catch (e) {
      print('학습 단어 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingFlashcards = false;
        });
      }
    }
  }

  void _startStudy() {
    if (_studyFlashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습할 단어가 없습니다.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashcardStudyScreen(
          flashcards: _studyFlashcards,
          onStudyComplete: () {
            // 공부 완료 시 즉시 달력 새로고침
            if (mounted) {
              setState(() {
                _calendarRefreshKey++;
              });
            }
          },
        ),
      ),
    ).then((result) {
      // 공부 화면에서 돌아오면 다시 로드
      _loadStudyFlashcards();
      // 추가로 달력 새로고침 (혹시 놓친 경우 대비)
      if (result == true && mounted) {
        setState(() {
          _calendarRefreshKey++;
        });
      }
    });
  }

  void _clearRecognizedText() {
    setState(() {
      _recognizedText = null;
    });
  }

  void _printCurrentUserDocumentId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('========================================');
      print('현재 로그인한 사용자 문서 ID: ${user.uid}');
      print('현재 로그인한 사용자 이메일: ${user.email ?? 'N/A'}');
      print('========================================');
    } else {
      print('로그인된 사용자가 없습니다.');
    }
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
        title: Image.asset(
          'assets/HaHaHa.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          // TextButton.icon(
          //   onPressed: _addPronunciationToWords,
          //   icon: const Icon(Icons.phonelink_ring, size: 18),
          //   label: const Text(
          //     '발음기호 넣기',
          //     style: TextStyle(fontSize: 12),
          //   ),
          //   style: TextButton.styleFrom(
          //     foregroundColor: const Color(0xFF6366F1),
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //   ),
          // ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const WordSearchDialog(),
              );
            },
            tooltip: '단어 검색',
          ),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_recognizedText == null ||
                            _recognizedText!.isEmpty) ...[
                          // 공부 시작 카드 (고정, 텍스트 추출 전/없을 때만 표시)
                          GestureDetector(
                            onTap: _startStudy,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.school,
                                    color: Color(0xFF6366F1),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '공부 시작',
                                          style: TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isLoadingFlashcards
                                              ? '로딩 중...'
                                              : '${_studyFlashcards.length}개의 단어가 준비되어 있어요',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: const Color(0xFF6366F1).withOpacity(0.8),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 스크롤 가능한 영역 (달력 + 그래프)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  // 달력 위젯
                                  StudyCalendarWidget(
                                    key: ValueKey(_calendarRefreshKey),
                                    refreshTrigger: _calendarRefreshKey,
                                  ),
                                  const SizedBox(height: 20),
                                  // 단어 추가 그래프
                                  const WordAdditionChart(),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_selectedWordMeanings.isNotEmpty) ...[
                          SelectedWordList(
                            selectedWords: _selectedWordMeanings,
                            onRemove: _removeSelectedWord,
                            onAddToFlashcard: _showAddToFlashcardDialog,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_recognizedText != null &&
                            _recognizedText!.isNotEmpty) ...[
                          Expanded(
                            child: RecognizedTextDisplay(
                              recognizedText: _recognizedText!,
                              onWordSelected: _handleWordSelected,
                              onClose: _clearRecognizedText,
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
      // acknowledged -> acknowledge (dg로 끝나는 경우 dge로 변환)
      if (beforeEd.endsWith('dg')) {
        return beforeEd.substring(0, beforeEd.length - 2) + 'dge';
      }
      // stopped -> stop (자음이 두 번 반복되는 경우)
      if (beforeEd.length > 1 && 
          _isConsonant(beforeEd[beforeEd.length - 1]) &&
          beforeEd[beforeEd.length - 1] == beforeEd[beforeEd.length - 2]) {
        return beforeEd.substring(0, beforeEd.length - 1);
      }
      // graced -> grace, noticed -> notice, experienced -> experience
      // 'c'로 끝나는 경우 대부분 원형이 'ce'로 끝나므로 'e'를 추가
      if (beforeEd.endsWith('c')) {
        // 'e'를 추가하여 원형 복원 시도 (예: grac -> grace, notic -> notice)
        final withE = beforeEd + 'e';
        return withE;
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

    // 비교급/최상급 (더 제한적으로 처리)
    if (base.endsWith('iest') && base.length > 4) {
      return base.substring(0, base.length - 4) + 'y';
    }
    if (base.endsWith('est') && base.length > 3) {
      final beforeEst = base.substring(0, base.length - 3);
      // 비교급은 보통 짧은 단어이고, 자음이 두 번 반복되는 경우만 처리
      if (beforeEst.length <= 5 && beforeEst.endsWith('e')) {
        return beforeEst;
      }
      // doubled -> double 같은 경우만 (짧은 단어)
      if (beforeEst.length <= 5) {
        return beforeEst;
      }
    }
    if (base.endsWith('ier') && base.length > 3) {
      return base.substring(0, base.length - 3) + 'y';
    }
    // 비교급은 보통 짧은 단어에만 적용
    // matter, water 같은 긴 단어는 비교급이 아님
    // 비교급 원형은 보통 3글자 (big -> bigger)
    // 4글자 원형(fast -> faster)은 실제 비교급이지만, matter처럼 4글자인 일반 단어와 구분하기 어려움
    // 따라서 매우 제한적으로만 처리: 원형이 3글자이고 e로 끝나지 않는 경우만
    if (base.endsWith('er') && base.length == 5) { // bigger (5글자) -> big (3글자)
      final beforeEr = base.substring(0, base.length - 2);
      if (beforeEr.length == 3 && !beforeEr.endsWith('e')) {
        return beforeEr; // big
      }
    }
    // nice -> nicer 같은 경우는 처리하지 않음 (nice는 이미 원형이므로)

    return base;
  }

  bool _isConsonant(String char) {
    return !RegExp(r'[aeiouAEIOU]').hasMatch(char);
  }

  String _getSentenceContainingWordFromText(String text, String word) {
    // 단어가 포함된 첫 번째 위치 찾기 (대소문자 무시)
    final wordLower = word.toLowerCase();
    final textLower = text.toLowerCase();
    final wordIndex = textLower.indexOf(wordLower);
    
    if (wordIndex == -1) {
      // 단어를 찾을 수 없으면 빈 문자열 반환
      return '';
    }

    // 문장의 시작과 끝을 찾기
    int sentenceStart = 0;
    int sentenceEnd = text.length;

    // 문장 시작 찾기 (단어 위치에서 앞으로 가면서 문장 끝 문자 찾기)
    for (int i = wordIndex - 1; i >= 0; i--) {
      if (text[i] == '.' || text[i] == '!' || text[i] == '?') {
        sentenceStart = i + 1;
        break;
      }
    }

    // 문장 끝 찾기 (단어 위치에서 뒤로 가면서 문장 끝 문자 찾기)
    for (int i = wordIndex + word.length; i < text.length; i++) {
      if (text[i] == '.' || text[i] == '!' || text[i] == '?') {
        sentenceEnd = i + 1;
        break;
      }
    }

    // 문장 추출 및 정리
    String sentence = text.substring(sentenceStart, sentenceEnd).trim();
    // 앞뒤 공백 제거 및 연속된 공백을 하나로
    sentence = sentence.replaceAll(RegExp(r'\s+'), ' ');
    
    return sentence;
  }

  Future<void> _handleWordSelected(String selectedWord) async {
    if (selectedWord.isEmpty || _recognizedText == null) return;

    final word = selectedWord.trim();
    if (word.isEmpty) return;

    // 단어가 포함된 문장 추출 (전체 텍스트에서 해당 단어가 포함된 첫 번째 문장 찾기)
    final sentence = _getSentenceContainingWordFromText(_recognizedText!, word);

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
        if (mounted && data != null) {
          // 사용할 단어 키 결정 (원형 우선, 없으면 원래 단어)
          final wordKey = baseForm.isNotEmpty ? baseForm : word.toLowerCase();
          WordDetailDialog.show(
            context,
            data,
            sentence,
            word,
            wordKey,
            onMeaningSelected: (selectedWord, meaning) {
              if (mounted) {
                setState(() {
                  _selectedWordMeanings.add({
                    'word': wordKey, // 원형으로 저장
                    'meaning': meaning,
                  });
                });
              }
            },
          );
        }
      } else {
        // 단어를 찾지 못하면 ChatGPT API 호출
        if (mounted) {
          _fetchWordFromChatGPT(word, sentence, baseForm);
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

  /// ChatGPT API를 호출하여 단어 정보를 가져오고 Firebase에 저장한 후 표시합니다.
  Future<void> _fetchWordFromChatGPT(String word, String sentence, String baseForm) async {
    // 로딩 다이얼로그 표시
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('단어 정보를 불러오는 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // ChatGPT API 호출
      final wordData = await ChatGPTService.getWordInfo(word);
      
      if (!mounted) return;
      
      if (wordData == null) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어 정보를 가져올 수 없습니다.')),
        );
        return;
      }

      // Firebase에 저장
      final wordKey = baseForm.isNotEmpty ? baseForm : word.toLowerCase();
      await _firestore.collection('words').doc(wordKey).set(wordData);

      // 로딩 다이얼로그 닫기
      if (!mounted) return;
      Navigator.of(context).pop();

      // WordDetailDialog 표시
      WordDetailDialog.show(
        context,
        wordData,
        sentence,
        word,
        wordKey,
        onMeaningSelected: (selectedWord, meaning) {
          if (mounted) {
            setState(() {
              _selectedWordMeanings.add({
                'word': wordKey,
                'meaning': meaning,
              });
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('단어 정보를 가져오는 중 오류가 발생했습니다: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
      
      print('ChatGPT API 오류: $e');
    }
  }

  void _removeSelectedWord(int index) {
    setState(() {
      _selectedWordMeanings.removeAt(index);
    });
  }

  Future<void> _showAddToFlashcardDialog() async {
    if (_selectedWordMeanings.isEmpty) return;

    final result = await AddToFlashcardDialog.show(
      context,
      _selectedWordMeanings,
    );

    // 저장 성공 시 선택된 단어 목록 초기화 및 성공 메시지 표시
    if (result == true && mounted) {
      setState(() {
        _selectedWordMeanings.clear();
      });
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('단어장에 성공적으로 추가되었습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 발음기호 업데이트 진행 상황을 보여주는 다이얼로그
class _PronunciationProgressDialog extends StatelessWidget {
  const _PronunciationProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('발음기호 추가 중...'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            '단어들의 발음기호를 가져오는 중입니다.\n시간이 걸릴 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

